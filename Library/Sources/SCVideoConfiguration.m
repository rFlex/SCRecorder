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
    }
    
    return self;
}

- (NSDictionary *)createAssetWriterOptionsUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    NSDictionary *options = self.options;
    if (options != nil) {
        return options;
    }
    
    CGSize videoSize = self.size;
    
    if (CGSizeEqualToSize(videoSize, CGSizeZero)) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        videoSize.width = width;
        videoSize.height = height;
        
        if (self.sizeAsSquare) {
            if (width > height) {
                videoSize.width = height;
            } else {
                videoSize.height = width;
            }
        }
    }
    
    unsigned long bitrate = self.bitrate;
    
    NSMutableDictionary *compressionSettings = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:bitrate] forKey:AVVideoAverageBitRateKey];
    
    if (self.shouldKeepOnlyKeyFrames) {
        [compressionSettings setObject:@1 forKey:AVVideoMaxKeyFrameIntervalKey];
    }
    
    return @{
                      AVVideoCodecKey : self.codec,
                      AVVideoScalingModeKey : self.scalingMode,
                      AVVideoWidthKey : [NSNumber numberWithInteger:videoSize.width],
                      AVVideoHeightKey : [NSNumber numberWithInteger:videoSize.height],
                      AVVideoCompressionPropertiesKey : compressionSettings
                      };
}

@end
