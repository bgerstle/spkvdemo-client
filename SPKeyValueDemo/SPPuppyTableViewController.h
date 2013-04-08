//
//  SPPuppyTableViewController.h
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SPPuppyStorage.h"

@interface SPPuppyTableViewController : UITableViewController
@property (nonatomic, strong) SPPuppyStorage* storage;
@end
