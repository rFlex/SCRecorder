//
//  VRVideoRecorder.h
//  VideoRecorder
//
//  Created by Simon CORSIN on 8/3/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol SCVideoRecorderDelegate <NSObject>

@optional

- (void) videoRecorder:(id)videoRecorder didRecordFrame:(Float64)totalRecorded;

@end

@interface SCVideoRecorder : AVCaptureVideoDataOutput<AVCaptureVideoDataOutputSampleBufferDelegate> {
    
}

- (id) initWithOutputVideoSize:(CGSize)outputVideoSize;

- (void) startRecordingAtCameraRoll:(NSError**)error;
- (NSURL*) startRecordingOnTempDir:(NSError**)error;
- (void) startRecordingAtUrl:(NSURL*)url error:(NSError**)error;
- (void) reset;
- (void) resumeRecording;
- (void) pauseRecording;
- (void) stopRecording:(void(^)(NSError*)) handler;

- (BOOL) isRecordingStarted;
- (BOOL) isRecording;
- (NSURL*) getOutputFileUrl;

@property (assign, nonatomic) CGSize outputVideoSize;
@property (strong, nonatomic) id<SCVideoRecorderDelegate> delegate;

@end
