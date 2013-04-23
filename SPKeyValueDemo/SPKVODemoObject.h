//
//  SPKVODemoObject.h
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPKVODemoObject : NSObject
@property (nonatomic, strong) NSString* gid;
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSString* about;
@property (nonatomic, assign, getter = isFavorite) BOOL favorite;
@property (nonatomic, strong) NSString* imagePath;

+ (SPKVODemoObject*)fromJSON:(NSDictionary*)json;

@end
