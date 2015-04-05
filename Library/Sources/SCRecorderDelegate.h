//
//  SCRecorderDelegate.h
//  SCRecorder
//
//  Created by Simon CORSIN on 18/03/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SCRecorder.h"

typedef NS_ENUM(NSInteger, SCFlashMode) {
    SCFlashModeOff  = AVCaptureFlashModeOff,
    SCFlashModeOn   = AVCaptureFlashModeOn,
    SCFlashModeAuto = AVCaptureFlashModeAuto,
    SCFlashModeLight
};

@class SCRecorder;

@protocol SCRecorderDelegate <NSObject>

@optional

/**
 Called when the recorder has reconfigured the videoInput
 */
- (void)recorder:(SCRecorder *)recorder didReconfigureVideoInput:(NSError *)videoInputError;

/**
 Called when the recorder has reconfigured the audioInput
 */
- (void)recorder:(SCRecorder *)recorder didReconfigureAudioInput:(NSError *)audioInputError;

/**
 Called when the flashMode has changed
 */
- (void)recorder:(SCRecorder *)recorder didChangeFlashMode:(SCFlashMode)flashMode error:(NSError *)error;

/**
 Called before the recorder will start focusing
 */
- (void)recorderWillStartFocus:(SCRecorder *)recorder;

/**
 Called when the recorder has started focusing
 */
- (void)recorderDidStartFocus:(SCRecorder *)recorder;

/**
 Called when the recorder has finished focusing
 */
- (void)recorderDidEndFocus:(SCRecorder *)recorder;

/**
 Called when the recorder has initialized the audio in a session
 */
- (void)recorder:(SCRecorder *)recorder didInitializeAudioInSession:(SCRecordSession *)session error:(NSError *)error;

/**
 Called when the recorder has initialized the video in a session
 */
- (void)recorder:(SCRecorder *)recorder didInitializeVideoInSession:(SCRecordSession *)session error:(NSError *)error;

/**
 Called when the recorder has started a segment in a session
 */
- (void)recorder:(SCRecorder *)recorder didBeginSegmentInSession:(SCRecordSession *)session error:(NSError *)error;

/**
 Called when the recorder has completed a segment in a session
 */
- (void)recorder:(SCRecorder *)recorder didCompleteSegment:(SCRecordSessionSegment *)segment inSession:(SCRecordSession *)session error:(NSError *)error;

/**
 Called when the recorder has appended a video buffer in a session
 */
- (void)recorder:(SCRecorder *)recorder didAppendVideoSampleBufferInSession:(SCRecordSession *)session;

/**
 Called when the recorder has appended an audio buffer in a session
 */
- (void)recorder:(SCRecorder *)recorder didAppendAudioSampleBufferInSession:(SCRecordSession *)session;

/**
 Called when the recorder has skipped an audio buffer in a session
 */
- (void)recorder:(SCRecorder *)recorder didSkipAudioSampleBufferInSession:(SCRecordSession *)session;

/**
 Called when the recorder has skipped a video buffer in a session
 */
- (void)recorder:(SCRecorder *)recorder didSkipVideoSampleBufferInSession:(SCRecordSession *)session;

/**
 Called when a session has reached the maxRecordDuration
 */
- (void)recorder:(SCRecorder *)recorder didCompleteSession:(SCRecordSession *)session;

/**
 Gives an opportunity to the delegate to create an info dictionary for a record segment.
 */
- (NSDictionary *)createSegmentInfoForRecorder:(SCRecorder *)recorder;

@end
