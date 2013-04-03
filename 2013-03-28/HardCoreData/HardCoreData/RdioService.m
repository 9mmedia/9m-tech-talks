//
//  RdioService.m
//  HardCoreData
//
//  Created by Ben Fisher on 3/28/13.
//  Copyright (c) 2013 9MMEDIA. All rights reserved.
//

#import "RdioService.h"
#import <Rdio/Rdio.h>


@interface RdioService () <RdioDelegate,RDAPIRequestDelegate>

@property (nonatomic,strong) Rdio *rdio;
@property (nonatomic,strong) NSMutableDictionary *pendingRequests;

@end


@implementation RdioService

- (id)init
{
  self = [super init];
  if (self) {
    _pendingRequests = [NSMutableDictionary new];
    NSAssert([RDIO_CONSUMER_KEY length]>0, @"No Rdio Consumer Key Provided");
    NSAssert([RDIO_CONSUMER_SECRET length]>0, @"No Rdio Consumer Secret Provided");
    _rdio = [[Rdio alloc]initWithConsumerKey:RDIO_CONSUMER_KEY andSecret:RDIO_CONSUMER_SECRET delegate:self];
  }
  return self;
}

+ (NSString*)entityNameForRdioKey:(NSString*)key
{
  NSString *entityName;
  NSString *firstLetter = [key substringToIndex:1];
  if ([firstLetter isEqualToString:@"t"]) entityName = NSStringFromClass([Track class]);
  else if ([firstLetter isEqualToString:@"a"]) entityName = NSStringFromClass([Album class]);
  else if ([firstLetter isEqualToString:@"r"]) entityName = NSStringFromClass([Artist class]);
  NSAssert1(entityName, @"Undefined rdio type for key '%@'", key);
  return entityName;
}

- (id)requestRdioObjectsWithKeys:(NSSet*)keyStrings completion:(RdioRequestCompletion)completion
{
  NSParameterAssert([NSThread isMainThread]);
  
  NSMutableDictionary *params = [NSMutableDictionary new];
  params[@"keys"] = [[keyStrings allObjects]componentsJoinedByString:@","];
  
  RDAPIRequest *request = [self.rdio callAPIMethod:@"get" withParameters:params delegate:self];
  
  if (completion) {
    _pendingRequests[request.parameters] = completion;
  }else{
    _pendingRequests[request.parameters] = [NSNull null];
  }
  
  return request;
}

- (id)requestHeavyRotation:(RdioRequestCompletion)completion
{
  NSParameterAssert([NSThread isMainThread]);
  
  NSDictionary *params = @{@"type":@"albums",@"count":@"100"};
  
  RDAPIRequest *request = [self.rdio callAPIMethod:@"getHeavyRotation" withParameters:params delegate:self];
  
  if (completion) {
    _pendingRequests[request.parameters] = completion;
  }else{
    _pendingRequests[request.parameters] = [NSNull null];
  }
  
  return request;
}

- (void)cancelRequest:(id)requestToCancel
{
  if ([requestToCancel isKindOfClass:[RDAPIRequest class]]) {
    RDAPIRequest *request = (RDAPIRequest*)requestToCancel;
    [request cancel];
    [_pendingRequests removeObjectForKey:request.parameters];
  }
}

- (void)rdioRequest:(RDAPIRequest *)request didFailWithError:(NSError *)error
{
  dispatch_async(dispatch_get_main_queue(), ^{
    id completionOrNull = _pendingRequests[request.parameters];
    if ( completionOrNull && completionOrNull!=[NSNull null] ) {
      RdioRequestCompletion completion = _pendingRequests[request.parameters];
      completion(nil,error);
    }
    [_pendingRequests removeObjectForKey:request.parameters];
  });
}

- (void)rdioRequest:(RDAPIRequest *)request didLoadData:(id)data
{
  dispatch_async(dispatch_get_main_queue(), ^{
    RdioRequestCompletion completion;
    id completionOrNull = _pendingRequests[request.parameters];
    if ( completionOrNull && completionOrNull!=[NSNull null] ) {
      completion = _pendingRequests[request.parameters];
    }
    [_pendingRequests removeObjectForKey:request.parameters];
    
    NSDate *rankDate = [NSDate date];
    DataManager *dataManager = [DataManager sharedManager];
    NSManagedObjectContext *syncContext = [dataManager syncContext];
    [syncContext performBlock:^{
      if ([request.parameters[@"method"] isEqualToString:@"getHeavyRotation"]) {
        // we know this returns an array of albums
        NSArray *albumsArray = (NSArray*)data;
        
        // get the rdio keys for all albums
        NSSet *albumKeys = [NSSet setWithArray:[albumsArray valueForKeyPath:@"key"]];
        
        // find existing managed objects for these keys or create new ones
        [dataManager findOrCreateRdioObjectsWithKeys:albumKeys inContext:syncContext completion:^(NSDictionary *oldObjects, NSDictionary *newObjects, NSError *error) {
          
          for (NSDictionary *albumDict in albumsArray) {
            
            // insert new object into the sync context
            AlbumRanking *ranking = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([AlbumRanking class]) inManagedObjectContext:syncContext];
            NSString *albumKey = albumDict[@"key"];
            ranking.album = oldObjects[albumKey] ?: newObjects[albumKey];
            ranking.rank = albumDict[@"hits"];
            ranking.date = rankDate;
            
            if (newObjects[albumKey]) { // then its a new object so populate it
              Album *newAlbum = ranking.album;
              newAlbum.name = albumDict[@"name"];
              newAlbum.imageLink = albumDict[@"icon"];
              
              Artist *newArtist = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([Artist class]) inManagedObjectContext:syncContext];
              newArtist.name = albumDict[@"artist"];
              newArtist.key = albumDict[@"artistKey"];
              
              newAlbum.artist = newArtist;
            }
            
          }
          
          // save the sync context which will push changes up to the main context
          NSUInteger numPending = [[syncContext updatedObjects]count] + [[syncContext insertedObjects]count];
          NSLog(@"Saving %i objects",numPending);
          [syncContext saveContext];
          
          // hackish completion block returning no objects
          if (completion) completion(nil,error);
          
        }];
      }else{
        // create objects here
      }
    }];
  });
}

@end
