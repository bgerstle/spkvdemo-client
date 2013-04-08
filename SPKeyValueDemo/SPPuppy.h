//
//  SPPuppy.h
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPPuppy : NSObject
@property (nonatomic, strong) NSString* puppyName;
@property (nonatomic, strong) NSString* puppyDescription;
@property (nonatomic, assign, getter = isFavorite) BOOL favorite;
@property (nonatomic, strong) NSString* imagePath;
@end
