//
//  SPPuppy.m
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPPuppy.h"

@implementation SPPuppy

+ (SPPuppy*)fromJSON:(NSDictionary *)json
{
    SPPuppy* pup = [[SPPuppy alloc] init];
    [pup setValuesForKeysWithDictionary:json];
    return pup;
}

@end
