//
//  SPPuppy.h
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPPuppy : NSObject
@property (nonatomic, strong) NSString* gid;
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSString* about;
@property (nonatomic, assign, getter = isFavorite) BOOL favorite;
@property (nonatomic, strong) NSString* imagePath;

+ (SPPuppy*)fromJSON:(NSDictionary*)json;

@end
