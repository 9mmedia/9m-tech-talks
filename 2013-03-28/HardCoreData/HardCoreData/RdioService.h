//
//  RdioService.h
//  HardCoreData
//
//  Created by Ben Fisher on 3/28/13.
//  Copyright (c) 2013 9MMEDIA. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^RdioRequestCompletion)(NSDictionary *resultsByKey, NSError *error);

@interface RdioService : NSObject

+ (NSString*)entityNameForRdioKey:(NSString*)key;

- (id)requestRdioObjectsWithKeys:(NSSet*)keyStrings completion:(RdioRequestCompletion)completion;
- (id)requestHeavyRotation:(RdioRequestCompletion)completion;
- (void)cancelRequest:(id)requestToCancel;

@end
