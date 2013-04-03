//
//  DataManager.h
//  HardCoreData
//
//  Created by Ben Fisher on 3/27/13.
//  Copyright (c) 2013 9MMEDIA. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "RdioService.h"
#import "DataClasses.h"

@interface DataManager : NSObject

+ (id)sharedManager;

/*!
 The NSManagedObjectContext for use on the main thread.
 */
@property (readonly) NSManagedObjectContext * mainContext;

/*!
 Saves the main context safely.
 */
- (void)saveMainContext;


/*!
 A temporary NSManagedObjectContext that is a child of the main context and uses a private queue
 */
@property (readonly) NSManagedObjectContext *tempContext;

/*!
 The NSManagedObjectContext for syncing off of the main queue
 */
@property (readonly) NSManagedObjectContext *syncContext;

/*!
 An NSManagedObjectContext suitable for testing without affecting the main context
 */
@property (readonly) NSManagedObjectContext *testContext;

/*!
 URL where app's data is stored on disk.
 */
+ (NSURL*)dataDirectoryURL;

/*!
 The managed instance of RdioService.
 */
@property (nonatomic,readonly) RdioService *rdioService;

- (void)findOrCreateRdioObjectsWithKeys:(NSSet *)serverKeys
                             inContext:(NSManagedObjectContext *)context
                            completion:(void (^)(NSDictionary *oldObjects, NSDictionary *newObjects, NSError *error))completion;


@end

@interface NSManagedObjectContext (DataManager)
- (BOOL)isMainContext;
- (BOOL)saveContext;
- (NSArray*)performFetchWithRequest:(NSFetchRequest*)request;
@end

@interface NSFetchedResultsController (DataManager)
- (BOOL)performFetch;
@end

@interface NSDate (DataManager)
- (NSDate*)beginningOfDay;
- (NSDate*)endOfDay;
@end
