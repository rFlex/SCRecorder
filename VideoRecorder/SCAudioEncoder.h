//
//  SCAudioEncoder.h
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/5/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCDataEncoder.h"

@interface SCAudioEncoder : SCDataEncoder<AVCaptureAudioDataOutputSampleBufferDelegate> {
    
}

@property (assign, nonatomic) Float64 outputSampleRate;
@property (assign, nonatomic) int outputChannels;
@property (assign, nonatomic) int outputBitRate;

// Must be like kAudioFormat* (example kAudioFormatMPEGLayer3)
@property (assign, nonatomic) int outputEncodeType;

@end
