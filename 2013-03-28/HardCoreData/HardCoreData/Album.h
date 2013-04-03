//
//  Album.h
//  HardCoreData
//
//  Created by Ben Fisher on 3/28/13.
//  Copyright (c) 2013 9MMEDIA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "RdioObject.h"

@class AlbumRanking, Artist, Track;

@interface Album : RdioObject

@property (nonatomic, retain) NSString * imageLink;
@property (nonatomic, retain) Artist *artist;
@property (nonatomic, retain) NSSet *rankings;
@property (nonatomic, retain) NSSet *tracks;
@end

@interface Album (CoreDataGeneratedAccessors)

- (void)addRankingsObject:(AlbumRanking *)value;
- (void)removeRankingsObject:(AlbumRanking *)value;
- (void)addRankings:(NSSet *)values;
- (void)removeRankings:(NSSet *)values;

- (void)addTracksObject:(Track *)value;
- (void)removeTracksObject:(Track *)value;
- (void)addTracks:(NSSet *)values;
- (void)removeTracks:(NSSet *)values;

@end
