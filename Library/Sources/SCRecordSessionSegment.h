//
//  SCRecordSessionSegment.h
//  SCRecorder
//
//  Created by Simon CORSIN on 10/03/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface SCRecordSessionSegment : NSObject

/**
 The url containing the segment data
 */
@property (readonly, nonatomic) NSURL *url;

/**
 The AVAsset created from the url.
 */
@property (readonly, nonatomic) AVAsset *asset;

/**
 The duration of this segment
 */
@property (readonly, nonatomic) CMTime duration;

/**
 The thumbnail that represents this segment
 */
@property (readonly, nonatomic) UIImage *thumbnail;

/**
 The lastImage of this segment. This can be used for implement
 features like Vine's ghost mode.
 */
@property (readonly, nonatomic) UIImage *lastImage;

/**
 The average frameRate of this segment
 */
@property (readonly, nonatomic) float frameRate;

/**
 The custom info dictionary.
 */
@property (readonly, nonatomic) NSDictionary *info;


/**
 Initialize with an URL and an info dictionary
 */
- (instancetype)initWithURL:(NSURL *)url info:(NSDictionary *)info;

/**
 Delete the file at the url. This will make the segment unusable.
 */
- (void)deleteFile;

/**
 Create and init a segment using an URL and an info dictionary
 */
+ (SCRecordSessionSegment *)segmentWithURL:(NSURL *)url info:(NSDictionary *)info;

@end
