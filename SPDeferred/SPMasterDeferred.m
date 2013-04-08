//
//  SPMasterDeferred.m
//  Project X
//
//  Created by Brian Gerstle on 3/25/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPMasterDeferred.h"
#import "SPDeferred_Internal.h"

@interface SPMasterDeferred ()

@end

@implementation SPMasterDeferred
{
    dispatch_group_t _group;
    dispatch_queue_t _joinedCallbackQueue;
    NSMutableArray* _responses;
}

- (id)initWithDeferreds:(NSArray *)deferreds
{
    self = [super init];
    if (self) {
        _group = dispatch_group_create();
        _responses = [[NSMutableArray alloc] initWithCapacity:[deferreds count]];
        _joinedCallbackQueue = dispatch_queue_create([[NSString stringWithFormat:@"com.spotify.deferred.master.%p", self] UTF8String],
                                                     DISPATCH_QUEUE_SERIAL);
        [self joinDeferreds:deferreds];
    }
    return self;
}

- (void)joinDeferreds:(NSArray*)deferreds
{
    BOOL allFinished = YES;
    
    for (id<SPDeferredBase> dfr in deferreds) {
        // if any of the deferreds are rejected|canceled we can call the whole thing off
        switch (dfr.state) {
            case SPDeferredRejected:
            {
                [self reject:dfr.error];
                return;
            }
            case SPDeferredCancelled:
            {
                [self cancel];
                return;
            }
            case SPDeferredResolved:
            {
                // or if it's done, we keep track of allFinished (see below) and continue iterating
                [_responses addObject:[dfr resolvedObj] ?: dfr];
                allFinished &= YES;
                continue;
            }
            default:
                break;
        }
        
        allFinished = NO;
        
        dispatch_group_enter(_group);
        
        [dfr fail:^(NSError *error) {
            // if any deferreds fail, reject master, but NOT all other deferreds
            [self reject:error];
        } queue:_joinedCallbackQueue];
        
        [dfr done:^(id obj) {
            [_responses addObject:[dfr resolvedObj] ?: dfr];
        } queue:_joinedCallbackQueue];
        
        [dfr always:^ (SPDeferredState state) {
            // in case dfr is cancelled, we need to cancel master too, but NOT all other deferreds
            if (state == SPDeferredCancelled) {
                [self cancel];
            } 
            
            dispatch_group_leave(_group);
        } queue:_joinedCallbackQueue];
    }
    
    if (allFinished) {
        [self resolveWith:_responses];
    } else {
        // can't dispatch to our own queue since it would cause a deadlock
        dispatch_group_notify(_group,
                              _joinedCallbackQueue,
                              ^{
            [self resolveWith:_responses];
        });
    }
}

@end
