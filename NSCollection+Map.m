//
//  NSMutableDictionary+Map.m
//  Project X
//
//  Created by Brian Gerstle on 3/25/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "NSCollection+Map.h"

@implementation NSDictionary (Map)

- (NSMutableDictionary*)map:(NSDictionary*(^)(id key, id obj, BOOL* stop))map
{
    NSMutableDictionary* mapResult = [[NSMutableDictionary alloc] initWithCapacity:[self count]];
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSDictionary* mappedEntry = map(key, obj, stop);
        if (mappedEntry) {
            [mapResult addEntriesFromDictionary:mappedEntry];
        }
    }];
    return mapResult;
}

@end

@implementation NSArray (Map)

- (NSMutableArray*)map:(id(^)(id obj, NSUInteger idx, BOOL* stop))map
{
    NSMutableArray* mapResult = [[NSMutableArray alloc] initWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id mappedObject = map(obj, idx, stop);
        if (mappedObject) {
            [mapResult addObject:mappedObject];
        }
    }];
    return mapResult;
}

@end