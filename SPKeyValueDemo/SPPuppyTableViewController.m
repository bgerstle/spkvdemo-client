//
//  SPPuppyTableViewController.m
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPPuppyTableViewController.h"
#import "SPFunctional.h"
#import "SPLowVerbosity.h"
#import "SPDepends.h"

@interface SPPuppyTableViewController ()
@property (nonatomic, strong) UIView* maskView;
@end

#define kCellBindingFormat @"%d.%@"

@implementation SPPuppyTableViewController

- (void)setStorage:(SPPuppyStorage *)storage
{
    if (![storage isEqual:_storage]) {
        _storage = storage;
        [self maybeAddStorageDependencies];
    }
}

- (void)maybeAddStorageDependencies
{
    if (!_storage || ![self isViewLoaded]) {
        return;
    }
    
    [self sp_removeDependency:@"puppies"];
    [self sp_removeDependency:@"pupsOnline"];
    
    $sp_decl_wself;
    SPAddDependencyV(self,@"puppies", _storage, @"puppies", ^ (NSDictionary* change, id obj, NSString* keypath){
        NSLog(@"Updating table w/ change: %@", change);
        [weakSelf.tableView beginUpdates];
        
        NSIndexSet* indexes = change[NSKeyValueChangeIndexesKey];
        NSMutableArray* indexPaths = [[NSMutableArray alloc] initWithCapacity:[indexes count]];
        [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
        }];
        switch ([change[NSKeyValueChangeKindKey] intValue]) {
            case NSKeyValueChangeRemoval:
                [weakSelf.tableView deleteRowsAtIndexPaths:indexPaths
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            case NSKeyValueChangeInsertion:
                [weakSelf.tableView insertRowsAtIndexPaths:indexPaths
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            default:
                break;
        }
        
        [weakSelf.tableView endUpdates];
    }, nil);
    
    SPAddDependencyV(self, @"pupsOnline", _storage, @"online", ^ (NSDictionary* change, id obj, NSString* keypath) {
        if ([weakSelf.storage isOnline]) {
            [weakSelf.storage getPups];
            [weakSelf.storage subscribeToPups];
            [weakSelf.maskView removeFromSuperview];
        } else {
            if(weakSelf.maskView.superview) {
                return;
            } else if (!weakSelf.maskView) {
                weakSelf.maskView = [[UIView alloc] initWithFrame:weakSelf.view.bounds];
                weakSelf.maskView.backgroundColor = [UIColor blackColor];
                weakSelf.maskView.alpha = 0.7;
                weakSelf.maskView.userInteractionEnabled = NO;
            }
        
            [weakSelf.view addSubview:_maskView];
        }
    }, nil);
}

#pragma mark - UITableViewController Stuff

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    [self maybeAddStorageDependencies];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [[_storage valueForKeyPath:@"puppies.@count"] intValue];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    SPPuppy* pup = [_storage mutableArrayValueForKey:@"puppies"][indexPath.row];
    
    // Configure the cell...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
    // hiding warnig for unused weak self (selff) var declared by $depends
    $depends($sprintf(kCellBindingFormat, indexPath.row, @"name"), pup, @"name",
             ^ (NSDictionary* change, id obj, NSString* keypath) {
                 cell.textLabel.text = pup.name;
             }, nil);
    $depends($sprintf(kCellBindingFormat, indexPath.row, @"about"), pup, @"about",
             ^ (NSDictionary* change, id obj, NSString* keypath) {
                 cell.detailTextLabel.text = pup.about;
             }, nil);
    $depends($sprintf(kCellBindingFormat, indexPath.row, @"favorite"), pup, @"favorite",
             ^ (NSDictionary* change, id obj, NSString* keypath) {
                 cell.accessoryType = pup.isFavorite ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
             }, nil);
#pragma clang diagnostic pop
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self sp_removeDependency:$sprintf(kCellBindingFormat, indexPath.row, @"name")];
    [self sp_removeDependency:$sprintf(kCellBindingFormat, indexPath.row, @"about")];
    [self sp_removeDependency:$sprintf(kCellBindingFormat, indexPath.row, @"favorite")];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

@end
