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
@property (nonatomic, strong) NSMutableSet* puppySet;
@property (nonatomic, strong) NSArray* sortedPuppies;
@end

@implementation SPPuppyStorage

- (id)initWithServerPath:(NSString*)puppyServer
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [MDWamp setDebug:YES];
    });
    
    if (!(self = [super init])) {
        return nil;
    }
    
    _puppySet = [[NSMutableSet alloc] init];
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
        [pendingDfr donePipe: ^ (NSArray* result) {
            NSArray* pups = [(NSArray*)result map:^id(id obj, NSUInteger idx, BOOL* stop) {
                SPPuppy* puppy = [[_puppySet objectsPassingTest:^BOOL(SPPuppy* pup, BOOL *stop) {
                    if ([[pup gid] isEqualToString:obj[@"gid"]]) {
                        *stop = YES;
                        return YES;
                    }
                    return NO;
                }] anyObject];
                
                if (!puppy) {
                    puppy = [SPPuppy fromJSON:obj];
                    return puppy;
                }
                
                return nil;
            }];
            
            NSMutableArray* mutablePups = [self mutableArrayValueForKey:@"puppies"];
            if ([pups count]) {
                [mutablePups addObjectsFromArray:pups];
            }
            
            return mutablePups;
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
        
        _pendingCalls[uri] = pendingDfr;
        
        $sp_decl_wself;
        [self prepCall:uri withDeferred:pendingDfr postOpenBlock:^(id obj) {
            [weakSelf.wampSocket call:uri withDelegate:weakSelf args:gid, nil];
        }];
        
        return pendingDfr.promise;
    }
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
        [self maybeSortPuppiesSilent];
    }
}

#pragma mark - Sorted Array KVC

- (void)maybeSortPuppiesSilent
{
    if (!_sortedPuppies) {
        _sortedPuppies = [_puppySet sortedArrayUsingDescriptors:@[_sortDescriptor]];
    }
}

- (NSUInteger)countOfPuppies
{
    return [_puppySet count];
}

- (id)objectInPuppiesAtIndex:(NSUInteger)index
{
    [self maybeSortPuppiesSilent];
    return _sortedPuppies[index];
}

- (void)removeObjectFromPuppiesAtIndex:(NSUInteger)index
{
    [self maybeSortPuppiesSilent];
    SPPuppy* outgoingPup = _sortedPuppies[index];
    [_puppySet removeObject:outgoingPup];
    [self maybeSortPuppiesSilent];
}

- (NSArray*)puppiesAtIndexes:(NSIndexSet *)indexes
{
    [self maybeSortPuppiesSilent];
    return [_sortedPuppies objectsAtIndexes:indexes];
}

- (void)removePuppiesAtIndexes:(NSIndexSet *)indexes
{
    [self maybeSortPuppiesSilent];
    [[_sortedPuppies objectsAtIndexes:indexes] sp_each:^(id obj) {
        [_puppySet removeObject:obj];
    }];
    [self maybeSortPuppiesSilent];
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
                                          userInfo:@{NSLocalizedFailureReasonErrorKey: reason}]];
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
}

@end
