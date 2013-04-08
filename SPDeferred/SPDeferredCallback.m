//
//  SPJSBridgeCallback.m
//  Project X
//
//  Created by Brian Gerstle on 3/22/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPDeferredCallback.h"

@implementation SPDeferredCallback

+ (SPDeferredCallback*)callbackWithBlock:(id)block queue:(dispatch_queue_t)queue
{
    return [[SPDeferredCallback alloc] initWithBlock:block queue:queue];
}

- (id)initWithBlock:(id)block queue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self)
    {
        _block = [block copy];
        _queue = queue;
    }
    return self;
}

@end