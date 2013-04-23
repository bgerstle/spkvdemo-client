//
//  SPKVODemoStorage.h
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SPKVODemoObject.h"
#import "SPPromise.h"

@interface SPKVODemoStorage : NSObject
@property (nonatomic, retain) NSSortDescriptor* sortDescriptor;
@property (nonatomic, assign, readonly, getter=isOnline) BOOL online;

/// Access `objects` indirectly using mutablerArrayValueForKey:@"objects"
//@property (nonatomic, readonly) NSMutableArray* objects;

- (id)initWithServerPath:(NSString*)remote topic:(NSString*)topic;

- (SPPromise*)socketReady;

- (SPPromise*)getRemoteObjects;

- (SPPromise*)getRemoteObject:(NSString*)gid;

- (void)subscribeToAllObjects;
- (void)unsubscribeFromAllObjects;

@end
