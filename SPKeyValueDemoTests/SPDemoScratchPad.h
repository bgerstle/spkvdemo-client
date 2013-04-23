//
//  SPDemoScratchPad.h
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/9/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <Foundation/Foundation.h>

/*! Ignore this file! It's used as a scratchpad for presentation stuff
 */

@interface SPDemoScratchPad : NSObject

@end


@interface NSObject (JSONFactory)

+ (instancetype)fromJSON:(NSDictionary*)json;

@end

//...

@class Occupation;
@interface Person : NSObject
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) Occupation* occupation;
@end

@class Company;
@interface Occupation : NSObject
@property (nonatomic, strong) NSString* title;
@property (nonatomic, strong) Company* company;
@property (nonatomic, strong) NSNumber* salary;
@end

@interface Company : NSObject
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSSet* employees;
@end