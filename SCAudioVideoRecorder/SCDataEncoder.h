//
//  SCDataEncoder.h
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/6/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

//
// Encoder
//

@class SCDataEncoder;
@class SCAudioVideoRecorder;

@protocol SCDataEncoderDelegate <NSObject>

@optional
- (void) dataEncoder:(SCDataEncoder*)dataEncoder didEncodeFrame:(CMTime)frameTime;
- (void) dataEncoder:(SCDataEncoder *)dataEncoder didFailToInitializeEncoder:(NSError*)error;

@end

@interface SCDataEncoder : NSObject {
    
}

- (id) initWithAudioVideoRecorder:(SCAudioVideoRecorder*)audioVideoRecorder;
- (void) reset;

// Abstract method
- (AVAssetWriterInput*) createWriterInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer error:(NSError**)error;

@property (assign, nonatomic) BOOL useInputFormatTypeAsOutputType;
@property (assign, nonatomic) BOOL enabled;
@property (strong, nonatomic) AVAssetWriterInput * writerInput;
@property (weak, nonatomic) id<SCDataEncoderDelegate> delegate;
@property (weak, nonatomic, readonly) SCAudioVideoRecorder * audioVideoRecorder;

@end
