//
//  SPDemoScratchPadTests.m
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/9/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPDemoScratchPadTests.h"
#import "SPDemoScratchPad.h"

@implementation SPDemoScratchPadTests

- (void)testJSONFactory
{
    NSDictionary* personDict =
    @{@"name": @"Brian",
      @"occupation": @{@"title": @"Developer",
                       @"company": @{@"name": @"Spotify"}}};
    
    Person* person;
    STAssertNoThrow(person = [Person fromJSON:personDict], nil);
    
    STAssertEqualObjects(person.name, @"Brian", nil);
    STAssertTrue([person.occupation isKindOfClass:[Occupation class]], nil);
    STAssertEqualObjects(person.occupation.title, @"Developer", nil);
    STAssertTrue([person.occupation.company isKindOfClass:[Company class]], nil);
    STAssertEqualObjects(person.occupation.company.name, @"Spotify", nil);
}

- (void)testKVUpdate
{
    Person* person = [[Person alloc] init];
    person.name = @"Joe";
    person.occupation = [Occupation new];
    person.occupation.title = @"Plumber";
    person.occupation.company = [Company new];
    person.occupation.company.name = @"Joe's Pipes";
    
    [person setValuesForKeysWithDictionary:
    @{@"name": @"Tim",
      @"occupation": @{@"title": @"CEO",
                       @"company": @{@"name": @"Apple"}}}];
    
    STAssertEqualObjects(person.name, @"Tim", nil);
    STAssertTrue([person.occupation isKindOfClass:[Occupation class]], nil);
    STAssertEqualObjects(person.occupation.title, @"CEO", nil);
    STAssertTrue([person.occupation.company isKindOfClass:[Company class]], nil);
    STAssertEqualObjects(person.occupation.company.name, @"Apple", nil);
}

- (void)testOperators
{
    NSArray* salaries = @[@(300), @(15), @(15), @(1000), @(7)];
    NSMutableArray* peeps = [[NSMutableArray alloc] initWithCapacity:[salaries count]];
    for (NSNumber* salary in salaries) {
        Person* p = [Person new];
        p.occupation = [Occupation new];
        p.occupation.salary = salary;
        [peeps addObject:p];
    }
    STAssertTrue([[peeps valueForKeyPath:@"@count"] intValue] == [salaries count], nil);
    STAssertTrue([[peeps valueForKeyPath:@"@max.occupation.salary"] intValue] == 1000, nil);
    STAssertTrue([[peeps valueForKeyPath:@"@min.occupation.salary"] intValue] == 7, nil);
    STAssertTrue([[peeps valueForKeyPath:@"@sum.occupation.salary"] intValue] == 1337, nil);
    
    STAssertTrue([[peeps valueForKeyPath:@"@distinctUnionOfObjects.occupation.salary"] count] == 4, nil);
    
    STAssertTrue([[peeps valueForKeyPath:@"occupation.salary"] isEqualToArray:salaries], nil);
    [peeps setValue:@(1) forKeyPath:@"occupation.salary"];
    STAssertTrue([[peeps valueForKeyPath:@"@sum.occupation.salary"] intValue] == [peeps count], nil);
}

@end
