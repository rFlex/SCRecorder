//
//  SCAudioEncoder.m
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/5/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCAudioEncoder.h"
#import "SCAudioVideoRecorderInternal.h"

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////


////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCAudioEncoder {
    
}

@synthesize outputSampleRate;
@synthesize outputChannels;
@synthesize outputBitRate;
@synthesize outputEncodeType;

- (id) initWithAudioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder {
    self = [super initWithAudioVideoRecorder:audioVideoRecorder];
    
    if (self != nil) {
        self.outputSampleRate = 0;
        self.outputChannels = 0;
        self.outputBitRate = 128000;
        self.outputEncodeType = kAudioFormatMPEG4AAC;
    }
    
    return self;
}

- (AVAssetWriterInput*) createWriterInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer error:(NSError **)error {
    
    Float64 sampleRate = self.outputSampleRate;
    int channels = self.outputChannels;
    
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    const AudioStreamBasicDescription * streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    
    if (sampleRate == 0) {
        sampleRate = streamBasicDescription->mSampleRate;
    }
    if (channels == 0) {
        channels = streamBasicDescription->mChannelsPerFrame;
    }
    
    AVAssetWriterInput * audioInput = nil;
    NSDictionary * audioCompressionSetings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [ NSNumber numberWithInt: self.outputEncodeType], AVFormatIDKey,
                                              [ NSNumber numberWithInt: self.outputBitRate ], AVEncoderBitRateKey,
                                              [ NSNumber numberWithFloat: sampleRate], AVSampleRateKey,
                                              [ NSNumber numberWithInt: channels], AVNumberOfChannelsKey,
                                              nil];
    
    if ([self.audioVideoRecorder.assetWriter canApplyOutputSettings:audioCompressionSetings forMediaType:AVMediaTypeAudio]) {
        audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSetings];
        audioInput.expectsMediaDataInRealTime = YES;
        if (error != nil)
            *error = nil;
    } else {
        if (error != nil)
            *error = [SCAudioVideoRecorder createError:@"Cannot apply Audio settings"];
    }

    return audioInput;
}

@end
