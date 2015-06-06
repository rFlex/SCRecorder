//
//  SCRecorderTools.h
//  SCRecorder
//
//  Created by Simon CORSIN on 24/12/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface SCRecorderTools : NSObject

/**
 Returns the best session preset that is compatible with all available video
 devices (front and back camera). It will ensure that buffer output from
 both camera has the same resolution.
 */
+ (NSString *)bestCaptureSessionPresetCompatibleWithAllDevices;

/**
 Returns the best captureSessionPreset for a device that is equal or under the max specified size
 */
+ (NSString *)bestCaptureSessionPresetForDevice:(AVCaptureDevice *)device withMaxSize:(CGSize)maxSize;

/**
 Returns the best captureSessionPreset for a device position that is equal or under the max specified size
 */
+ (NSString *)bestCaptureSessionPresetForDevicePosition:(AVCaptureDevicePosition)devicePosition withMaxSize:(CGSize)maxSize;

+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate;

+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate dimensions:(CMVideoDimensions)videoDimensions;

+ (CMTimeScale)maxFrameRateForFormat:(AVCaptureDeviceFormat *)format minFrameRate:(CMTimeScale)minFrameRate;

+ (AVCaptureDevice *)videoDeviceForPosition:(AVCaptureDevicePosition)position;

+ (NSArray *)assetWriterMetadata;

@end

@interface NSDate (SCRecorderTools)

- (NSString *)toISO8601;

+ (NSDate *)fromISO8601:(NSString *)iso8601;

@end
