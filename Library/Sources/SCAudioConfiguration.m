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
    unsigned long bitrate = (unsigned long)self.bitrate;
    
    if (self.preset != nil) {
        if ([self.preset isEqualToString:SCPresetLowQuality]) {
            bitrate = 64000;
            channels = 1;
        } else if ([self.preset isEqualToString:SCPresetMediumQuality]) {
            bitrate = 128000;
        } else if ([self.preset isEqualToString:SCPresetHighestQuality]) {
            bitrate = 320000;
        } else {
            NSLog(@"Unrecognized video preset %@", self.preset);
        }
    }
    
    if (sampleBuffer != nil) {
        CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
        const AudioStreamBasicDescription *streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
        
        if (sampleRate == 0) {
            sampleRate = streamBasicDescription->mSampleRate;
        }
        if (channels == 0) {
            channels = streamBasicDescription->mChannelsPerFrame;
        }
    }
    
    if (sampleRate == 0) {
        sampleRate = kSCAudioConfigurationDefaultSampleRate;
    }
    if (channels == 0) {
        channels = kSCAudioConfigurationDefaultNumberOfChannels;
    }
    
    return @{
             AVFormatIDKey : [NSNumber numberWithInt: self.format],
             AVEncoderBitRateKey : [NSNumber numberWithUnsignedLong: bitrate],
             AVNumberOfChannelsKey : [NSNumber numberWithInt: channels],
             AVSampleRateKey : [NSNumber numberWithInt: sampleRate]
             };
}

@end
