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

@property (readonly, nonatomic) NSURL *url;
@property (readonly, nonatomic) AVAsset *asset;
@property (readonly, nonatomic) CMTime duration;
@property (readonly, nonatomic) UIImage *thumbnail;
@property (readonly, nonatomic) UIImage *lastImage;
@property (readonly, nonatomic) float frameRate;

- (instancetype)initWithURL:(NSURL *)url;

- (void)deleteFile;

+ (SCRecordSessionSegment *)segmentWithURL:(NSURL *)url;

@end
