//
//  SCRecorderTools.h
//  SCRecorder
//
//  Created by Simon CORSIN on 24/12/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCRecorderTools : NSObject

/**
 Returns the best session preset that is compatible with all available video
 devices (front and back camera). It will ensure that buffer output from
 both camera has the same resolution.
 */
+ (NSString *)bestSessionPresetCompatibleWithAllDevices;

+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate;

+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate dimensions:(CMVideoDimensions)videoDimensions;

+ (CMTimeScale)maxFrameRateForFormat:(AVCaptureDeviceFormat *)format minFrameRate:(CMTimeScale)minFrameRate;

+ (AVCaptureDevice *)videoDeviceForPosition:(AVCaptureDevicePosition)position;

@end
