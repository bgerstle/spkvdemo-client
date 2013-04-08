//
//  SPAppDelegate.h
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SPPuppyTableViewController;

@interface SPAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) SPPuppyTableViewController *viewController;

@end
