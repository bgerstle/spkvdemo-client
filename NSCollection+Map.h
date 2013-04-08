//
//  NSCollection+Map.h
//  Project X
//
//  Created by Brian Gerstle on 3/25/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (Map)

- (NSMutableDictionary*)map:(NSDictionary*(^)(id key, id obj, BOOL* stop))map;

@end

@interface NSArray (Map)

- (NSMutableArray*)map:(id(^)(id obj, NSUInteger idx, BOOL* stop))map;

@end
