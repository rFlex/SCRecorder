//
//  SCRecorderTools.m
//  SCRecorder
//
//  Created by Simon CORSIN on 24/12/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "SCRecorderTools.h"
#define kFULL_HD (1920 x 1080)
#define kHD_READY (1280 x 720)

@implementation SCRecorderTools

+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate {
    CMVideoDimensions dimensions;
    dimensions.width = 0;
    dimensions.height = 0;
    
    return [SCRecorderTools formatInRange:format frameRate:frameRate dimensions:dimensions];
}

+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate dimensions:(CMVideoDimensions)dimensions {
    CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
    
    if (size.width >= dimensions.width && size.height >= dimensions.height) {
        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
            if (range.minFrameDuration.timescale >= frameRate && range.maxFrameDuration.timescale <= frameRate) {
                return YES;
            }
        }
    }
    
    return NO;
}

+ (CMTimeScale)maxFrameRateForFormat:(AVCaptureDeviceFormat *)format minFrameRate:(CMTimeScale)minFrameRate {
    CMTimeScale lowerTimeScale = 0;
    for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
        if (range.minFrameDuration.timescale >= minFrameRate && (lowerTimeScale == 0 || range.minFrameDuration.timescale < lowerTimeScale)) {
            lowerTimeScale = range.minFrameDuration.timescale;
        }
    }
    
    return lowerTimeScale;
}

+ (AVCaptureDevice *)videoDeviceForPosition:(AVCaptureDevicePosition)position {
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in videoDevices) {
        if (device.position == (AVCaptureDevicePosition)position) {
            return device;
        }
    }
    
    return nil;
}

+ (NSString *)bestSessionPresetCompatibleWithAllDevices {
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];

    CMVideoDimensions highestCompatibleDimension;
    BOOL lowestSet = NO;
    
    for (AVCaptureDevice *device in videoDevices) {
        CMVideoDimensions highestDeviceDimension;
        highestDeviceDimension.width = 0;
        highestDeviceDimension.height = 0;
        
        for (AVCaptureDeviceFormat *format in device.formats) {
            CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            
            if (dimension.width * dimension.height > highestDeviceDimension.width * highestDeviceDimension.height) {
                highestDeviceDimension = dimension;
            }
        }
        
        if (!lowestSet || (highestCompatibleDimension.width * highestCompatibleDimension.height > highestDeviceDimension.width * highestDeviceDimension.height)) {
            lowestSet = YES;
            highestCompatibleDimension = highestDeviceDimension;
        }
        
    }

    if (highestCompatibleDimension.width >= 1920 && highestCompatibleDimension.height >= 1080) {
        return AVCaptureSessionPreset1920x1080;
    }
    if (highestCompatibleDimension.width >= 1280 && highestCompatibleDimension.height >= 720) {
        return AVCaptureSessionPreset1280x720;
    }
    if (highestCompatibleDimension.width >= 960 && highestCompatibleDimension.height >= 540) {
        return AVCaptureSessionPresetiFrame960x540;
    }
    if (highestCompatibleDimension.width >= 640 && highestCompatibleDimension.height >= 480) {
        return AVCaptureSessionPreset640x480;
    }
    if (highestCompatibleDimension.width >= 352 && highestCompatibleDimension.height >= 288) {
        return AVCaptureSessionPreset352x288;
    }
    
    return AVCaptureSessionPresetLow;
}

@end
