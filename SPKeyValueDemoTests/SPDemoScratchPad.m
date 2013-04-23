//
//  SPDemoScratchPad.m
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/9/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPDemoScratchPad.h"

@implementation Company
@end


@implementation SPDemoScratchPad

static void* kPersonNameKVOContext = &kPersonNameKVOContext;

- (void)bindToPerson:(Person*)person;
{
    // tell me when person's name changes
    [person addObserver:self
             forKeyPath:@"name"
                options:0
                context:kPersonNameKVOContext];
}

- (void)unbindFromPerson:(Person*)person;
{
    // don't tell me when person changed its name
    [person removeObserver:self
                forKeyPath:@"name"
                   context:kPersonNameKVOContext];

//NSDictionary* personDict =
//@{@"name": @"Brian",
//  @"occupation": @{@"title": @"Developer",
//                   @"company": @{@"name": @"Spotify"}}};
//                       
    
NSLog(@"Hello my name is %@ and I'm a %@ at %@",
      [person valueForKey:@"name"],
      [person valueForKeyPath:@"occupation.title"],
      [person valueForKeyPath:@"occupation.company.name"]);
// Hello my name is Brian and I'm a Developer at Spotify
}

- (void)foo
{
Person* person = [Person new];
[person addObserver:self forKeyPath:@"name" options:0 context:NULL];
person = nil;
// !!! "Observation info was leaked, and may even become mistakenly attached to some other object"
}

- (void)unbindPerson:(Person*)person
{
@try {
    [person removeObserver:self forKeyPath:@"name" context:NULL];
    [person removeObserver:self forKeyPath:@"about" context:NULL];
    [person removeObserver:self forKeyPath:@"favorite" context:NULL];
}
@catch (NSException *exception) { NSLog(@"LAME!"); }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == kPersonNameKVOContext) {
        Person* person = (Person*)object;
        NSLog(@"Nice to meet you, %@", person.name);
    }
}

@end

@implementation Person

- (void)setOccupation:(Occupation *)occupation
{
    if ([occupation isKindOfClass:[NSDictionary class]]) {
        _occupation = [Occupation fromJSON:(NSDictionary*)occupation];
        return;
    }
    _occupation = occupation;
}

@end

@implementation Occupation

- (void)setCompany:(Company *)company
{
    if ([company isKindOfClass:[NSDictionary class]]) {
        _company = [Company fromJSON:(NSDictionary*)company];
        return;
    }
    
    _company = company;
}

@end

@implementation NSObject (JSONFactory)

+ (instancetype)fromJSON:(NSDictionary *)json
{
    id instance = [[[self class] alloc] init];
    [instance setValuesForKeysWithDictionary:json];
    return instance;
}

@end
