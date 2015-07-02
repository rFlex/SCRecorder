//
//  SCVideoConfiguration.h
//  SCRecorder
//
//  Created by Simon CORSIN on 21/11/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCMediaTypeConfiguration.h"
#import "SCFilter.h"

#define kSCVideoConfigurationDefaultCodec AVVideoCodecH264
#define kSCVideoConfigurationDefaultScalingMode AVVideoScalingModeResizeAspectFill
#define kSCVideoConfigurationDefaultBitrate 2000000

typedef enum : NSUInteger {
    SCWatermarkAnchorLocationTopLeft,
    SCWatermarkAnchorLocationTopRight,
    SCWatermarkAnchorLocationBottomLeft,
    SCWatermarkAnchorLocationBottomRight
} SCWatermarkAnchorLocation;

@protocol SCVideoOverlay <NSObject>

@optional

- (void)updateWithVideoTime:(NSTimeInterval)time;

@end

@interface SCVideoConfiguration : SCMediaTypeConfiguration

/**
 Change the size of the video
 If options has been changed, this property will be ignored
 If this value is CGSizeZero, the input video size received
 from the camera will be used
 Default is CGSizeZero
 */
@property (assign, nonatomic) CGSize size;

/**
 Change the affine transform for the video
 If options has been changed, this property will be ignored
 */
@property (assign, nonatomic) CGAffineTransform affineTransform;

/**
 Set the codec used for the video
 Default is AVVideoCodecH264
 */
@property (copy, nonatomic) NSString *__nonnull codec;

/**
 Set the video scaling mode
 */
@property (copy, nonatomic) NSString *__nonnull scalingMode;

/**
 The maximum framerate that this SCRecordSession should handle
 If the camera appends too much frames, they will be dropped.
 If this property's value is 0, it will use the current video
 framerate from the camera.
 */
@property (assign, nonatomic) CMTimeScale maxFrameRate;

/**
 The time scale of the video
 A value more than 1 will make the buffers last longer, it creates
 a slow motion effect. A value less than 1 will make the buffers be
 shorter, it creates a timelapse effect.
 
 Only used in SCRecorder.
 */
@property (assign, nonatomic) CGFloat timeScale;

/**
 If true and videoSize is CGSizeZero, the videoSize
 used will equal to the minimum width or height found,
 thus making the video square.
 */
@property (assign, nonatomic) BOOL sizeAsSquare;

/**
 If true, each frame will be encoded as a keyframe
 This is needed if you want to merge the recordSegments using
 the passthrough preset. This will seriously impact the video
 size. You can set this to NO and change the recordSegmentsMergePreset if you want
 a better quality/size ratio, but the merge will be slower.
 Default is NO
 */
@property (assign, nonatomic) BOOL shouldKeepOnlyKeyFrames;

/**
 If not nil, each appended frame will be processed by this SCFilter.
 While it seems convenient, this removes the possibility to change the
 filter after the segment has been added.
 Setting a new filter will cause the SCRecordSession to stop the
 current record segment if the previous filter was NIL and the
 new filter is NOT NIL or vice versa. If you want to have a smooth
 transition between filters in the same record segment, make sure to set
 an empty SCFilterGroup instead of setting this property to nil.
 */
@property (strong, nonatomic) SCFilter *__nullable filter;

/**
 If YES, the affineTransform will be ignored and the output affineTransform
 will be the same as the input asset.
 
 Only used in SCAssetExportSession.
 */
@property (assign, nonatomic) BOOL keepInputAffineTransform;

/**
 The video composition to use.
 
 Only used in SCAssetExportSession.
 */
@property (strong, nonatomic) AVVideoComposition *__nullable composition;

/**
 The watermark to use. If the composition is not set, this watermark
 image will be applied on the exported video.
 
 Only used in SCAssetExportSession.
 */
@property (strong, nonatomic) UIImage *__nullable watermarkImage;

/**
 The watermark image location and size in the input video frame coordinates.
 
 Only used in SCAssetExportSession.
 */
@property (assign, nonatomic) CGRect watermarkFrame;

/**
 Specify a buffer size to use. By default the SCAssetExportSession tries
 to figure out which size to use by looking at the composition and the natural
 size of the inputAsset. If the filter you set return back an image with a different
 size, you should put the output size here.
 
 Only used in SCAssetExportSession.
 Default is CGSizeZero
 */
@property (assign, nonatomic) CGSize bufferSize;

/**
 Set a specific key to the video profile
 */
@property (assign, nonatomic) NSString *__nullable profileLevel;

/**
 The overlay view that will be drawn on top of the video.
 
 Only used in SCAssetExportSession.
 */
@property (strong, nonatomic) UIView<SCVideoOverlay> *__nullable overlay;

/**
 The watermark anchor location.
 
 Default is top left
 
 Only used in SCAssetExportSession.
 */
@property (assign, nonatomic) SCWatermarkAnchorLocation watermarkAnchorLocation;


- (NSDictionary *__nonnull)createAssetWriterOptionsWithVideoSize:(CGSize)videoSize;

@end
