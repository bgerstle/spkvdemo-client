//
//  SPJSBridgeCallback.h
//  Project X
//
//  Created by Brian Gerstle on 3/22/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPDeferredCallback : NSObject
@property (nonatomic, strong, readonly) id block;
@property (nonatomic, assign, readonly) dispatch_queue_t queue;

+ (SPDeferredCallback*)callbackWithBlock:(id)block queue:(dispatch_queue_t)queue;

@end