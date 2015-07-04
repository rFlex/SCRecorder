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
- (void)recorder:(SCRecorder *__nonnull)recorder didReconfigureVideoInput:(NSError *__nullable)videoInputError;

/**
 Called when the recorder has reconfigured the audioInput
 */
- (void)recorder:(SCRecorder *__nonnull)recorder didReconfigureAudioInput:(NSError *__nullable)audioInputError;

/**
 Called when the flashMode has changed
 */
- (void)recorder:(SCRecorder *__nonnull)recorder didChangeFlashMode:(SCFlashMode)flashMode error:(NSError *__nullable)error;

/**
 Called when the recorder has lost the focus. Returning true will make the recorder
 automatically refocus at the center.
 */
- (BOOL)recorderShouldAutomaticallyRefocus:(SCRecorder *__nonnull)recorder;

/**
 Called before the recorder will start focusing
 */
- (void)recorderWillStartFocus:(SCRecorder *__nonnull)recorder;

/**
 Called when the recorder has started focusing
 */
- (void)recorderDidStartFocus:(SCRecorder *__nonnull)recorder;

/**
 Called when the recorder has finished focusing
 */
- (void)recorderDidEndFocus:(SCRecorder *__nonnull)recorder;

/**
 Called before the recorder will start adjusting exposure
 */
- (void)recorderWillStartAdjustingExposure:(SCRecorder *__nonnull)recorder;

/**
 Called when the recorder has started adjusting exposure
 */
- (void)recorderDidStartAdjustingExposure:(SCRecorder *__nonnull)recorder;

/**
 Called when the recorder has finished adjusting exposure
 */
- (void)recorderDidEndAdjustingExposure:(SCRecorder *__nonnull)recorder;

/**
 Called when the recorder has initialized the audio in a session
 */
- (void)recorder:(SCRecorder *__nonnull)recorder didInitializeAudioInSession:(SCRecordSession *__nonnull)session error:(NSError *__nullable)error;

/**
 Called when the recorder has initialized the video in a session
 */
- (void)recorder:(SCRecorder *__nonnull)recorder didInitializeVideoInSession:(SCRecordSession *__nonnull)session error:(NSError *__nullable)error;

/**
 Called when the recorder has started a segment in a session
 */
- (void)recorder:(SCRecorder *__nonnull)recorder didBeginSegmentInSession:(SCRecordSession *__nonnull)session error:(NSError *__nullable)error;

/**
 Called when the recorder has completed a segment in a session
 */
- (void)recorder:(SCRecorder *__nonnull)recorder didCompleteSegment:(SCRecordSessionSegment *__nullable)segment inSession:(SCRecordSession *__nonnull)session error:(NSError *__nullable)error;

/**
 Called when the recorder has appended a video buffer in a session
 */
- (void)recorder:(SCRecorder *__nonnull)recorder didAppendVideoSampleBufferInSession:(SCRecordSession *__nonnull)session;

/**
 Called when the recorder has appended an audio buffer in a session
 */
- (void)recorder:(SCRecorder *__nonnull)recorder didAppendAudioSampleBufferInSession:(SCRecordSession *__nonnull)session;

/**
 Called when the recorder has skipped an audio buffer in a session
 */
- (void)recorder:(SCRecorder *__nonnull)recorder didSkipAudioSampleBufferInSession:(SCRecordSession *__nonnull)session;

/**
 Called when the recorder has skipped a video buffer in a session
 */
- (void)recorder:(SCRecorder *__nonnull)recorder didSkipVideoSampleBufferInSession:(SCRecordSession *__nonnull)session;

/**
 Called when a session has reached the maxRecordDuration
 */
- (void)recorder:(SCRecorder *__nonnull)recorder didCompleteSession:(SCRecordSession *__nonnull)session;

/**
 Gives an opportunity to the delegate to create an info dictionary for a record segment.
 */
- (NSDictionary *__nullable)createSegmentInfoForRecorder:(SCRecorder *__nonnull)recorder;

@end
