//
//  SPPromise.m
//  Project X
//
//  Created by Brian Gerstle on 3/25/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPPromise_Internal.h"

@implementation SPPromise

- (id)initWithDeferred:(SPDeferred*)deferred
{
    self = [super init];
    if (self) {
        _deferred = deferred;
    }
    return self;
}

- (BOOL)isResolved
{
    return _deferred.isResolved;
}

- (BOOL)isRejected
{
    return _deferred.isRejected;
}

- (BOOL)isCancelled
{
    return _deferred.isCancelled;
}

- (SPDeferredState)state
{
    return _deferred.state;
}

- (id)resolvedObj
{
    return _deferred.resolvedObj;
}

- (NSError*)error
{
    return _deferred.error;
}

- (instancetype)done:(SPDeferredResolvedBlock)doneBlock
{
    [_deferred done:doneBlock];
    return self;
}

- (instancetype)fail:(SPDeferredFailBlock)failBlock
{
    [_deferred fail:failBlock];
    return self;
}

- (instancetype)always:(SPDeferredAlwaysBlock)alwaysBlock
{
    [_deferred always:alwaysBlock];
    return self;
}

- (instancetype)done:(SPDeferredResolvedBlock)doneBlock queue:(dispatch_queue_t)callbackQueue;
{
    [_deferred done:doneBlock queue:callbackQueue];
    return self;
}

- (instancetype)fail:(SPDeferredFailBlock)failBlock queue:(dispatch_queue_t)callbackQueue;
{
    [_deferred fail:failBlock queue:callbackQueue];
    return self;
}

- (instancetype)always:(SPDeferredAlwaysBlock)alwaysBlock queue:(dispatch_queue_t)callbackQueue;
{
    [_deferred always:alwaysBlock queue:callbackQueue];
    return self;
}

- (instancetype)donePipe:(SPDeferredDonePipeBlock)donePipe
                   queue:(dispatch_queue_t)callbackQueue
{
    [_deferred donePipe:donePipe queue:callbackQueue];
    return self;
}

- (instancetype)failPipe:(SPDeferredFailPipeBlock)failPipe
                   queue:(dispatch_queue_t)callbackQueue
{
    [_deferred failPipe:failPipe queue:callbackQueue];
    return self;
}

- (instancetype)failPipe:(SPDeferredFailPipeBlock)failPipe
{
    [_deferred failPipe:failPipe];
    return self;
}

- (instancetype)donePipe:(SPDeferredDonePipeBlock)donePipe
{
    [_deferred donePipe:donePipe];
    return self;
}

- (void)cancel
{
    [_deferred cancel];
}

@end
