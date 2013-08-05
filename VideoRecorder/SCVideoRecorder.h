//
//  VRVideoRecorder.h
//  VideoRecorder
//
//  Created by Simon CORSIN on 8/3/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface SCVideoRecorder : AVCaptureVideoDataOutput<AVCaptureVideoDataOutputSampleBufferDelegate> {
    
}

- (id) initWithOutputVideoSize:(CGSize)outputVideoSize;

- (void) startRecordingAtCameraRoll:(void(^)(NSError*))handler;
- (void) startRecordingAtUrl:(NSURL*)url withHandler:(void(^)(NSError*))handler;
- (void) reset:(void(^)()) handler;
- (void) resumeRecording;
- (void) pauseRecording;
- (void) stopRecording:(void(^)(NSURL*, NSError*)) handler;

- (BOOL) isRecordingStarted;
- (BOOL) isRecording;
- (BOOL) isInitializingRecording;

@property (assign, nonatomic) CGSize outputVideoSize;


@end
