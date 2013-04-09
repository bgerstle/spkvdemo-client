//
//  SPPuppyStorage.m
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPPuppyStorage.h"
#import <MDWamp/MDWamp.h>
#import "SPFunctional.h"
#import "NSCollection+Map.h"

@interface SPPuppyStorage ()
<MDWampEventDelegate, MDWampRpcDelegate, MDWampDelegate>
@property (nonatomic, strong) SPDeferred* socketReadyDfr;
@property (nonatomic, strong) MDWamp* wampSocket;
@property (nonatomic, strong) NSMutableDictionary* pendingCalls;
@property (nonatomic, strong) NSMutableDictionary* puppyMap;
@property (nonatomic, strong) NSArray* sortedPuppies;
@end

@implementation SPPuppyStorage
@dynamic puppies;

- (id)initWithServerPath:(NSString*)puppyServer
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [MDWamp setDebug:YES];
    });
    
    if (!(self = [super init])) {
        return nil;
    }
    
    _puppyMap = [[NSMutableDictionary alloc] init];
    _pendingCalls = [[NSMutableDictionary alloc] init];
    _sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    _socketReadyDfr = [[SPDeferred alloc] init];
    _wampSocket = [[MDWamp alloc] initWithUrl:puppyServer delegate:self];
    [_wampSocket connect];
    
    return self;
}

- (void)dealloc
{
    [_wampSocket unsubscribeTopic:@"pups"];
}

- (NSMutableDictionary*)updatePuppies:(NSDictionary*)results pupsToRemove:(NSArray**)outRemovePups
{
    NSMutableArray* removePups = outRemovePups ? [[NSMutableArray alloc] initWithCapacity:[results count]] : nil;
    NSMutableDictionary* uniquePups = [results map:^id(NSString* gid, NSDictionary* vals, BOOL *stop) {
        SPPuppy* puppy = _puppyMap[gid];
        if (!puppy) {
            puppy = [SPPuppy fromJSON:vals];
            puppy.gid = gid;
            return @{puppy.gid: puppy};
        } else if ([vals count]) {
            [puppy setValuesForKeysWithDictionary:vals];
        } else {
            [removePups addObject:gid];
        }
        
        return nil;
    }];
    
    if (outRemovePups) {
        (*outRemovePups) = removePups;
    }
    return uniquePups;
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

- (SPPromise*)getPups
{
    @synchronized(self) {
        NSString* uri = @"pups:#get";
        SPDeferred* pendingDfr = _pendingCalls[uri];
        if (pendingDfr) {
            return pendingDfr.promise;
        }
        
        pendingDfr = [[SPDeferred alloc] init];
        
        $sp_decl_wself;        
        [pendingDfr donePipe: ^ (NSDictionary* results) {
            [weakSelf mergePuppies:results];
            return weakSelf.sortedPuppies;
        }];
        
        [self prepCall:uri withDeferred:pendingDfr postOpenBlock:^(id obj) {
            [weakSelf.wampSocket call:uri withDelegate:weakSelf args:nil];
        }];
        
        return pendingDfr.promise;
    }
}

- (SPPromise*)getPup:(NSString*)gid
{
    @synchronized(self) {
        NSString* uri = @"pups:#get";
        SPDeferred* pendingDfr = _pendingCalls[uri];
        if (pendingDfr) {
            return pendingDfr.promise;
        }
        
        pendingDfr = [[SPDeferred alloc] init];
        
        $sp_decl_wself;
        [pendingDfr donePipe: ^id(NSDictionary* results) {
            [weakSelf mergePuppies:results];
            return weakSelf.puppyMap[[[results allKeys] lastObject]];
        }];
        
        [self prepCall:uri withDeferred:pendingDfr postOpenBlock:^(id obj) {
            [weakSelf.wampSocket call:uri withDelegate:weakSelf args:gid, nil];
        }];
        
        return pendingDfr.promise;
    }
}

- (void)subscribeToPups
{
    $sp_decl_wself;
    [_socketReadyDfr done:^(id obj) {
        [weakSelf.wampSocket subscribeTopic:@"http://spkvexample.com/pups/" withDelegate:self];
    }];
}

- (void)unsubscribedToPups
{
    $sp_decl_wself;
    [_socketReadyDfr done:^(id obj) {
        [weakSelf.wampSocket unsubscribeTopic:@"http://spkvexample.com/pups/"];
    }];
}

- (void)mergePuppies:(NSDictionary*)results
{
    NSArray* pupsToRemove = nil;
    NSMutableDictionary* pups = [self updatePuppies:results pupsToRemove:&pupsToRemove];
    
    if ([pups count]) {
        [self insertPups:pups];
    }
    
    if ([pupsToRemove count]) {
        [self removePups:pupsToRemove];
    }
}

- (void)removePups:(NSArray*)pupGIDs
{    
    NSMutableIndexSet* deletedIndexes = [[NSMutableIndexSet alloc] init];
    
    [[_sortedPuppies valueForKey:@"gid"] enumerateObjectsUsingBlock:^(NSString* gid, NSUInteger idx, BOOL *stop) {
        if ([pupGIDs containsObject:gid]) {
            [deletedIndexes addIndex:idx];
            if ([pupGIDs count] == [deletedIndexes count]) {
                *stop = YES;
            }
        }
    }];
    
    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:deletedIndexes forKey:@"puppies"];
    [_puppyMap removeObjectsForKeys:pupGIDs];
    _sortedPuppies = nil;
    [self generateSortedPuppiesIfNil];
    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:deletedIndexes forKey:@"puppies"];
}

- (void)insertPups:(NSDictionary*)pups
{
    [_puppyMap addEntriesFromDictionary:pups];
    
    NSMutableIndexSet* insertedIndexes = [[NSMutableIndexSet alloc] init];
    
    NSArray* updatedSortedPups = [[_puppyMap allValues] sortedArrayUsingDescriptors:@[_sortDescriptor]];
    [updatedSortedPups enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([[pups allValues] containsObject:obj]) {
            [insertedIndexes addIndex:idx];
            
            if ([insertedIndexes count] == [pups count]) {
                *stop =YES;
            }
        }
    }];    
    
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:insertedIndexes forKey:@"puppies"];
    _sortedPuppies = updatedSortedPups;
    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:insertedIndexes forKey:@"puppies"];
}

#pragma mark - Accessors

- (SPPromise*)socketReady
{
    return [_socketReadyDfr promise];
}

- (void)setSortDescriptor:(NSSortDescriptor *)sortDescriptor
{
    if (![sortDescriptor isEqual:_sortDescriptor]) {
        _sortDescriptor = sortDescriptor;
        _sortedPuppies = nil;
        [self generateSortedPuppiesIfNil];
    }
}

#pragma mark - Sorted Array KVC

- (void)generateSortedPuppiesIfNil
{
    if (!_sortedPuppies) {
        _sortedPuppies = [[_puppyMap allValues] sortedArrayUsingDescriptors:@[_sortDescriptor]];
    }
}

- (NSUInteger)countOfPuppies
{
    return [_puppyMap count];
}

- (void)insertObject:(SPPuppy *)aPup inPuppiesAtIndex:(int)index
{
    // index is ignored, since we're sorting automatically
    if (_sortedPuppies && [_sortedPuppies containsObject:aPup]) {
        return;
    }
    
    if (!_sortedPuppies) {
        _puppyMap[aPup.gid] = aPup;
        [self generateSortedPuppiesIfNil];
        return;
    }
    
    // insert puppy at appropriate index
    __block int insertionIndex = 0;
    [_sortedPuppies enumerateObjectsUsingBlock:^(SPPuppy* pup, NSUInteger idx, BOOL *stop) {
        switch ([[aPup valueForKeyPath:_sortDescriptor.key] compare:[pup valueForKeyPath:_sortDescriptor.key]]) {
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
        _sortedPuppies = [@[aPup] arrayByAddingObjectsFromArray:_sortedPuppies];
    } else if (insertionIndex == [_sortedPuppies count]) {
        _sortedPuppies = [_sortedPuppies arrayByAddingObject:aPup];
    } else {
        NSArray* beforeInsertion = [_sortedPuppies subarrayWithRange:NSMakeRange(0, insertionIndex--)];
        NSArray* afterInsertion = [_sortedPuppies subarrayWithRange:NSMakeRange(insertionIndex, [_sortedPuppies count] - insertionIndex)];
        _sortedPuppies = [[beforeInsertion arrayByAddingObject:aPup] arrayByAddingObjectsFromArray:afterInsertion];
    }
}

- (id)objectInPuppiesAtIndex:(NSUInteger)index
{
    [self generateSortedPuppiesIfNil];
    return _sortedPuppies[index];
}

- (void)removeObjectFromPuppiesAtIndex:(NSUInteger)index
{
    [self generateSortedPuppiesIfNil];
    SPPuppy* outgoingPup = _sortedPuppies[index];
    [_puppyMap removeObjectForKey:outgoingPup.gid];
    [self generateSortedPuppiesIfNil];
}

- (NSArray*)puppiesAtIndexes:(NSIndexSet *)indexes
{
    [self generateSortedPuppiesIfNil];
    return [_sortedPuppies objectsAtIndexes:indexes];
}

- (void)removePuppiesAtIndexes:(NSIndexSet *)indexes
{
    [self generateSortedPuppiesIfNil];
    [[_sortedPuppies objectsAtIndexes:indexes] sp_each:^(SPPuppy* pup) {
        [_puppyMap removeObjectForKey:pup.gid];
    }];
    [self generateSortedPuppiesIfNil];
}

#pragma mark - MDWampProtocols

- (void)onOpen
{
    static NSDictionary* prefixesURIMap = nil;
    if (!prefixesURIMap){
        prefixesURIMap = @{@"pups": @"http://spkvexample.com/pups"};
    }
    
    [prefixesURIMap enumerateKeysAndObjectsUsingBlock:^(NSString* prefix, NSString* uri, BOOL *stop) {
        [_wampSocket prefix:prefix uri:uri];
    }];
    
    [_socketReadyDfr resolve];
}

- (void)onClose:(int)code reason:(NSString *)reason
{
    [_socketReadyDfr reject:[NSError errorWithDomain:@"MDWampErrorDomain"
                                              code:code
                                            userInfo:reason ? @{NSLocalizedFailureReasonErrorKey: reason} : nil]];
    _socketReadyDfr = nil;
}

- (void)onError:(NSString *)errorUri description:(NSString *)errorDesc forCalledUri:(NSString *)callUri
{
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
    
    if ([topicUri hasSuffix:@"pups/"]) {
        [self mergePuppies:object];
    }
}

@end
