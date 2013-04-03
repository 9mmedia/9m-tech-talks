//
//  HeavyRotationVC.m
//  HardCoreData
//
//  Created by Ben Fisher on 3/28/13.
//  Copyright (c) 2013 9MMEDIA. All rights reserved.
//

#import "HeavyRotationVC.h"
#import "RdioService.h"
#import "UIImageView+AFNetworking.h"

@interface HeavyRotationVC () <NSFetchedResultsControllerDelegate>

@property (nonatomic,strong) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic,weak) id pendingRequest;

@end

@implementation HeavyRotationVC

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  NSFetchedResultsController *fetchedResultsController = [self fetchedResultsController];
  [fetchedResultsController.fetchRequest setPredicate:[self updatedPredicate]];
  [fetchedResultsController performFetch];
  [fetchedResultsController setDelegate:self];
  [self.tableView reloadData];
  
  if ( [fetchedResultsController.fetchedObjects count] == 0 ) {
    RdioService *rdio = [[DataManager sharedManager] rdioService];
    id request = [rdio requestHeavyRotation:nil];
    self.pendingRequest = request;
  }
  
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  
  RdioService *rdio = [[DataManager sharedManager] rdioService];
  [rdio cancelRequest:self.pendingRequest];
  
 [self.fetchedResultsController setDelegate:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return [self.fetchedResultsController.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
  id<NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController.sections objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"PopularAlbumCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
  AlbumRanking *rankingObject = (AlbumRanking*)[self.fetchedResultsController objectAtIndexPath:indexPath];
  cell.textLabel.text = rankingObject.album.name;
  cell.detailTextLabel.text = rankingObject.album.artist.name;
  
  [cell.imageView setImageWithURL:[NSURL URLWithString:rankingObject.album.imageLink] placeholderImage:[UIImage imageNamed:@"Default.png"]];
  
    return cell;
}


#pragma mark - Fetched Results Controller Delegate
- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
  [self.tableView reloadData];
}


#pragma mark - Convenience methods
- (NSFetchedResultsController*)fetchedResultsController
{
  if (!_fetchedResultsController) {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([AlbumRanking class])];
    [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:NO]]];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc]initWithFetchRequest:request
                                                                   managedObjectContext:[[DataManager sharedManager]mainContext]
                                                                     sectionNameKeyPath:nil
                                                                              cacheName:nil];
    
  }
  return _fetchedResultsController;
}

- (NSPredicate*)updatedPredicate
{
  NSDate *now = [NSDate date];
  return [NSPredicate predicateWithFormat:@"date >= %@ && date <= %@",[now beginningOfDay],[now endOfDay]];
}
@end
