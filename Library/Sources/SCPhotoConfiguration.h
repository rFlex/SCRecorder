//
//  SCPhotoConfiguration.h
//  SCRecorder
//
//  Created by Simon CORSIN on 24/11/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCMediaTypeConfiguration.h"

@interface SCPhotoConfiguration : NSObject

/**
 Whether the photo output is enabled or not.
 Changing this value after the session has been opened
 on the SCRecorder has no effect.
 */
@property (assign, nonatomic) BOOL enabled;

/**
 If set, every other properties but "enabled" will be ignored
 and this options dictionary will be used instead.
 */
@property (copy, nonatomic) NSDictionary *options;

/**
 Returns the output settings for the 
 */
- (NSDictionary *)createOutputSettings;

@end
