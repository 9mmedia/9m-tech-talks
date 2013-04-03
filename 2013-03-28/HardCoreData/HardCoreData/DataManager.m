//
//  DataManager.m
//  HardCoreData
//
//  Created by Ben Fisher on 3/27/13.
//  Copyright (c) 2013 9MMEDIA. All rights reserved.
//

#import "DataManager.h"

#import "RdioService.h"

#ifndef DATA_MODEL_BASE_NAME
#define DATA_MODEL_BASE_NAME @"DataModel"
#endif

#ifndef PERSISTENT_STORE_FILENAME
# define PERSISTENT_STORE_FILENAME @"DataStore"
#endif

#ifndef DELETES_PERSISTENT_STORE_ON_LAUNCH
# define DELETES_PERSISTENT_STORE_ON_LAUNCH NO
#endif

@interface DataManager () {
  NSManagedObjectContext *_mainContext;
  NSManagedObjectContext *_syncContext;
  NSManagedObjectContext *_writeContext;
  NSManagedObjectModel *_managedObjectModel;
  NSPersistentStoreCoordinator *_persistentStoreCoordinator;
  
  RdioService *_rdioService;
}

@end

@implementation DataManager

#pragma mark - Object Lifecycle
+ (id)sharedManager
{
  static DataManager *__sharedManager;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    __sharedManager = [[DataManager alloc] initPrivate];
  });
  return __sharedManager;
}

- (id)initPrivate
{
  self = [super init];
  if (self) {
    [self setupCoreDataStack];
  }
  return self;
}

- (id)init { NSAssert(false, @"-init should never be called on DataManager"); return nil; }

#pragma mark - Core Data Setup
- (void)setupCoreDataStack
{
  NSURL *modelURL = [[NSBundle mainBundle]URLForResource:DATA_MODEL_BASE_NAME withExtension:@"momd"];
  _managedObjectModel = [[NSManagedObjectModel alloc]initWithContentsOfURL:modelURL];
  
  NSAssert1(_managedObjectModel, @"ERROR::%@ failed to create the managed object model", [self class] );
  
  NSError *error;
  
  NSDictionary* options = @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES};
  
  NSURL *persistentStoreURL = [[DataManager dataDirectoryURL]URLByAppendingPathComponent:PERSISTENT_STORE_FILENAME];
  
  // this is nice for debugging; delete the underlying store and start fresh
  if ( DELETES_PERSISTENT_STORE_ON_LAUNCH ) [[NSFileManager defaultManager] removeItemAtURL:persistentStoreURL error:NULL];
  
  _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_managedObjectModel];
  NSPersistentStore *persistentStore = [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                                 configuration:nil
                                                                                           URL:persistentStoreURL
                                                                                       options:options
                                                                                         error:&error];
  
  // hack for if you were naughty and didn't version your model; or are developing v1
  if ([error code]==134130) { // data model has changed. for now, delete the persistent store
    [[NSFileManager defaultManager]removeItemAtURL:persistentStoreURL error:NULL];
    persistentStore = [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                configuration:nil
                                                                          URL:persistentStoreURL
                                                                      options:options
                                                                        error:&error];
  }
  NSAssert2(persistentStore, @"ERROR::%@ failed to add persistent store.\n%@", [self class], error);
  
  _writeContext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
  [_writeContext setPersistentStoreCoordinator:_persistentStoreCoordinator];
  
  
}

+ (NSURL*)dataDirectoryURL
{
  static NSURL* url = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSError* error = nil;
    NSFileManager* fileManager = [[NSFileManager alloc] init];
    url = [[[fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error]
            URLByAppendingPathComponent:[[NSBundle mainBundle]bundleIdentifier] isDirectory:YES]
           URLByAppendingPathComponent:@"data" isDirectory:YES];
    [fileManager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error];
    NSAssert1(!error, @"ERROR::Unable to create directory.\n%@",error);
  });
  
  return url;
}


#pragma mark - Rdio Object Management
- (RdioService*)rdioService
{
  if (!_rdioService) {
    _rdioService = [RdioService new];
  }
  return _rdioService;
}

- (void)findOrCreateRdioObjectsWithKeys:(NSSet *)serverKeys
                              inContext:(NSManagedObjectContext *)context
                             completion:(void (^)(NSDictionary *, NSDictionary *, NSError *))completion
{
  NSParameterAssert(context);
  
  [context performBlock:^{
    
    // first, we sort the keys we want objects for
    NSArray *sortedKeys = [serverKeys sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:nil ascending:YES]]];
    
    // now let's find the existing objects for those keys with the same sorting
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([RdioObject class])];
    [request setPredicate:[NSPredicate predicateWithFormat:@"key in %@",serverKeys]];
    [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"key" ascending:YES]]];
    NSArray *sortedObjects = [context performFetchWithRequest:request];
    
    __block NSMutableDictionary *newObjects = [NSMutableDictionary dictionary];
    __block NSMutableDictionary *oldObjects = [NSMutableDictionary dictionary];
    __block NSMutableArray *existingObjects = [NSMutableArray arrayWithArray:sortedObjects];
    
    [sortedKeys enumerateObjectsUsingBlock:^(NSString *serverKey, NSUInteger idx, BOOL *stop) {
      RdioObject *existingObject = idx < [existingObjects count] ? [existingObjects objectAtIndex:idx] : nil;
      if (![serverKey isEqualToString:[existingObject key]]) {
        RdioObject *newObject = [NSEntityDescription insertNewObjectForEntityForName:[RdioService entityNameForRdioKey:serverKey] inManagedObjectContext:context];
        [newObject setKey:serverKey];
        [existingObjects insertObject:newObject atIndex:idx];
        newObjects[serverKey] = newObject;
      }else{
        oldObjects[serverKey] = existingObject;
      }
    }];
    
    NSUInteger numPending = [[context insertedObjects]count];
    if ( numPending > 0 ) {
      NSLog(@"Creating %i new objects",numPending);
      [context saveContext];
    }
    
    if (completion) {
      completion(oldObjects,newObjects,nil);
    }
    
  }];
  
}

#pragma mark - Property Implementation

- (NSManagedObjectContext*)mainContext
{
  if (!_mainContext) {
    _mainContext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_mainContext setParentContext:_writeContext];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(writeChangesToStore) name:NSManagedObjectContextDidSaveNotification object:_mainContext];
  }
  return _mainContext;
}


- (NSManagedObjectContext*)syncContext
{
  if (!_syncContext) {
    _syncContext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [_syncContext setParentContext:[self mainContext]];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(saveMainContext) name:NSManagedObjectContextDidSaveNotification object:_syncContext];
  }
  return _syncContext;
}


- (NSManagedObjectContext*)tempContext
{
  NSManagedObjectContext *tempContext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
  [tempContext setParentContext:[self mainContext]];
  return tempContext;
}

- (NSManagedObjectContext*)testContext
{
  NSManagedObjectContext *testContext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
  [testContext setParentContext:[self tempContext]];
  return testContext;
}


#pragma mark - Convenience methods
- (void)saveMainContext
{
  NSManagedObjectContext *mainContext = [self mainContext];
  [mainContext performBlock:^{
    [mainContext saveContext];
  }];
}

- (void)writeChangesToStore
{
  [_writeContext performBlock:^{
    [_writeContext saveContext];
  }];
}

@end

#pragma mark - Category Implementations

@implementation NSManagedObjectContext (DataManager)

- (BOOL)isMainContext { return (self==[[DataManager sharedManager] mainContext]); }

- (BOOL)saveContext
{
  NSError *error;
  BOOL saved = [self save:&error];
  NSAssert2(!error, @"%@ failed to save: %@", NSStringFromClass([self class]),error);
  return saved;
}

- (NSArray*)performFetchWithRequest:(NSFetchRequest*)request
{
  NSError *error;
  NSArray *results = [self executeFetchRequest:request error:&error];
  NSAssert2(!error, @"%@ failed to fetch: %@", NSStringFromClass([self class]),error);
  return results;
}

@end

@implementation NSFetchedResultsController (DataManager)

- (BOOL)performFetch
{
  NSError *error;
  BOOL fetched = [self performFetch:&error];
  NSAssert2(!error, @"%@ failed to fetch: %@", NSStringFromClass([self class]),error);
  return fetched;
}

@end

@implementation NSDate (DataManager)

- (NSDate*)beginningOfDay
{
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSDateComponents *components = [cal components:( NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ) fromDate: self];
  
  [components setHour:0];
  [components setMinute:0];
  [components setSecond:0];
  
  return [cal dateFromComponents:components];
}

- (NSDate*)endOfDay
{
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSDateComponents *components = [cal components:( NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ) fromDate: self];
  
  [components setHour:23];
  [components setMinute:59];
  [components setSecond:59];
  
  return [cal dateFromComponents:components];
}

@end
