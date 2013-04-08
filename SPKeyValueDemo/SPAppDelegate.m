//
//  SPAppDelegate.m
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPAppDelegate.h"
#import <MDWamp/MDWamp.h>
#import "SPPuppyTableViewController.h"
#import "SPPromise.h"

@interface SPAppDelegate ()
<MDWampDelegate>
{
    MDWamp* _wampSocket;
    SPDeferred* _wampDeferred;
}

@end

@implementation SPAppDelegate

#pragma mark - MDWampDelegate

- (void)onOpen
{
    static NSDictionary* prefixesURIMap = nil;
    if (!prefixesURIMap){
        prefixesURIMap = @{@"pups": @"http://spkvexample.com/pups/"};
    }
    
    [prefixesURIMap enumerateKeysAndObjectsUsingBlock:^(NSString* prefix, NSString* uri, BOOL *stop) {
        [_wampSocket prefix:prefix uri:uri];
    }];
    
    [_wampDeferred resolveWith:_wampSocket];
}

- (void)onClose:(int)code reason:(NSString *)reason
{
    [_wampDeferred reject:[NSError errorWithDomain:@"MDWampErrorDomain"
                                              code:code
                                          userInfo:@{NSLocalizedFailureReasonErrorKey: reason}]];
    _wampDeferred = nil;
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [MDWamp setDebug:YES];
    
    _wampDeferred = [[SPDeferred alloc] init];
    
    _wampSocket = [[MDWamp alloc] initWithUrl:@"ws://localhost:9000" delegate:self];
    
    [_wampSocket connect];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.viewController = [[SPPuppyTableViewController alloc] initWithStyle:UITableViewStylePlain];
    
    [self.viewController setSocketOpenPromise:_wampDeferred.promise];
    
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
