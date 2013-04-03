//
//  AlbumsVC.m
//  HardCoreData
//
//  Created by Ben Fisher on 3/27/13.
//  Copyright (c) 2013 9MMEDIA. All rights reserved.
//

#import "AlbumsVC.h"

@interface AlbumsVC ()

@end

@implementation AlbumsVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSFetchedResultsController*)fetchedResultsController
{
  NSFetchedResultsController *fetchedResultsController = [super fetchedResultsController];
  if (!fetchedResultsController) {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([Album class])];
    [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    
    fetchedResultsController = [[NSFetchedResultsController alloc]initWithFetchRequest:request
                                                                  managedObjectContext:[[DataManager sharedManager]mainContext]
                                                                    sectionNameKeyPath:nil
                                                                             cacheName:nil];
    [super setFetchedResultsController:fetchedResultsController];
  }
  return fetchedResultsController;
}

@end
