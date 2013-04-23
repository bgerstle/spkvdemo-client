//
//  SPKVODemoTableViewController.h
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SPKVODemoStorage.h"

@interface SPKVODemoTableViewController : UITableViewController
@property (nonatomic, strong) SPKVODemoStorage* storage;
@end
