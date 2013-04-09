//
//  SPPuppyStorage.h
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SPPuppy.h"
#import "SPPromise.h"

@interface SPPuppyStorage : NSObject
@property (nonatomic, retain) NSSortDescriptor* sortDescriptor;
@property (nonatomic, retain, readonly) NSMutableArray* puppies;

- (id)initWithServerPath:(NSString*)puppyServer;

- (SPPromise*)socketReady;

- (SPPromise*)getPups;

- (SPPromise*)getPup:(NSString*)gid;

- (void)subscribeToPups;
- (void)unsubscribedToPups;

@end
