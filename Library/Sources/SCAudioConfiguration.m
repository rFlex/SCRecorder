//
//  SCAudioConfiguration.m
//  SCRecorder
//
//  Created by Simon CORSIN on 21/11/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCAudioConfiguration.h"

@implementation SCAudioConfiguration

- (id)init {
    self = [super init];
    
    if (self) {
        self.bitrate = kSCAudioConfigurationDefaultBitrate;
        _format = kSCAudioConfigurationDefaultAudioFormat;
    }
    
    return self;
}

- (NSDictionary *)createAssetWriterOptionsUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    NSDictionary *options = self.options;
    if (options != nil) {
        return options;
    }
    
    Float64 sampleRate = self.sampleRate;
    int channels = self.channelsCount;
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    const AudioStreamBasicDescription * streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    
    if (sampleRate == 0) {
        sampleRate = streamBasicDescription->mSampleRate;
    }
    if (channels == 0) {
        channels = streamBasicDescription->mChannelsPerFrame;
    }
    
    return @{
             AVFormatIDKey : [NSNumber numberWithInt: self.format],
             AVEncoderBitRateKey : [NSNumber numberWithUnsignedLong:self.bitrate],
             AVSampleRateKey : [NSNumber numberWithFloat: sampleRate],
             AVNumberOfChannelsKey : [NSNumber numberWithInt: channels]
             };
}

@end
