//
//  SPKVODemoObject.m
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPKVODemoObject.h"

@implementation SPKVODemoObject

+ (SPKVODemoObject*)fromJSON:(NSDictionary *)json
{
    SPKVODemoObject* obj = [[SPKVODemoObject alloc] init];
    [obj setValuesForKeysWithDictionary:json];
    return obj;
}

@end
