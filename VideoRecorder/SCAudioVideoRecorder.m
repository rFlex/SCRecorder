//
//  VRVideoRecorder.m
//  VideoRecorder
//
//  Created by Simon CORSIN on 8/3/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import "SCAudioVideoRecorderInternal.h"

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface SCAudioVideoRecorder() {
    BOOL recording;
    BOOL shouldWriteToCameraRoll;
    BOOL audioEncoderReady;
    BOOL videoEncoderReady;
    dispatch_queue_t dispatch_queue;
}

@property (strong, nonatomic) AVCaptureVideoDataOutput * videoOutput;
@property (strong, nonatomic) AVCaptureAudioDataOutput * audioOutput;
@property (strong, nonatomic) SCVideoEncoder * videoEncoder;
@property (strong, nonatomic) SCAudioEncoder * audioEncoder;
@property (strong, nonatomic) NSURL * outputFileUrl;
@property (strong, nonatomic) AVAssetWriter * assetWriter;

@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCAudioVideoRecorder

@synthesize delegate;
@synthesize videoOutput;
@synthesize audioOutput;
@synthesize outputFileUrl;
@synthesize audioEncoder;
@synthesize videoEncoder;
@synthesize dispatchDelegateMessagesOnMainQueue;

- (id) init {
    self = [super init];
    
    if (self) {
        dispatch_queue = dispatch_queue_create("SCVideoRecorder", nil);
        
        audioEncoderReady = NO;
        videoEncoderReady = NO;
        self.audioEncoder = [[SCAudioEncoder alloc] initWithAudioVideoRecorder:self];
        self.videoEncoder = [[SCVideoEncoder alloc] initWithAudioVideoRecorder:self];
        self.audioEncoder.delegate = self;
        self.videoEncoder.delegate = self;
        
        self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [self.videoOutput setSampleBufferDelegate:self.videoEncoder queue:dispatch_queue];
        
        self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
        [self.audioOutput setSampleBufferDelegate:self.audioEncoder queue:dispatch_queue];
        
        self.lastFrameTimeBeforePause = CMTimeMake(0, 1);
        self.dispatchDelegateMessagesOnMainQueue = YES;
    }
    return self;
}

- (void) dealloc {
    self.videoOutput = nil;
    self.audioOutput = nil;
    self.videoEncoder = nil;
    self.audioEncoder = nil;
    self.outputFileUrl = nil;
    self.assetWriter = nil;
}

//
// Video Recorder methods
//

- (void) startRecordingAtCameraRoll:(NSError **)error {
    [self prepareRecordingAtCameraRoll:error shouldStartRecording:YES];
}

- (NSURL*) startRecordingOnTempDir:(NSError **)error {
    return [self prepareRecordingOnTempDir:error shouldStartRecording:YES];
}

- (void) startRecordingAtUrl:(NSURL *)fileUrl error:(NSError**)error {
    [self prepareRecordingAtUrl:fileUrl error:error shouldStartRecording:YES];
}

- (void) prepareRecordingAtCameraRoll:(NSError **)error shouldStartRecording:(BOOL)shouldRecord {
    [self prepareRecordingOnTempDir:error shouldStartRecording:shouldRecord];
    shouldWriteToCameraRoll = YES;
}

- (NSURL*) prepareRecordingOnTempDir:(NSError **)error shouldStartRecording:(BOOL)shouldRecord {
    long timeInterval =  (long)[[NSDate date] timeIntervalSince1970];
    NSURL * fileUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%ld%@", NSTemporaryDirectory(), timeInterval, @"SCVideo.MOV"]];
    
    NSError * recordError = nil;
    [self prepareRecordingAtUrl:fileUrl error:&recordError shouldStartRecording:shouldRecord];
    
    if (recordError != nil) {
        if (error != nil) {
            *error = recordError;
        }
        [self removeFile:fileUrl];
        fileUrl = nil;
        
    }
    
    return fileUrl;
}


- (void) prepareRecordingAtUrl:(NSURL *)fileUrl error:(NSError **)error shouldStartRecording:(BOOL)shouldRecord {
    if (fileUrl == nil) {
        [NSException raise:@"Invalid argument" format:@"FileUrl must be not nil"];
    }
    
    dispatch_sync(dispatch_queue, ^ {
        [self resetInternal];
        shouldWriteToCameraRoll = NO;
        self.currentTimeOffset = CMTimeMake(0, 1);
        
        NSError * assetError;
        
        AVAssetWriter * writer = [[AVAssetWriter alloc] initWithURL:fileUrl fileType:AVFileTypeQuickTimeMovie error:&assetError];
        
        if (assetError == nil) {
            self.assetWriter = writer;
            self.outputFileUrl = fileUrl;
            
            if (shouldRecord) {
                [self resumeRecording];
            }
        } else {
            if (error != nil) {
                *error = assetError;
            }
        }
    });
}

- (void) removeFile:(NSURL *)fileURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [fileURL path];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *error;
        [fileManager removeItemAtPath:filePath error:&error];
    }
}

- (void) assetWriterFinished:(NSURL*)fileUrl {
    self.assetWriter = nil;
    self.outputFileUrl = nil;
    [self.audioEncoder reset];
    [self.videoEncoder reset];
    
    if (shouldWriteToCameraRoll) {
        ALAssetsLibrary * library = [[ALAssetsLibrary alloc] init];
        [library writeVideoAtPathToSavedPhotosAlbum:fileUrl completionBlock:^(NSURL *assetUrl, NSError * error) {
            [self removeFile:fileUrl];
            
            [self dispatchBlockOnAskedQueue:^ {
                if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didFinishRecordingAtUrl:error:)]) {
                    [self.delegate audioVideoRecorder:self didFinishRecordingAtUrl:assetUrl error:error];
                }
            }];
        }];
    } else {
        [self dispatchBlockOnAskedQueue:^ {
            if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didFinishRecordingAtUrl:error:)]) {
                [self.delegate audioVideoRecorder:self didFinishRecordingAtUrl:fileUrl error:nil];
            }
        }];
    }
}

- (void) stopRecording {
    [self pauseRecording];
    
    dispatch_async(dispatch_queue, ^ {
        if (self.assetWriter == nil) {
            [self dispatchBlockOnAskedQueue:^ {
                if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didFinishRecordingAtUrl:error:)]) {
                    [self.delegate audioVideoRecorder:self didFinishRecordingAtUrl:nil error:[SCAudioVideoRecorder createError:@"Recording must be started before calling stopRecording"]];
                }                
            }];
        } else {
            NSURL * fileUrl = self.outputFileUrl;

            if (self.assetWriter.status != AVAssetWriterStatusUnknown) {
                [self.assetWriter finishWritingWithCompletionHandler:^ {
                    [self assetWriterFinished:fileUrl];
                }];
            } else {
                [self assetWriterFinished:fileUrl];
            }
        }
    });
    
}

- (void) pauseRecording {
    dispatch_async(dispatch_queue, ^ {
        recording = NO;
        // As I don't know any way to get the current time, setting this will always
        // let the last frame to last 1/24th of a second
        self.lastFrameTimeBeforePause = CMTimeMake(1, 24);
    });
}

- (void) resumeRecording {
    if (![self isRecordingStarted]) {
        [NSException raise:@"Recording not previously started" format:@"Recording should be started using startRecording before trying to resume it"];
    }
    dispatch_async(dispatch_queue, ^ {
        self.shouldComputeOffset = YES;
        recording = YES;
    });
}

- (void) cancelRecording {
    dispatch_sync(dispatch_queue, ^ {
        [self resetInternal];
    });
}

- (void) resetInternal {
    AVAssetWriter * writer = self.assetWriter;
    NSURL * fileUrl = self.outputFileUrl;
    
    audioEncoderReady = NO;
    videoEncoderReady = NO;
    
    self.outputFileUrl = nil;
    self.assetWriter = nil;
    
    [self.audioEncoder reset];
    [self.videoEncoder reset];
    
    if (writer != nil) {
        if (writer.status != AVAssetWriterStatusUnknown) {
            [writer finishWritingWithCompletionHandler:^ {
                if (fileUrl != nil) {
                    [self removeFile:fileUrl];
                }
            }];
        }
    }
}

//
// DataEncoder Delegate implementation
//

- (void) dataEncoder:(SCDataEncoder *)dataEncoder didEncodeFrame:(Float64)frameSecond {
    [self dispatchBlockOnAskedQueue:^ {
        if (dataEncoder == self.audioEncoder) {
            if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didRecordAudioSample:)]) {
                [self.delegate audioVideoRecorder:self didRecordAudioSample:frameSecond];
            }
        } else {
            if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didRecordVideoFrame:)]) {
                [self.delegate audioVideoRecorder:self didRecordVideoFrame:frameSecond];
            }
        }
    }];
}

- (void) dataEncoder:(SCDataEncoder *)dataEncoder didFailToInitializeEncoder:(NSError *)error {
    [self dispatchBlockOnAskedQueue: ^ {
        if (dataEncoder == self.audioEncoder) {
            if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didFailToInitializeAudioEncoder:)]) {
                [self.delegate audioVideoRecorder:self didFailToInitializeAudioEncoder:error];
            }
        } else {
            if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didFailToInitializeVideoEncoder:)]) {
                [self.delegate audioVideoRecorder:self didFailToInitializeVideoEncoder:error];
            }
        }
    }];
}

//
// Misc methods
//

- (void) dispatchBlockOnAskedQueue:(void(^)())block {
    if (self.dispatchDelegateMessagesOnMainQueue) {
        dispatch_async(dispatch_get_main_queue(), block);
    } else {
        block();
    }
}

+ (NSError*) createError:(NSString*)name {
    return [NSError errorWithDomain:@"SCAudioVideoRecorder" code:500 userInfo:[NSDictionary dictionaryWithObject:name forKey:NSLocalizedDescriptionKey]];
}

- (void) prepareWriterAtSourceTime:(CMTime)sourceTime fromEncoder:(SCDataEncoder*)encoder {
    // Set an encoder as ready if it's the caller or if it's not enabled
    audioEncoderReady |= (encoder == self.audioEncoder) | !self.audioEncoder.enabled;
    videoEncoderReady |= (encoder == self.videoEncoder) | !self.videoEncoder.enabled;
    
    // We only start the writing when both encoder are ready
    if (audioEncoderReady && videoEncoderReady) {
        if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
            if ([self.assetWriter startWriting]) {
                [self.assetWriter startSessionAtSourceTime:sourceTime];
            }
            self.startedTime = sourceTime;
        }
    }
}

//
// Getters
//

- (BOOL) isRecordingStarted {
    return self.assetWriter != nil;
}

- (BOOL) isRecording {
    return recording;
}

@end
