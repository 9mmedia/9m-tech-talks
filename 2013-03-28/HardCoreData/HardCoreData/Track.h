//
//  Track.h
//  HardCoreData
//
//  Created by Ben Fisher on 3/28/13.
//  Copyright (c) 2013 9MMEDIA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "RdioObject.h"

@class Album, Artist;

@interface Track : RdioObject

@property (nonatomic, retain) NSNumber * number;
@property (nonatomic, retain) Album *album;
@property (nonatomic, retain) Artist *artist;

@end
