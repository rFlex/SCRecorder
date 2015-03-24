//
//  SCVideoConfiguration.m
//  SCRecorder
//
//  Created by Simon CORSIN on 21/11/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCVideoConfiguration.h"

@implementation SCVideoConfiguration

- (id)init {
    self = [super init];
    
    if (self) {
        self.bitrate = kSCVideoConfigurationDefaultBitrate;
        _size = CGSizeZero;
        _codec = kSCVideoConfigurationDefaultCodec;
        _scalingMode = kSCVideoConfigurationDefaultScalingMode;
        _affineTransform = CGAffineTransformIdentity;
        _timeScale = 1;
        _keepInputAffineTransform = YES;
    }
    
    return self;
}

static CGSize MakeVideoSize(CGSize videoSize, float requestedWidth) {
    float ratio = videoSize.width / requestedWidth;
    
    if (ratio <= 1) {
        return videoSize;
    }
    
    return CGSizeMake(videoSize.width / ratio, videoSize.height / ratio);
}

- (NSDictionary *)createAssetWriterOptionsWithVideoSize:(CGSize)videoSize {
    NSDictionary *options = self.options;
    if (options != nil) {
        return options;
    }
    
    CGSize outputSize = self.size;
    unsigned long bitrate = (unsigned long)self.bitrate;
    
    if (self.preset != nil) {
        if ([self.preset isEqualToString:SCPresetLowQuality]) {
            bitrate = 500000;
            outputSize = MakeVideoSize(videoSize, 640);
        } else if ([self.preset isEqualToString:SCPresetMediumQuality]) {
            bitrate = 1000000;
            outputSize = MakeVideoSize(videoSize, 1280);
        } else if ([self.preset isEqualToString:SCPresetHighestQuality]) {
            bitrate = 6000000;
            outputSize = MakeVideoSize(videoSize, 1920);
        } else {
            NSLog(@"Unrecognized video preset %@", self.preset);
        }
    }
    
    if (CGSizeEqualToSize(outputSize, CGSizeZero)) {
        outputSize = videoSize;
    }
    
    if (self.sizeAsSquare) {
        if (videoSize.width > videoSize.height) {
            outputSize.width = videoSize.height;
        } else {
            outputSize.height = videoSize.width;
        }
    }
    
    NSMutableDictionary *compressionSettings = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:bitrate] forKey:AVVideoAverageBitRateKey];
    
    if (self.shouldKeepOnlyKeyFrames) {
        [compressionSettings setObject:@1 forKey:AVVideoMaxKeyFrameIntervalKey];
    }
    
    if (self.profileLevel) {
        [compressionSettings setObject:self.profileLevel forKey:AVVideoProfileLevelKey];
    }
//    [compressionSettings setObject:@30 forKey:AVVideoAverageNonDroppableFrameRateKey];
    [compressionSettings setObject:@NO forKey:AVVideoAllowFrameReorderingKey];
//    [compressionSettings setObject:AVVideoH264EntropyModeCABAC forKey:AVVideoH264EntropyModeKey];
    [compressionSettings setObject:@30 forKey:AVVideoExpectedSourceFrameRateKey];
    
    return @{
             AVVideoCodecKey : self.codec,
             AVVideoScalingModeKey : self.scalingMode,
             AVVideoWidthKey : [NSNumber numberWithInteger:outputSize.width],
             AVVideoHeightKey : [NSNumber numberWithInteger:outputSize.height],
             AVVideoCompressionPropertiesKey : compressionSettings
             };

}

- (NSDictionary *)createAssetWriterOptionsUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    return [self createAssetWriterOptionsWithVideoSize:CGSizeMake(width, height)];
}

@end
