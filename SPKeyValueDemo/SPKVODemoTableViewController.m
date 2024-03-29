//
//  SPKVODemoTableViewController.m
//  SPKeyValueDemo
//
//  Created by Brian Gerstle on 4/8/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPKVODemoTableViewController.h"
#import "SPFunctional.h"
#import "SPLowVerbosity.h"
#import "SPDepends.h"

@interface SPKVODemoTableViewController ()
@property (nonatomic, strong) UIView* maskView;
@end

#define kCellBindingFormat @"%d.%@"
static void* kObjectsCollectionKVOC = &kObjectsCollectionKVOC;
static void* kStorageOnlineKVOC = &kStorageOnlineKVOC;
static void* kObjCellViewKVOC = &kObjCellViewKVOC;

@implementation SPKVODemoTableViewController

- (void)setStorage:(SPKVODemoStorage *)storage
{
    if (![storage isEqual:_storage]) {
        _storage = storage;
        [self maybeAddStorageDependencies];
    }
}

- (void)unbindPup:(SPKVODemoObject*)pup
{
    @try {
        [pup removeObserver:self forKeyPath:@"name" context:kObjCellViewKVOC];
        [pup removeObserver:self forKeyPath:@"about" context:kObjCellViewKVOC];
        [pup removeObserver:self forKeyPath:@"favorite" context:kObjCellViewKVOC];
    }
    @catch (NSException *exception) { NSLog(@"OH EM GEE"); }
}

- (void)bindPup:(SPKVODemoObject*)pup
{
    [pup addObserver:self forKeyPath:@"name" options:0 context:kObjCellViewKVOC];
    [pup addObserver:self forKeyPath:@"about" options:0 context:kObjCellViewKVOC];
    [pup addObserver:self forKeyPath:@"favorite" options:0 context:kObjCellViewKVOC];
}

- (void)maybeAddStorageDependencies
{
    if (!_storage || ![self isViewLoaded]) {
        return;
    }
    
    @try {
        [_storage removeObserver:self forKeyPath:@"objects"];
        [_storage removeObserver:self forKeyPath:@"online"];
    }
    @catch (NSException *exception) { NSLog(@"OH EM GEE"); }


    [_storage addObserver:self
               forKeyPath:@"objects"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionPrior
                  context:kObjectsCollectionKVOC];
    
    [_storage addObserver:self
               forKeyPath:@"online"
                  options:NSKeyValueObservingOptionInitial
                  context:kStorageOnlineKVOC];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kObjectsCollectionKVOC) {
        NSLog(@"Updating table w/ change: %@", change);
        
        if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {            
            if ([change[NSKeyValueChangeKindKey] intValue] == NSKeyValueChangeRemoval) {
                [change[NSKeyValueChangeIndexesKey] enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                    SPKVODemoObject* pupToBeRemoved = [_storage mutableArrayValueForKey:@"objects"][idx];
                    [self unbindPup:pupToBeRemoved];
                }];
            }
            
            return;
        }
        
        [self.tableView beginUpdates];
        
        NSIndexSet* indexes = change[NSKeyValueChangeIndexesKey];
        NSMutableArray* indexPaths = [[NSMutableArray alloc] initWithCapacity:[indexes count]];
        [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
        }];
        switch ([change[NSKeyValueChangeKindKey] intValue]) {
            case NSKeyValueChangeRemoval:
                [self.tableView deleteRowsAtIndexPaths:indexPaths
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            case NSKeyValueChangeInsertion:
                [self.tableView insertRowsAtIndexPaths:indexPaths
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            default:
                [self.tableView reloadData];
                break;
        }
        
        [self.tableView endUpdates];
    } else if (context == kStorageOnlineKVOC) {
        if ([self.storage isOnline]) {
            [self.storage getRemoteObjects];
            [self.storage subscribeToAllObjects];
            [self.maskView removeFromSuperview];
        } else {
            if(self.maskView.superview) {
                return;
            } else if (!self.maskView) {
                self.maskView = [[UIView alloc] initWithFrame:self.view.bounds];
                self.maskView.backgroundColor = [UIColor blackColor];
                self.maskView.alpha = 0.7;
                self.maskView.userInteractionEnabled = NO;
            }
            
            [self.view addSubview:_maskView];
        }
    } else if (context == kObjCellViewKVOC) {
        SPKVODemoObject* pup = (SPKVODemoObject*)object;
        int index = [[_storage mutableArrayValueForKey:@"objects"] indexOfObject:pup];
        UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        if (!cell) {
            return;
        }
        if ([keyPath isEqualToString:@"name"]) {
            cell.textLabel.text = pup.name;
        } else if ([keyPath isEqualToString:@"about"]) {
            cell.detailTextLabel.text = pup.about;
        } else /*if ([keyPath isEqualToString:@"favorite"])*/ {
            cell.accessoryType = pup.isFavorite ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
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
    return [[_storage valueForKeyPath:@"objects.@count"] intValue];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    SPKVODemoObject* pup = [_storage mutableArrayValueForKey:@"objects"][indexPath.row];
    
    // Configure the cell...
    [self bindPup:pup];
    
    cell.textLabel.text = pup.name;
    cell.detailTextLabel.text = pup.about;
    cell.accessoryType = pup.isFavorite ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
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
    if (indexPath.row >= [[_storage valueForKeyPath:@"objects.@count"] intValue]) {
        return;
    }
    
    SPKVODemoObject* pup = [_storage mutableArrayValueForKey:@"objects"][indexPath.row];
    [self unbindPup:pup];
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
