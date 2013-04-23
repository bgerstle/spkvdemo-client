//
//  SPKVODemoStorage.m
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPKVODemoStorage.h"
#import <MDWamp/MDWamp.h>
#import "SPFunctional.h"
#import "NSCollection+Map.h"

@interface SPKVODemoStorage ()
<MDWampEventDelegate, MDWampRpcDelegate, MDWampDelegate>
@property (nonatomic, strong) SPDeferred* socketReadyDfr;
@property (nonatomic, strong) MDWamp* wampSocket;
@property (nonatomic, strong) NSMutableDictionary* pendingCalls;
@property (nonatomic, strong) NSMutableDictionary* objectMap;
@property (nonatomic, strong) NSArray* sortedObjects;
@property (nonatomic, strong) NSString* topic;
@property (nonatomic, assign, readwrite, getter=isOnline) BOOL online;
@end

@implementation SPKVODemoStorage

- (id)initWithServerPath:(NSString*)remote topic:(NSString*)topic
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [MDWamp setDebug:YES];
    });
    
    if (!(self = [super init])) {
        return nil;
    }
    
    _topic = topic;
    _objectMap = [[NSMutableDictionary alloc] init];
    _pendingCalls = [[NSMutableDictionary alloc] init];
    _sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    _socketReadyDfr = [[SPDeferred alloc] init];
    _wampSocket = [[MDWamp alloc] initWithUrl:remote delegate:self];
    [_wampSocket connect];
    
    return self;
}

- (void)dealloc
{
    [_wampSocket unsubscribeTopic:_topic];
}

- (NSMutableDictionary*)updateObjects:(NSDictionary*)results
                         objsToRemove:(NSArray**)outRemoveObjs
                     outUpdateSorting:(BOOL*)outUpdateSorting
{
    NSMutableArray* removeObjs = outRemoveObjs ? [[NSMutableArray alloc] initWithCapacity:[results count]] : nil;
    __block BOOL needsSortingUpdate = NO;
    NSMutableDictionary* uniqueObjs = [results map:^id(NSString* gid, NSDictionary* vals, BOOL *stop) {
        SPKVODemoObject* obj = _objectMap[gid];
        if (!obj && [vals count]) {
            obj = [SPKVODemoObject fromJSON:vals];
            obj.gid = gid;
            return @{obj.gid: obj};
        } else if ([vals count]) {
            if ([[vals allKeys] containsObject:_sortDescriptor.key]
                && [[obj valueForKey:_sortDescriptor.key] isEqual:vals[_sortDescriptor.key]]) {
                needsSortingUpdate = YES;
            }
            [obj setValuesForKeysWithDictionary:vals];
        } else {
            [removeObjs addObject:gid];
        }
        
        return nil;
    }];
    
    if (outUpdateSorting) {
        *outUpdateSorting = needsSortingUpdate;
    }
    
    if (outRemoveObjs) {
        (*outRemoveObjs) = removeObjs;
    }
    return uniqueObjs;
}

#pragma mark - WAMP Abstractions

- (void)prepCall:(NSString*)callURI withDeferred:(SPDeferred*)pendingDfr postOpenBlock:(SPDeferredResolvedBlock)done
{
    _pendingCalls[callURI] = pendingDfr;
    
    $sp_decl_wself;
    [_socketReadyDfr done:done];
    
    [_socketReadyDfr fail:^(NSError *error) {
        [pendingDfr reject:error];
    }];
    
    [_socketReadyDfr always:^(SPDeferredState state) {
        if (state == SPDeferredCancelled) {
            [pendingDfr cancel];
        }
    }];
    
    [pendingDfr always:^(SPDeferredState state) {
        @synchronized(self) {
            [weakSelf.pendingCalls removeObjectForKey:callURI];
        }
    }];
}

- (SPPromise*)getRemoteObjects
{
    @synchronized(self) {
        NSString* uri = [_topic stringByAppendingString:@":#get"];
        SPDeferred* pendingDfr = _pendingCalls[uri];
        if (pendingDfr) {
            return pendingDfr.promise;
        }
        
        pendingDfr = [[SPDeferred alloc] init];
        
        $sp_decl_wself;        
        [pendingDfr donePipe: ^ (NSDictionary* results) {
            [weakSelf mergeObjects:results];
            return weakSelf.sortedObjects;
        }];
        
        [self prepCall:uri withDeferred:pendingDfr postOpenBlock:^(id obj) {
            [weakSelf.wampSocket call:uri withDelegate:weakSelf args:nil];
        }];
        
        return pendingDfr.promise;
    }
}

- (SPPromise*)getRemoteObject:(NSString*)gid
{
    @synchronized(self) {
        NSString* uri = [_topic stringByAppendingString:@":#get"];
        SPDeferred* pendingDfr = _pendingCalls[uri];
        if (pendingDfr) {
            return pendingDfr.promise;
        }
        
        pendingDfr = [[SPDeferred alloc] init];
        
        $sp_decl_wself;
        [pendingDfr donePipe: ^id(NSDictionary* results) {
            [weakSelf mergeObjects:results];
            return weakSelf.objectMap[[[results allKeys] lastObject]];
        }];
        
        [self prepCall:uri withDeferred:pendingDfr postOpenBlock:^(id obj) {
            [weakSelf.wampSocket call:uri withDelegate:weakSelf args:gid, nil];
        }];
        
        return pendingDfr.promise;
    }
}

- (void)subscribeToAllObjects
{
    $sp_decl_wself;
    [_socketReadyDfr done:^(id obj) {
        [weakSelf.wampSocket subscribeTopic:[NSString stringWithFormat:@"http://spkvexample.com/%@/", _topic]
                               withDelegate:self];
    }];
}

- (void)unsubscribeFromAllObjects
{
    $sp_decl_wself;
    [_socketReadyDfr done:^(id obj) {
        [weakSelf.wampSocket unsubscribeTopic:[NSString stringWithFormat:@"http://spkvexample.com/%@/", _topic]];
    }];
}

- (void)mergeObjects:(NSDictionary*)results
{
    NSArray* objsToRemove = nil;
    BOOL forceSortingUpdate = NO;
    NSMutableDictionary* objs = [self updateObjects:results
                                       objsToRemove:&objsToRemove
                                   outUpdateSorting:&forceSortingUpdate];
    
    if ([objs count]) {
        [self insertObjects:objs];
    }
    
    if ([objsToRemove count]) {
        [self removeObjects:objsToRemove];
    }
    
    if (forceSortingUpdate && ![objs count] && ![objsToRemove count]) {
        [self updateObjectSorting];
    }
}

- (void)updateObjectSorting
{
    // lazy impl
    [self willChangeValueForKey:@"objects"];
    _sortedObjects = nil;
    [self generateSortedObjectsIfNil];
    [self didChangeValueForKey:@"objects"];
}

- (void)removeObjects:(NSArray*)gids
{    
    NSMutableIndexSet* deletedIndexes = [[NSMutableIndexSet alloc] init];
    
    [[_sortedObjects valueForKey:@"gid"] enumerateObjectsUsingBlock:^(NSString* gid, NSUInteger idx, BOOL *stop) {
        if ([gids containsObject:gid]) {
            [deletedIndexes addIndex:idx];
            if ([gids count] == [deletedIndexes count]) {
                *stop = YES;
            }
        }
    }];
    
    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:deletedIndexes forKey:@"objects"];
    [_objectMap removeObjectsForKeys:gids];
    _sortedObjects = nil;
    [self generateSortedObjectsIfNil];
    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:deletedIndexes forKey:@"objects"];
}

- (void)insertObjects:(NSDictionary*)objects
{
    [_objectMap addEntriesFromDictionary:objects];
    
    NSMutableIndexSet* insertedIndexes = [[NSMutableIndexSet alloc] init];
    
    NSArray* updatedSortedObjs = [[_objectMap allValues] sortedArrayUsingDescriptors:@[_sortDescriptor]];
    [updatedSortedObjs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([[objects allValues] containsObject:obj]) {
            [insertedIndexes addIndex:idx];
            
            if ([insertedIndexes count] == [objects count]) {
                *stop =YES;
            }
        }
    }];    
    
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:insertedIndexes forKey:@"objects"];
    _sortedObjects = updatedSortedObjs;
    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:insertedIndexes forKey:@"objects"];
}

#pragma mark - Accessors

- (void)setOnline:(BOOL)online
{
    if (online != _online) {
        [self willChangeValueForKey:@"online"];
        _online = online;
        [self didChangeValueForKey:@"online"];
    }
}

- (SPPromise*)socketReady
{
    return [_socketReadyDfr promise];
}

- (void)setSortDescriptor:(NSSortDescriptor *)sortDescriptor
{
    if (![sortDescriptor isEqual:_sortDescriptor]) {
        _sortDescriptor = sortDescriptor;
        _sortedObjects = nil;
        [self generateSortedObjectsIfNil];
    }
}

#pragma mark - Sorted Array KVC

- (void)generateSortedObjectsIfNil
{
    if (!_sortedObjects) {
        _sortedObjects = [[_objectMap allValues] sortedArrayUsingDescriptors:@[_sortDescriptor]];
    }
}

- (NSUInteger)countOfObjects
{
    return [_objectMap count];
}

- (void)insertObject:(SPKVODemoObject *)aObj inObjectsAtIndex:(int)index
{
    // index is ignored, since we're sorting automatically
    if (_sortedObjects && [_sortedObjects containsObject:aObj]) {
        return;
    }
    
    if (!_sortedObjects) {
        _objectMap[aObj.gid] = aObj;
        [self generateSortedObjectsIfNil];
        return;
    }
    
    // insert object at appropriate index
    __block int insertionIndex = 0;
    [_sortedObjects enumerateObjectsUsingBlock:^(SPKVODemoObject* obj, NSUInteger idx, BOOL *stop) {
        switch ([[aObj valueForKeyPath:_sortDescriptor.key] compare:[obj valueForKeyPath:_sortDescriptor.key]]) {
            case NSOrderedAscending:
                if (!_sortDescriptor.ascending) {
                    insertionIndex = idx++;
                    *stop = YES;
                }
                return;
            case NSOrderedDescending:
                if (_sortDescriptor.ascending) {
                    insertionIndex = idx++;
                    *stop = YES;
                }
                return;
            case NSOrderedSame:
                insertionIndex = idx;
                *stop = YES;
                return;
            default:
                break;
        }
        insertionIndex++;
    }];
    
    if (insertionIndex == 0) {
        _sortedObjects = [@[aObj] arrayByAddingObjectsFromArray:_sortedObjects];
    } else if (insertionIndex == [_sortedObjects count]) {
        _sortedObjects = [_sortedObjects arrayByAddingObject:aObj];
    } else {
        NSArray* beforeInsertion = [_sortedObjects subarrayWithRange:NSMakeRange(0, insertionIndex--)];
        NSArray* afterInsertion = [_sortedObjects subarrayWithRange:NSMakeRange(insertionIndex, [_sortedObjects count] - insertionIndex)];
        _sortedObjects = [[beforeInsertion arrayByAddingObject:aObj] arrayByAddingObjectsFromArray:afterInsertion];
    }
}

- (id)objectInObjectsAtIndex:(NSUInteger)index
{
    [self generateSortedObjectsIfNil];
    return _sortedObjects[index];
}

- (void)removeObjectFromObjectsAtIndex:(NSUInteger)index
{
    [self generateSortedObjectsIfNil];
    SPKVODemoObject* outgoingObj = _sortedObjects[index];
    [_objectMap removeObjectForKey:outgoingObj.gid];
    [self generateSortedObjectsIfNil];
}

- (NSArray*)objectsAtIndexes:(NSIndexSet *)indexes
{
    [self generateSortedObjectsIfNil];
    return [_sortedObjects objectsAtIndexes:indexes];
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes
{
    [self generateSortedObjectsIfNil];
    [[_sortedObjects objectsAtIndexes:indexes] sp_each:^(SPKVODemoObject* obj) {
        [_objectMap removeObjectForKey:obj.gid];
    }];
    [self generateSortedObjectsIfNil];
}

#pragma mark - MDWampProtocols

- (void)onOpen
{
    static NSDictionary* prefixesURIMap = nil;
    if (!prefixesURIMap){
        prefixesURIMap = @{_topic: [NSString stringWithFormat:@"http://spkvexample.com/%@", _topic]};
    }
    
    [prefixesURIMap enumerateKeysAndObjectsUsingBlock:^(NSString* prefix, NSString* uri, BOOL *stop) {
        [_wampSocket prefix:prefix uri:uri];
    }];
    
    self.online = YES;
    
    [_socketReadyDfr resolve];
}

- (void)onClose:(int)code reason:(NSString *)reason
{
    [_socketReadyDfr reject:[NSError errorWithDomain:@"MDWampErrorDomain"
                                              code:code
                                            userInfo:reason ? @{NSLocalizedFailureReasonErrorKey: reason} : nil]];
    
    // reset the deferred so consumers can register callbacks for when we go online again
    _socketReadyDfr = [[SPDeferred alloc] init];
    
    self.online = NO;
}

- (void)onError:(NSString *)errorUri description:(NSString *)errorDesc forCalledUri:(NSString *)callUri
{
    NSLog(@"MDwamp error! %@", @{@"uri": errorUri, @"desc": errorDesc, @"callURI": callUri});
    
    @synchronized(self) {
        [_pendingCalls[callUri] reject:[NSError errorWithDomain:errorUri code:-1 userInfo:@{NSLocalizedFailureReasonErrorKey: errorDesc}]];
    }
}

- (void)onResult:(id)result forCalledUri:(NSString *)callUri
{
    NSLog(@"Got result %@ from URI: %@", result, callUri);
    @synchronized(self) {        
        [_pendingCalls[callUri] resolveWith:result];
    }
}

- (void)onEvent:(NSString *)topicUri eventObject:(id)object
{
    NSLog(@"Got object %@ for event %@", object, topicUri);
    
    if ([topicUri hasSuffix:[NSString stringWithFormat:@"%@/", _topic]]) {
        [self mergeObjects:object];
    }
}

@end
