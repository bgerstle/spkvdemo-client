//
//  SPObjCDeferred.m
//  Project X
//
//  Created by Brian Gerstle on 3/22/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPDeferred_Internal.h"
#import "SPPromise.h"
#import "SPMasterDeferred.h"

#define SPDeferredQueueContextSize 64
#define SPDeferredQueueSpecificKey "SPDeferredQueueSpecificKey"

@implementation SPDeferred
{
@private
    SPDeferredState _state;
    NSError* _error;
    
    dispatch_queue_t _queue;
    
    /// collections of SPDeferredCallback objects
    NSMutableArray* _doneCallbacks;
    NSMutableArray* _failCallbacks;
    NSMutableArray* _alwaysCallbacks;
    NSMutableArray* _donePipes;
    NSMutableArray* _failPipes;
    
    id _resolvedObj;
    char _queueContext[SPDeferredQueueContextSize];
}

- (id)init
{
    self = [super init];
    if (self) {
        _doneCallbacks = [[NSMutableArray alloc] init];
        _failCallbacks = [[NSMutableArray alloc] init];
        _alwaysCallbacks = [[NSMutableArray alloc] init];
        _donePipes = [NSMutableArray new];
        _failPipes = [NSMutableArray new];

        snprintf(_queueContext, SPDeferredQueueContextSize, "com.spotify.deferred.%p", self);
        _queue = dispatch_queue_create(_queueContext, DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_queue, SPDeferredQueueSpecificKey, _queueContext, NULL);
    }
    return self;
}

- (void)dealloc
{
    dispatch_sync(_queue, ^{
        if (_state != SPDeferredPending)
            return;
        
        [self wasCancelled];
    });
}

- (BOOL)isOnInternalQueue
{
    return dispatch_get_specific(SPDeferredQueueSpecificKey) == _queueContext;
}

- (NSError*)error
{
    __block NSError* error = nil;
    dispatch_sync(_queue, ^ {
        error = _error;
    });
    return error;
}

- (id)resolvedObj
{
    return _resolvedObj;
}

- (SPDeferredState)state
{
    __block SPDeferredState state = SPDeferredPending;
    dispatch_sync(_queue, ^{
        state = _state;
    });
    return state;
}

- (BOOL)isResolved
{
    __block BOOL done = NO;
    dispatch_sync(_queue, ^ {
        done = _state == SPDeferredResolved;
    });
    return done;
}

- (BOOL)isRejected
{
    __block BOOL failed = NO;
    dispatch_sync(_queue, ^ {
        failed = _state == SPDeferredRejected;
    });
    return failed;
}

- (BOOL)isCancelled
{
    __block BOOL cancelled = NO;
    dispatch_sync(_queue, ^ {
        cancelled = _state == SPDeferredCancelled;
    });
    return cancelled;
}

- (instancetype)done:(SPDeferredResolvedBlock)doneBlock
{
    return [self done:doneBlock queue:dispatch_get_main_queue()];
}

- (instancetype)done:(SPDeferredResolvedBlock)doneBlock queue:(dispatch_queue_t)callbackQueue
{
    dispatch_sync(_queue, ^ {
        switch (_state) {
            case SPDeferredCancelled:
            case SPDeferredRejected:
                return;
            case SPDeferredResolved:
            {
                dispatch_async(callbackQueue, ^{
                    doneBlock(_resolvedObj ?: self);
                });
                return;
            }
            default:
                break;
        }
        
        [_doneCallbacks addObject:[SPDeferredCallback callbackWithBlock:doneBlock queue:callbackQueue]];
    });
    return self;
}

- (instancetype)fail:(SPDeferredFailBlock)failBlock
{
    return [self fail:failBlock queue:dispatch_get_main_queue()];
}


- (instancetype)fail:(SPDeferredFailBlock)failBlock queue:(dispatch_queue_t)callbackQueue
{    
    dispatch_sync(_queue, ^ {
        switch (_state) {
            case SPDeferredCancelled:
            case SPDeferredResolved:
                return;
            case SPDeferredRejected:
            {
                dispatch_async(callbackQueue, ^{
                    failBlock(_error);
                });
                return;
            }
            default:
                break;
        }
        
        [_failCallbacks addObject:[SPDeferredCallback callbackWithBlock:failBlock queue:callbackQueue]];
    });
    return self;
}

- (instancetype)always:(SPDeferredAlwaysBlock)alwaysBlock
{
    return [self always:alwaysBlock queue:dispatch_get_main_queue()];
}

- (instancetype)always:(SPDeferredAlwaysBlock)alwaysBlock queue:(dispatch_queue_t)callbackQueue
{
    dispatch_sync(_queue, ^ {
        switch (_state) {
            case SPDeferredPending:
                break;
            default:
            {
                dispatch_async(callbackQueue, ^{
                    alwaysBlock(_state);
                });
                return;
            }
        }
        
        [_alwaysCallbacks addObject:[SPDeferredCallback callbackWithBlock:alwaysBlock queue:callbackQueue]];
    });
    return self;
}


- (instancetype)donePipe:(SPDeferredDonePipeBlock)donePipe
{
    return [self donePipe:donePipe queue:dispatch_get_main_queue()];
}

- (instancetype)donePipe:(SPDeferredDonePipeBlock)donePipe
                   queue:(dispatch_queue_t)callbackQueue
{
    dispatch_sync(_queue, ^ {
        if (_state == SPDeferredCancelled)
            return;
        
        switch (_state) {
            case SPDeferredRejected:
            {
                dispatch_async(callbackQueue, ^{
                    id result = donePipe(_resolvedObj);
                    [self consumePipeResult:result];
                });
                break;
            }
                
            default:
                [_donePipes addObject:[SPDeferredCallback callbackWithBlock:donePipe queue:callbackQueue]];
                break;
        }
    });
    
    return self;
}

- (instancetype)failPipe:(SPDeferredFailPipeBlock)failPipe
{
    return [self failPipe:failPipe queue:dispatch_get_main_queue()];
}

- (instancetype)failPipe:(SPDeferredFailPipeBlock)failPipe
                   queue:(dispatch_queue_t)callbackQueue
{
    dispatch_sync(_queue, ^ {
        if (_state == SPDeferredCancelled)
            return;
        
        switch (_state) {
            case SPDeferredRejected:
            {
                dispatch_async(callbackQueue, ^{
                    id result = failPipe(_error);
                    [self consumePipeResult:result];
                });
                break;
            }
                
            default:
                [_failPipes addObject:[SPDeferredCallback callbackWithBlock:failPipe queue:callbackQueue]];
                break;
        }
    });
    
    return self;
}

- (BOOL)primitiveIsResolved
{
    return _state == SPDeferredResolved;
}

- (BOOL)primitiveIsCancelled
{
    return _state == SPDeferredCancelled;
}

- (BOOL)primitiveIsRejected
{
    return _state == SPDeferredRejected;
}

- (SPDeferredState)primitiveState
{
    return _state;
}

- (void)cancel
{
    dispatch_sync(_queue, ^ {
        if (_state != SPDeferredPending)
            return;
        
        [self wasCancelled];
    });
}

- (void)resolve
{
    [self resolveWith:self];
}

- (void)resolveWith:(id)result
{
    dispatch_sync(_queue, ^ {
        _resolvedObj = result == self ? nil : result;
        
        if ([self maybeResolvePipe]) {
            return;
        }
        
        if (_state != SPDeferredPending)
            return;
        
        _state = SPDeferredResolved;
        
        id resultArg = _resolvedObj ?: self;
        
        for (SPDeferredCallback* callback in _doneCallbacks) {
            dispatch_async(callback.queue, ^{
                    ((SPDeferredResolvedBlock)callback.block)(resultArg);
            });
        }
        
        [self finally];
    });
}

- (void)reject:(NSError *)error
{
    dispatch_sync(_queue, ^ {
        _error = error;
        
        if ([self maybeRejectPipe]) {
            return;
        }
        
        if (_state != SPDeferredPending)
            return;
        
        _state = SPDeferredRejected;
        
        for (SPDeferredCallback* callback in _failCallbacks) {
            dispatch_async(callback.queue, ^{
                ((SPDeferredFailBlock)callback.block)(error);
            });
        }
        [self finally];
    });
}

- (void)consumePipeResult:(id)result
{
    // !!!: It's possible for the pipe to alter the deferred's state w/in pipe.block, in which case
    // any future calls to resolve(With) or reject: will continue evaluating pipes until none are left,
    // which will cause the deferred to end up in whatever final states the pipes resolve to
    if ([result conformsToProtocol:@protocol(SPDeferredBase)] && ![result isEqual:self]) {
        id<SPDeferredBase> pipePromise = (id<SPDeferredBase>)result;
        
        // !!!: there's an intentional retain cycle here to keep pipe's promise alive while we consume it
        [pipePromise always:^(SPDeferredState state) {
            switch (state) {
                case SPDeferredResolved:
                    [self resolveWith:[pipePromise resolvedObj]];
                    break;
                case SPDeferredRejected:
                    [self reject:[pipePromise error]];
                    break;
                default:
                    [self cancel];
                    break;
            }
        }];
    } else if ([result isKindOfClass:[NSError class]]) {
        [self reject:result];
    } else {
        [self resolveWith:result];
    }
}

- (BOOL)maybeResolvePipe
{
    NSParameterAssert([self isOnInternalQueue]);
    
    SPDeferredCallback* pipe = [self maybePopDonePipe];
    if (!pipe) {
        return NO;
    }
    
    dispatch_async(pipe.queue, ^ {
        id result = ((SPDeferredDonePipeBlock)pipe.block)(_resolvedObj ?: self);
        [self consumePipeResult:result];
    });
    
    return YES;
}

- (BOOL)maybeRejectPipe
{
    NSParameterAssert([self isOnInternalQueue]);
    
    SPDeferredCallback* pipe = [self maybePopFailPipe];
    if (!pipe) {
        return NO;
    }
    
    dispatch_async(pipe.queue, ^ {
        id result = ((SPDeferredFailPipeBlock)pipe.block)(_error);
        [self consumePipeResult:result];
    });
    
    return YES;
}

- (SPDeferredCallback*)maybePopDonePipe
{
    NSParameterAssert([self isOnInternalQueue]);
    
    if ([_donePipes count] == 0) {
        return nil;
    }
    SPDeferredCallback* pipe = _donePipes[0];
    [_donePipes removeObjectAtIndex:0];
    return pipe;
}

- (SPDeferredCallback*)maybePopFailPipe
{
    NSParameterAssert([self isOnInternalQueue]);
    
    if ([_failPipes count] == 0) {
        return nil;
    }
    SPDeferredCallback* pipe = _failPipes[0];
    [_failPipes removeObjectAtIndex:0];
    return pipe;
}

- (void)finally
{
    NSParameterAssert([self isOnInternalQueue]);
    
    // "copy" our internal state here to be sent to all always callbacks
    SPDeferredState state = _state;
    for (SPDeferredCallback* callback in _alwaysCallbacks) {
        dispatch_async(callback.queue, ^{
            ((SPDeferredAlwaysBlock)callback.block)(state);
        });
    }
    
    [_doneCallbacks removeAllObjects];
    [_failCallbacks removeAllObjects];
    [_alwaysCallbacks removeAllObjects];
    [_donePipes removeAllObjects];
    [_failPipes removeAllObjects];
}

- (void)wasCancelled
{
    NSParameterAssert([self isOnInternalQueue]);
    
    _state = SPDeferredCancelled;
    [self finally];
}

- (SPPromise*)promise
{
    return [[SPPromise alloc] initWithDeferred:self];
}

+ (SPPromise*)join:(NSArray*)deferreds
{
    SPMasterDeferred* master = [[SPMasterDeferred alloc] initWithDeferreds:deferreds];    
    return master.promise;
}

@end
