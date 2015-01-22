//
//  SCNewCamera.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 27/03/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCRecorder.h"
#import "SCRecordSession_Internal.h"
#define dispatch_handler(x) if (x != nil) dispatch_async(dispatch_get_main_queue(), x)
#define SCRecorderFocusContext ((void*)0x1)
#define SCRecorderVideoEnabledContext ((void*)0x2)
#define SCRecorderAudioEnabledContext ((void*)0x3)
#define SCRecorderPhotoOptionsContext ((void*)0x3)
#define kSCRecorderRecordSessionQueueKey "SCRecorderRecordSessionQueue"
#define kMinTimeBetweenAppend 0
//#define kMinTimeBetweenAppend 0.0020

@interface SCRecorder() {
    AVCaptureVideoPreviewLayer *_previewLayer;
    AVCaptureSession *_captureSession;
    UIView *_previewView;
    AVCaptureVideoDataOutput *_videoOutput;
    AVCaptureMovieFileOutput *_movieOutput;
    AVCaptureAudioDataOutput *_audioOutput;
    AVCaptureStillImageOutput *_photoOutput;
    SCSampleBufferHolder *_lastVideoBuffer;
    SCSampleBufferHolder *_lastAppendedVideoBuffer;
    dispatch_queue_t _videoQueue;
    dispatch_queue_t _audioQueue;
    CIContext *_context;
    BOOL _audioInputAdded;
    BOOL _audioOutputAdded;
    BOOL _videoInputAdded;
    BOOL _videoOutputAdded;
    BOOL _shouldAutoresumeRecording;
    BOOL _needsSwitchBackToContinuousFocus;
    int _beginSessionConfigurationCount;
    double _lastAppendedTime;
    NSTimer *_movieOutputProgressTimer;
    CMTime _lastMovieFileOutputTime;
    void(^_pauseCompletionHandler)();
}

@property (readonly, atomic) int buffersWaitingToProcessCount;

@end

@implementation SCRecorder

- (id)init {
    self = [super init];
    
    if (self) {
        _videoQueue = dispatch_queue_create("me.corsin.SCRecorder.Video", nil);
        _audioQueue = dispatch_queue_create("me.corsin.SCRecorder.Audio", nil);
        _recordSessionQueue = dispatch_queue_create("me.corsin.SCRecorder.RecordSession", nil);
        
        dispatch_set_target_queue(_recordSessionQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));

        dispatch_queue_set_specific(_recordSessionQueue, kSCRecorderRecordSessionQueueKey, "true", nil);
        
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] init];
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _initializeRecordSessionLazily = YES;
        
        _videoOrientation = AVCaptureVideoOrientationPortrait;
        
        [[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(_subjectAreaDidChange) name:AVCaptureDeviceSubjectAreaDidChangeNotification  object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaServicesWereReset:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaServicesWereLost:) name:AVAudioSessionMediaServicesWereLostNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(deviceOrientationChanged:) name:UIDeviceOrientationDidChangeNotification  object:nil];
        
        _lastAppendedVideoBuffer = [SCSampleBufferHolder new];
        _lastVideoBuffer = [SCSampleBufferHolder new];
        _maxRecordDuration = kCMTimeInvalid;
        
        self.device = AVCaptureDevicePositionBack;
        _videoConfiguration = [SCVideoConfiguration new];
        _audioConfiguration = [SCAudioConfiguration new];
        _photoConfiguration = [SCPhotoConfiguration new];
        
        [_videoConfiguration addObserver:self forKeyPath:@"enabled" options:NSKeyValueObservingOptionNew context:SCRecorderVideoEnabledContext];
        [_audioConfiguration addObserver:self forKeyPath:@"enabled" options:NSKeyValueObservingOptionNew context:SCRecorderAudioEnabledContext];
        [_photoConfiguration addObserver:self forKeyPath:@"options" options:NSKeyValueObservingOptionNew context:SCRecorderPhotoOptionsContext];
    }
    
    return self;
}

- (void)dealloc {
    [_videoConfiguration removeObserver:self forKeyPath:@"enabled"];
    [_audioConfiguration removeObserver:self forKeyPath:@"enabled"];
    [_photoConfiguration removeObserver:self forKeyPath:@"options"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self closeSession];
}

+ (SCRecorder*)recorder {
    return [[SCRecorder alloc] init];
}

- (void)applicationDidEnterBackground:(id)sender {
    _shouldAutoresumeRecording = _isRecording;
    [self pause];
}

- (void)applicationDidBecomeActive:(id)sender {
    [self reconfigureVideoInput:self.videoConfiguration.enabled audioInput:self.audioConfiguration.enabled];
    
    if (_shouldAutoresumeRecording) {
        _shouldAutoresumeRecording = NO;
        [self record];
    }
}

- (void)deviceOrientationChanged:(id)sender {
    if (_autoSetVideoOrientation) {
        dispatch_sync(_recordSessionQueue, ^{
            [self updateVideoOrientation];
        });
    }
}

- (void)sessionRuntimeError:(id)sender {
    [self startRunningSession];
}

- (void)updateVideoOrientation {
    if (!_recordSession.currentSegmentHasAudio && !_recordSession.currentSegmentHasVideo) {
        [_recordSession deinitialize];
    }
    
    AVCaptureVideoOrientation videoOrientation = [self actualVideoOrientation];
    AVCaptureConnection *videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if ([videoConnection isVideoOrientationSupported]) {
        videoConnection.videoOrientation = videoOrientation;
    }
    if ([_previewLayer.connection isVideoOrientationSupported]) {
        _previewLayer.connection.videoOrientation = videoOrientation;
    }
    
    AVCaptureConnection *photoConnection = [_photoOutput connectionWithMediaType:AVMediaTypeVideo];
    if ([photoConnection isVideoOrientationSupported]) {
        photoConnection.videoOrientation = videoOrientation;
    }
}

- (void)beginSessionConfiguration {
    if (_captureSession != nil) {
        _beginSessionConfigurationCount++;
        if (_beginSessionConfigurationCount == 1) {
            [_captureSession beginConfiguration];
        }
    }
}

- (void)commitSessionConfiguration {
    if (_captureSession != nil) {
        _beginSessionConfigurationCount--;
        if (_beginSessionConfigurationCount == 0) {
            [_captureSession commitConfiguration];
        }
    }
}

- (void)openSession:(void(^)(NSError *sessionError, NSError *audioError, NSError *videoError, NSError *photoError))completionHandler {
    if (_captureSession != nil) {
        [NSException raise:@"SCCameraException" format:@"The session is already opened"];
    }
    
    NSError *sessionError = nil;
    NSError *audioError = nil;
    NSError *videoError = nil;
    NSError *photoError = nil;
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    _beginSessionConfigurationCount = 0;
    _captureSession = session;

    [self beginSessionConfiguration];
    
    if ([session canSetSessionPreset:self.sessionPreset]) {
        session.sessionPreset = self.sessionPreset;
    } else {
        sessionError = [SCRecorder createError:@"Cannot set session preset"];
    }
    
    if (self.fastRecordMethodEnabled) {
        if (_movieOutput == nil) {
            _movieOutput = [AVCaptureMovieFileOutput new];
        }
        
        if ([session canAddOutput:_movieOutput]) {
            [session addOutput:_movieOutput];
        } else {
            videoError = [SCRecorder createError:@"Cannot add movieOutput inside the session"];
        }
    } else {
        _videoOutputAdded = NO;
        if (self.videoConfiguration.enabled) {
            if (_videoOutput == nil) {
                _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
                _videoOutput.alwaysDiscardsLateVideoFrames = NO;
                [_videoOutput setSampleBufferDelegate:self queue:_videoQueue];
            }
            
            if ([session canAddOutput:_videoOutput]) {
                [session addOutput:_videoOutput];
                _videoOutputAdded = YES;
            } else {
                videoError = [SCRecorder createError:@"Cannot add videoOutput inside the session"];
            }
        }
        
        _audioOutputAdded = NO;
        if (self.audioConfiguration.enabled) {
            if (_audioOutput == nil) {
                _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
                [_audioOutput setSampleBufferDelegate:self queue:_audioQueue];
            }
            
            if ([session canAddOutput:_audioOutput]) {
                [session addOutput:_audioOutput];
                _audioOutputAdded = YES;
            } else {
                audioError = [SCRecorder createError:@"Cannot add audioOutput inside the sesssion"];
            }
        }
    }
    
    if (self.photoConfiguration.enabled) {
        if (_photoOutput == nil) {
            _photoOutput = [[AVCaptureStillImageOutput alloc] init];
            _photoOutput.outputSettings = [self.photoConfiguration createOutputSettings];
        }
        
        if ([session canAddOutput:_photoOutput]) {
            [session addOutput:_photoOutput];
        } else {
            photoError = [SCRecorder createError:@"Cannot add photoOutput inside the session"];
        }
    }
    
    _previewLayer.session = session;
    
    [self reconfigureVideoInput:YES audioInput:YES];
    
    [self commitSessionConfiguration];
    
    if (completionHandler != nil) {
        completionHandler(nil, audioError, videoError, photoError);
    }
}

- (void)startRunningSession {
    if (_captureSession == nil) {
        [NSException raise:@"SCCamera" format:@"Session was not opened before"];
    }
    
    if (!_captureSession.isRunning) {
        [_captureSession startRunning];
    }
}

- (void)endRunningSession {
    [_captureSession stopRunning];
}

- (void)_subjectAreaDidChange {
    [self focusCenter];
}

- (UIImage *)_imageFromSampleBufferHolder:(SCSampleBufferHolder *)sampleBufferHolder {
    __block CMSampleBufferRef sampleBuffer = nil;
    dispatch_sync(_videoQueue, ^{
        sampleBuffer = sampleBufferHolder.sampleBuffer;
        
        if (sampleBuffer != nil) {
            CFRetain(sampleBuffer);
        }
    });
    
    if (sampleBuffer == nil) {
        return nil;
    }
    
    CVPixelBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:buffer];
    
    if (_context == nil) {
        _context = [CIContext contextWithEAGLContext:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2]];
    }
    
    CGImageRef cgImage = [_context createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer))];
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];

    CGImageRelease(cgImage);
    CFRelease(sampleBuffer);
    
    return image;
}

- (UIImage *)snapshotOfLastVideoBuffer {
    return [self _imageFromSampleBufferHolder:_lastVideoBuffer];
}

- (UIImage *)snapshotOfLastAppendedVideoBuffer {
    return [self _imageFromSampleBufferHolder:_lastAppendedVideoBuffer];
}

- (void)capturePhoto:(void(^)(NSError*, UIImage*))completionHandler {
    AVCaptureConnection *connection = [_photoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (connection != nil) {
        [_photoOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:
         ^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
             
             if (imageDataSampleBuffer != nil && error == nil) {
                 NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                 if (jpegData) {
                     UIImage *image = [UIImage imageWithData:jpegData];
                     if (completionHandler != nil) {
                         completionHandler(nil, image);
                     }
                 } else {
                     if (completionHandler != nil) {
                         completionHandler([SCRecorder createError:@"Failed to create jpeg data"], nil);
                     }
                 }
             } else {
                 if (completionHandler != nil) {
                     completionHandler(error, nil);
                 }
             }
         }];
    } else {
        if (completionHandler != nil) {
            completionHandler([SCRecorder createError:@"Camera session not started or Photo disabled"], nil);
        }
    }
}

- (void)closeSession {
    if (_captureSession != nil) {
        for (AVCaptureDeviceInput *input in _captureSession.inputs) {
            [_captureSession removeInput:input];
            if ([input.device hasMediaType:AVMediaTypeVideo]) {
                [self removeVideoObservers:input.device];
            }
        }
        
        for (AVCaptureOutput *output in _captureSession.outputs) {
            [_captureSession removeOutput:output];
        }
        
        _previewLayer.session = nil;
        _captureSession = nil;
    }
}

- (void)_progressTimerFired:(NSTimer *)progressTimer {
    CMTime recordedDuration = _movieOutput.recordedDuration;
    
    if (CMTIME_COMPARE_INLINE(recordedDuration, !=, _lastMovieFileOutputTime)) {
        SCRecordSession *recordSession = _recordSession;
        id<SCRecorderDelegate> delegate = self.delegate;
        
        if (recordSession != nil) {
            if ([delegate respondsToSelector:@selector(recorder:didAppendVideoSampleBuffer:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate recorder:self didAppendVideoSampleBuffer:self.recordSession];
                });
            }
            if ([delegate respondsToSelector:@selector(recorder:didAppendAudioSampleBuffer:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate recorder:self didAppendAudioSampleBuffer:self.recordSession];
                });
            }
        }
    }
    
    _lastMovieFileOutputTime = recordedDuration;
}

- (void)record {
    dispatch_sync(_recordSessionQueue, ^{
        _isRecording = YES;
        if (_movieOutput != nil && _recordSession != nil) {
            _movieOutput.maxRecordedDuration = self.maxRecordDuration;
            [self beginRecordSegmentIfNeeded:_recordSession];
            if (_movieOutputProgressTimer == nil) {
                [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0 target:self selector:@selector(_progressTimerFired:) userInfo:nil repeats:YES];
            }
        }
    });
}

- (void)pause {
    [self pause:nil];
}

- (void)pause:(void(^)())completionHandler {
    dispatch_sync(_recordSessionQueue, ^{
        _isRecording = NO;
        
        SCRecordSession *recordSession = _recordSession;
        
        if (recordSession != nil) {
            if (recordSession.recordSegmentReady) {
                if (recordSession.isUsingMovieFileOutput) {
                    _pauseCompletionHandler = completionHandler;
                    [_movieOutputProgressTimer invalidate];
                    _movieOutputProgressTimer = nil;
                    [recordSession endRecordSegment:nil];
                } else {
                    [recordSession endRecordSegment:^(NSInteger segmentIndex, NSError *error) {
                        id<SCRecorderDelegate> delegate = self.delegate;
                        if ([delegate respondsToSelector:@selector(recorder:didEndRecordSegment:segmentIndex:error:)]) {
                            [delegate recorder:self didEndRecordSegment:recordSession segmentIndex:segmentIndex error:error];
                        }
                        if (completionHandler != nil) {
                            completionHandler();
                        }
                    }];
                }
            } else {
                dispatch_handler(completionHandler);
            }
        } else {
            dispatch_handler(completionHandler);
        }
    });
}

+ (NSError*)createError:(NSString*)errorDescription {
    return [NSError errorWithDomain:@"SCRecorder" code:200 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
}

- (void)beginRecordSegmentIfNeeded:(SCRecordSession *)recordSession {
    if (!recordSession.recordSegmentBegan) {
        NSError *error = nil;
        if (_movieOutput != nil && self.fastRecordMethodEnabled) {
            [recordSession beginRecordSegmentUsingMovieFileOutput:_movieOutput error:&error delegate:self];
        } else {
            [recordSession beginRecordSegment:&error];
        }
        
        id<SCRecorderDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(recorder:didBeginRecordSegment:error:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate recorder:self didBeginRecordSegment:recordSession error:error];
            });
        }
    }
}

- (void)checkRecordSessionDuration:(SCRecordSession *)recordSession {
    CMTime currentRecordDuration = recordSession.currentRecordDuration;
    CMTime suggestedMaxRecordDuration = _maxRecordDuration;
    
    if (CMTIME_IS_VALID(suggestedMaxRecordDuration)) {
        if (CMTIME_COMPARE_INLINE(currentRecordDuration, >=, suggestedMaxRecordDuration)) {
            _isRecording = NO;

            [recordSession endRecordSegment:^(NSInteger segmentIndex, NSError *error) {
                id<SCRecorderDelegate> delegate = self.delegate;
                if ([delegate respondsToSelector:@selector(recorder:didEndRecordSegment:segmentIndex:error:)]) {
                    [delegate recorder:self didEndRecordSegment:recordSession segmentIndex:segmentIndex error:error];
                }
                
                if ([delegate respondsToSelector:@selector(recorder:didCompleteRecordSession:)]) {
                    [delegate recorder:self didCompleteRecordSession:recordSession];
                }
            }];
        }
    }
}

- (CMTime)frameDurationFromConnection:(AVCaptureConnection *)connection {
    AVCaptureDevice *device = [self currentVideoDeviceInput].device;
    
    if ([device respondsToSelector:@selector(activeVideoMaxFrameDuration)]) {
        return device.activeVideoMinFrameDuration;
    }
    
    return connection.videoMinFrameDuration;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (captureOutput == _videoOutput) {
        if (_videoConfiguration.shouldIgnore) {
            return;
        }
        
        _lastVideoBuffer.sampleBuffer = sampleBuffer;
        id<CIImageRenderer> imageRenderer = _CIImageRenderer;
        if (imageRenderer != nil) {
            CFRetain(sampleBuffer);
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([imageRenderer respondsToSelector:@selector(setImageBySampleBuffer:)]) {
                    [imageRenderer setImageBySampleBuffer:sampleBuffer];
                } else {
                    CVPixelBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:buffer];
                    
                    imageRenderer.CIImage = ciImage;
                }
                
                CFRelease(sampleBuffer);
            });
        }
    } else if (_audioConfiguration.shouldIgnore) {
        return;
    }
    
    if (_initializeRecordSessionLazily && !_isRecording) {
        return;
    }
    
    _buffersWaitingToProcessCount++;
    if (_isRecording) {
//        if (_buffersWaitingToProcessCount > 10) {
//            NSLog(@"Warning: Reached %d waiting to process", _buffersWaitingToProcessCount);
//        }
//        NSLog(@"Waiting to process %d", _buffersWaitingToProcessCount);
    }

    CFRetain(sampleBuffer);
    dispatch_async(_recordSessionQueue, ^{
        double timeToWait = kMinTimeBetweenAppend - (CACurrentMediaTime() - _lastAppendedTime);
        
        if (timeToWait > 0) {
            [NSThread sleepForTimeInterval:timeToWait];
        }
        
        SCRecordSession *recordSession = _recordSession;

        if (!(_initializeRecordSessionLazily && !_isRecording) && recordSession != nil) {
            if (recordSession != nil) {
                if (captureOutput == _videoOutput) {
                    if (!recordSession.videoInitializationFailed && !_videoConfiguration.shouldIgnore) {
                        if (!recordSession.videoInitialized) {
                            NSError *error = nil;
                            NSDictionary *settings = [self.videoConfiguration createAssetWriterOptionsUsingSampleBuffer:sampleBuffer];
                            
                            CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
                            [recordSession initializeVideo:settings formatDescription:formatDescription error:&error];
                            
                            id<SCRecorderDelegate> delegate = self.delegate;
                            if ([delegate respondsToSelector:@selector(recorder:didInitializeVideoInRecordSession:error:)]) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [delegate recorder:self didInitializeVideoInRecordSession:recordSession error:error];
                                });
                            }
                        }
                        
                        if (!self.audioEnabledAndReady || recordSession.audioInitialized || recordSession.audioInitializationFailed) {
                            [self beginRecordSegmentIfNeeded:recordSession];
                            
                            if (_isRecording && recordSession.recordSegmentReady) {
                                id<SCRecorderDelegate> delegate = self.delegate;
                                CMTime duration = [self frameDurationFromConnection:connection];
                                if ([recordSession appendVideoSampleBuffer:sampleBuffer duration:duration]) {
                                    _lastAppendedVideoBuffer.sampleBuffer = sampleBuffer;
                                    
                                    if ([delegate respondsToSelector:@selector(recorder:didAppendVideoSampleBuffer:)]) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [delegate recorder:self didAppendVideoSampleBuffer:recordSession];
                                        });
                                    }
                                    
                                    [self checkRecordSessionDuration:recordSession];
                                } else {
                                    if ([delegate respondsToSelector:@selector(recorder:didSkipVideoSampleBuffer:)]) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [delegate recorder:self didSkipVideoSampleBuffer:recordSession];
                                        });
                                    }
                                }
                                
                            }
                        }
                    }
                } else if (captureOutput == _audioOutput) {
                    if (!recordSession.audioInitializationFailed && !_audioConfiguration.shouldIgnore) {
                        if (!recordSession.audioInitialized) {
                            NSError *error = nil;
                            NSDictionary *settings = [self.audioConfiguration createAssetWriterOptionsUsingSampleBuffer:sampleBuffer];
                            CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
                            [recordSession initializeAudio:settings formatDescription:formatDescription error:&error];
                            
                            id<SCRecorderDelegate> delegate = self.delegate;
                            if ([delegate respondsToSelector:@selector(recorder:didInitializeAudioInRecordSession:error:)]) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [delegate recorder:self didInitializeAudioInRecordSession:recordSession error:error];
                                });
                            }
                        }
                        
                        if (!self.videoEnabledAndReady || recordSession.videoInitialized || recordSession.videoInitializationFailed) {
                            [self beginRecordSegmentIfNeeded:recordSession];
                            
                            if (_isRecording && recordSession.recordSegmentReady && (!self.videoEnabledAndReady || recordSession.currentSegmentHasVideo)) {
                                id<SCRecorderDelegate> delegate = self.delegate;
                                if ([recordSession appendAudioSampleBuffer:sampleBuffer]) {
                                    if ([delegate respondsToSelector:@selector(recorder:didAppendAudioSampleBuffer:)]) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [delegate recorder:self didAppendAudioSampleBuffer:recordSession];
                                        });
                                    }
                                    
                                    [self checkRecordSessionDuration:recordSession];
                                } else {
                                    if ([delegate respondsToSelector:@selector(recorder:didSkipAudioSampleBuffer:)]) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [delegate recorder:self didSkipAudioSampleBuffer:recordSession];
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        CFRelease(sampleBuffer);
        _lastAppendedTime = CACurrentMediaTime();

        _buffersWaitingToProcessCount--;
        if (_isRecording) {
//            NSLog(@"End waiting to process %d", _buffersWaitingToProcessCount);
        }
    });
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    CMTime recordedDuration = captureOutput.recordedDuration;
    dispatch_sync(_recordSessionQueue, ^{
        [_recordSession appendRecordSegment:^(NSInteger segmentNumber, NSError *error) {
            void (^pauseCompletionHandler)() = _pauseCompletionHandler;
            _pauseCompletionHandler = nil;
            
            SCRecordSession *recordSession = _recordSession;
            
            if (recordSession != nil) {
                id<SCRecorderDelegate> delegate = self.delegate;
                if ([delegate respondsToSelector:@selector(recorder:didEndRecordSegment:segmentIndex:error:)]) {
                    [delegate recorder:self didEndRecordSegment:recordSession segmentIndex:segmentNumber error:error];
                }
                
                if (CMTIME_IS_VALID(_maxRecordDuration) && CMTIME_COMPARE_INLINE(recordedDuration, >=, _maxRecordDuration)) {
                    if ([delegate respondsToSelector:@selector(recorder:didCompleteRecordSession:)]) {
                        [delegate recorder:self didCompleteRecordSession:recordSession];
                    }
                }
            }
            
            if (pauseCompletionHandler != nil) {
                pauseCompletionHandler();
            }
        } error:error url:outputFileURL duration:recordedDuration];
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    id<SCRecorderDelegate> delegate = self.delegate;
    
    if (context == SCRecorderFocusContext) {
        BOOL isFocusing = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (isFocusing) {
            if ([delegate respondsToSelector:@selector(recorderDidStartFocus:)]) {
                [delegate recorderDidStartFocus:self];
            }
        } else {
            if ([delegate respondsToSelector:@selector(recorderDidEndFocus:)]) {
                [delegate recorderDidEndFocus:self];
            }
            
            if (_needsSwitchBackToContinuousFocus) {
                _needsSwitchBackToContinuousFocus = NO;
                [self continuousFocusAtPoint:self.focusPointOfInterest];
            }

        }
    } else if (context == SCRecorderAudioEnabledContext) {
        if ([NSThread isMainThread]) {
            [self reconfigureVideoInput:NO audioInput:YES];
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self reconfigureVideoInput:NO audioInput:YES];
            });
        }
    } else if (context == SCRecorderVideoEnabledContext) {
        if ([NSThread isMainThread]) {
            [self reconfigureVideoInput:YES audioInput:NO];
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self reconfigureVideoInput:YES audioInput:NO];
            });
        }
    } else if (context == SCRecorderPhotoOptionsContext) {
        _photoOutput.outputSettings = [_photoConfiguration createOutputSettings];
    }
}

- (void)addVideoObservers:(AVCaptureDevice*)videoDevice {
    [videoDevice addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:SCRecorderFocusContext];
}

- (void)removeVideoObservers:(AVCaptureDevice*)videoDevice {
    [videoDevice removeObserver:self forKeyPath:@"adjustingFocus"];
}

- (void)configureDevice:(AVCaptureDevice*)newDevice mediaType:(NSString*)mediaType error:(NSError**)error {
    AVCaptureDeviceInput *currentInput = [self currentDeviceInputForMediaType:mediaType];
    AVCaptureDevice *currentUsedDevice = currentInput.device;
    
    if (currentUsedDevice != newDevice) {
        if ([mediaType isEqualToString:AVMediaTypeVideo]) {
            NSError *error;
            if ([newDevice lockForConfiguration:&error]) {
                if (newDevice.isSmoothAutoFocusSupported) {
                    newDevice.smoothAutoFocusEnabled = YES;
                }
                newDevice.subjectAreaChangeMonitoringEnabled = true;
                
                if (newDevice.isLowLightBoostSupported) {
                    newDevice.automaticallyEnablesLowLightBoostWhenAvailable = YES;
                }
                [newDevice unlockForConfiguration];
            } else {
                NSLog(@"Failed to configure device: %@", error);
            }
            _videoInputAdded = NO;
        } else {
            _audioInputAdded = NO;
        }

        AVCaptureDeviceInput *newInput = nil;
        
        if (newDevice != nil) {
            newInput = [[AVCaptureDeviceInput alloc] initWithDevice:newDevice error:error];
        }
        
        if (*error == nil) {
            if (currentInput != nil) {
                [_captureSession removeInput:currentInput];
                if ([currentInput.device hasMediaType:AVMediaTypeVideo]) {
                    [self removeVideoObservers:currentInput.device];
                }
            }
            
            if (newInput != nil) {
                if ([_captureSession canAddInput:newInput]) {
                    [_captureSession addInput:newInput];
                    if ([newInput.device hasMediaType:AVMediaTypeVideo]) {
                        _videoInputAdded = YES;

                        [self addVideoObservers:newInput.device];
                        
                        AVCaptureConnection *videoConnection = [self videoConnection];
                        if ([videoConnection isVideoStabilizationSupported]) {
                            if ([videoConnection respondsToSelector:@selector(setPreferredVideoStabilizationMode:)]) {
                                videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
                            } else {
                                videoConnection.enablesVideoStabilizationWhenAvailable = YES;
                            }
                        }
                    } else {
                        _audioInputAdded = YES;
                    }
                } else {
                    *error = [SCRecorder createError:@"Failed to add input to capture session"];
                }
            }
        }
    }
}

- (void)reconfigureVideoInput:(BOOL)shouldConfigureVideo audioInput:(BOOL)shouldConfigureAudio {
    if (_captureSession != nil) {
        [self beginSessionConfiguration];
        
        NSError *videoError = nil;
        if (shouldConfigureVideo) {
            [self configureDevice:[self videoDevice] mediaType:AVMediaTypeVideo error:&videoError];
            dispatch_sync(_recordSessionQueue, ^{
                [self updateVideoOrientation];
            });
        }
        
        NSError *audioError = nil;
        
        if (shouldConfigureAudio) {
            [self configureDevice:[self audioDevice] mediaType:AVMediaTypeAudio error:&audioError];
        }
        
        [self commitSessionConfiguration];
        
        id<SCRecorderDelegate> delegate = self.delegate;
        if (shouldConfigureAudio) {
            if ([delegate respondsToSelector:@selector(recorder:didReconfigureAudioInput:)]) {
                [delegate recorder:self didReconfigureAudioInput:audioError];
            }
        }
        if (shouldConfigureVideo) {
            if ([delegate respondsToSelector:@selector(recorder:didReconfigureVideoInput:)]) {
                [delegate recorder:self didReconfigureVideoInput:videoError];
            }
        }
    }
}

- (void)switchCaptureDevices {
    if (self.device == AVCaptureDevicePositionBack) {
        self.device = AVCaptureDevicePositionFront;
    } else {
        self.device = AVCaptureDevicePositionBack;
    }
}

- (void)previewViewFrameChanged {
    _previewLayer.frame = _previewView.bounds;
}

#pragma mark - FOCUS

// Convert from view coordinates to camera coordinates, where {0,0} represents the top left of the picture area, and {1,1} represents
// the bottom right in landscape mode with the home button on the right.
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates
{
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = self.previewView.frame.size;
    
    if ([self.previewLayer.connection isVideoMirrored]) {
        viewCoordinates.x = frameSize.width - viewCoordinates.x;
    }
    
    if ( [[self.previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize] ) {
		// Scale, switch x and y, and reverse x
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for (AVCaptureInputPort *port in [self.currentVideoDeviceInput ports]) {
            if ([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if ( [[self.previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect] ) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
						// If point is inside letterboxed area, do coordinate conversion; otherwise, don't change the default value returned (.5,.5)
                        if (point.x >= blackBar && point.x <= blackBar + x2) {
							// Scale (accounting for the letterboxing on the left and right of the video preview), switch x and y, and reverse x
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
						// If point is inside letterboxed area, do coordinate conversion. Otherwise, don't change the default value returned (.5,.5)
                        if (point.y >= blackBar && point.y <= blackBar + y2) {
							// Scale (accounting for the letterboxing on the top and bottom of the video preview), switch x and y, and reverse x
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if ([[self.previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
					// Scale, switch x and y, and reverse x
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2; // Account for cropped height
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2); // Account for cropped width
                        xc = point.y / frameSize.height;
                    }
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}

- (void)mediaServicesWereReset:(NSNotification *)notification {
    NSLog(@"MEDIA SERVICES WERE RESET");
}

- (void)mediaServicesWereLost:(NSNotification *)notification {
    NSLog(@"MEDIA SERVICES WERE LOST");
}

- (void)sessionInterrupted:(NSNotification *)notification {
    NSNumber *interruption = [notification.userInfo objectForKey:AVAudioSessionInterruptionOptionKey];
    
    if (interruption != nil) {
        AVAudioSessionInterruptionOptions options = interruption.unsignedIntValue;
        if (options == AVAudioSessionInterruptionOptionShouldResume) {
            [self reconfigureVideoInput:NO audioInput:self.audioConfiguration.enabled];
        }
    }
}

- (void)lockFocus {
    AVCaptureDevice *device = [self.currentVideoDeviceInput device];
    if ([device isFocusModeSupported:AVCaptureFocusModeLocked]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusMode:AVCaptureFocusModeLocked];
            [device unlockForConfiguration];
        }
    }
}

- (void)applyFocusMode:(AVCaptureFocusMode)focusMode withPointOfInterest:(CGPoint)point {
    AVCaptureDevice *device = [self.currentVideoDeviceInput device];
    
    if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode]) {
        CGPoint currentPointOfInterest = device.focusPointOfInterest;
        AVCaptureFocusMode currentFocusMode = device.focusMode;
        
        NSError *error;
        if (!CGPointEqualToPoint(point, currentPointOfInterest) || currentFocusMode != focusMode) {
            if ([device lockForConfiguration:&error]) {
                [device setFocusPointOfInterest:point];
                [device setFocusMode:focusMode];
                [device unlockForConfiguration];
                
                if (focusMode != AVCaptureFocusModeContinuousAutoFocus) {
                    id<SCRecorderDelegate> delegate = self.delegate;
                    if ([delegate respondsToSelector:@selector(recorderWillStartFocus:)]) {
                        [delegate recorderWillStartFocus:self];
                    }
                }
            }
        }
    }
}

// Perform an auto focus at the specified point. The focus mode will automatically change to locked once the auto focus is complete.
- (void)autoFocusAtPoint:(CGPoint)point {
    [self applyFocusMode:AVCaptureFocusModeAutoFocus withPointOfInterest:point];
}

// Switch to continuous auto focus mode at the specified point
- (void)continuousFocusAtPoint:(CGPoint)point {
    [self applyFocusMode:AVCaptureFocusModeContinuousAutoFocus withPointOfInterest:point];
}

- (void)focusCenter {
    _needsSwitchBackToContinuousFocus = YES;
    [self autoFocusAtPoint:CGPointMake(0.5, 0.5)];
}

- (void)refocus {
    _needsSwitchBackToContinuousFocus = YES;
    [self autoFocusAtPoint:self.focusPointOfInterest];
}

- (CGPoint)focusPointOfInterest {
    return [self.currentVideoDeviceInput device].focusPointOfInterest;
}

- (BOOL)focusSupported {
    return [self currentVideoDeviceInput].device.isFocusPointOfInterestSupported;
}

- (AVCaptureDeviceInput*)currentAudioDeviceInput {
    return [self currentDeviceInputForMediaType:AVMediaTypeAudio];
}

- (AVCaptureDeviceInput*)currentVideoDeviceInput {
    return [self currentDeviceInputForMediaType:AVMediaTypeVideo];
}

- (AVCaptureDeviceInput*)currentDeviceInputForMediaType:(NSString*)mediaType {
    for (AVCaptureDeviceInput* deviceInput in _captureSession.inputs) {
        if ([deviceInput.device hasMediaType:mediaType]) {
            return deviceInput;
        }
    }
    
    return nil;
}

- (AVCaptureDevice*)audioDevice {
    if (!self.audioConfiguration.enabled) {
        return nil;
    }
    
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
}

- (AVCaptureDevice*)videoDevice {
    if (!self.videoConfiguration.enabled) {
        return nil;
    }
    
    return [SCRecorderTools videoDeviceForPosition:_device];
}

- (AVCaptureVideoOrientation)actualVideoOrientation {
    AVCaptureVideoOrientation videoOrientation = _videoOrientation;
    
    if (_autoSetVideoOrientation) {
        UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
        
        switch (deviceOrientation) {
            case UIDeviceOrientationLandscapeLeft:
                videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                break;
            case UIDeviceOrientationLandscapeRight:
                videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                break;
            case UIDeviceOrientationPortrait:
                videoOrientation = AVCaptureVideoOrientationPortrait;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
                break;
            default:
                break;
        }
    }
    
    return videoOrientation;
}

- (AVCaptureSession*)captureSession {
    return _captureSession;
}

- (void)setPreviewView:(UIView *)previewView {
    [_previewLayer removeFromSuperlayer];
    
    _previewView = previewView;
    
    if (_previewView != nil) {
        _previewLayer.frame = _previewView.bounds;
        [_previewView.layer insertSublayer:_previewLayer atIndex:0];
    }
}

- (UIView*)previewView {
    return _previewView;
}

- (NSDictionary*)photoOutputSettings {
    return _photoOutput.outputSettings;
}

- (void)setPhotoOutputSettings:(NSDictionary *)photoOutputSettings {
    _photoOutput.outputSettings = photoOutputSettings;
}

- (void)setDevice:(AVCaptureDevicePosition)device {
    _device = device;
    if (_captureSession != nil) {
        [self reconfigureVideoInput:self.videoConfiguration.enabled audioInput:NO];
    }
}

- (void)setFlashMode:(SCFlashMode)flashMode {
    AVCaptureDevice *currentDevice = [self videoDevice];
    NSError *error = nil;
    
    if (currentDevice.hasFlash) {
        if ([currentDevice lockForConfiguration:&error]) {
            if (flashMode == SCFlashModeLight) {
                if ([currentDevice isTorchModeSupported:AVCaptureTorchModeOn]) {
                    [currentDevice setTorchMode:AVCaptureTorchModeOn];
                }
                if ([currentDevice isFlashModeSupported:AVCaptureFlashModeOff]) {
                    [currentDevice setFlashMode:AVCaptureFlashModeOff];
                }
            } else {
                if ([currentDevice isTorchModeSupported:AVCaptureTorchModeOff]) {
                    [currentDevice setTorchMode:AVCaptureTorchModeOff];
                }
                if ([currentDevice isFlashModeSupported:(AVCaptureFlashMode)flashMode]) {
                    [currentDevice setFlashMode:(AVCaptureFlashMode)flashMode];
                }
            }
            
            [currentDevice unlockForConfiguration];
        }
    } else {
        error = [SCRecorder createError:@"Current device does not support flash"];
    }
    
    id<SCRecorderDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(recorder:didChangeFlashMode:error:)]) {
        [delegate recorder:self didChangeFlashMode:flashMode error:error];
    }
    
    if (error == nil) {
        _flashMode = flashMode;
    }
}

- (BOOL)deviceHasFlash {
    AVCaptureDevice *currentDevice = [self videoDevice];
    return currentDevice.hasFlash;
}

- (AVCaptureVideoPreviewLayer*)previewLayer {
    return _previewLayer;
}

- (BOOL)isCaptureSessionOpened {
    return _captureSession != nil;
}

- (void)setSessionPreset:(NSString *)sessionPreset {
    if (_captureSession != nil) {
        NSError *error = nil;
        if ([_captureSession canSetSessionPreset:sessionPreset]) {
            [_captureSession beginConfiguration];
            _captureSession.sessionPreset = sessionPreset;
            [_captureSession commitConfiguration];
        } else {
            error = [SCRecorder createError:@"Failed to set session preset"];
        }
        
        if (error == nil) {
            _sessionPreset = [sessionPreset copy];
        }
        
        id<SCRecorderDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(recorder:didChangeSessionPreset:error:)]) {
            [delegate recorder:self didChangeSessionPreset:sessionPreset error:error];
        }
    } else {
        _sessionPreset = [sessionPreset copy];
    }
}

- (void)setVideoOrientation:(AVCaptureVideoOrientation)videoOrientation {
    _videoOrientation = videoOrientation;
    [self updateVideoOrientation];
}

- (void)setRecordSession:(SCRecordSession *)recordSession {
    if (_recordSession != recordSession) {
        dispatch_sync(_recordSessionQueue, ^{
            _recordSession.recorder = nil;
            
            _recordSession = recordSession;
            
            recordSession.recorder = self;
        });
    }
}

- (AVCaptureFocusMode)focusMode {
    return [self currentVideoDeviceInput].device.focusMode;
}

- (AVCaptureConnection*)videoConnection {
	for (AVCaptureConnection * connection in _videoOutput.connections) {
		for (AVCaptureInputPort * port in connection.inputPorts) {
			if ([port.mediaType isEqual:AVMediaTypeVideo]) {
				return connection;
			}
		}
	}
	
	return nil;
}

- (CMTimeScale)frameRate {
    AVCaptureDeviceInput * deviceInput = [self currentVideoDeviceInput];
    
    CMTimeScale framerate = 0;
    
    if (deviceInput != nil) {
        if ([deviceInput.device respondsToSelector:@selector(activeVideoMaxFrameDuration)]) {
            framerate = deviceInput.device.activeVideoMaxFrameDuration.timescale;
        } else {
            AVCaptureConnection *videoConnection = [self videoConnection];
            framerate = videoConnection.videoMaxFrameDuration.timescale;
        }
    }
    
    return framerate;
}

- (void)setFrameRate:(CMTimeScale)framePerSeconds {
    CMTime fps = CMTimeMake(1, framePerSeconds);
    
    AVCaptureDevice * device = [self videoDevice];
    
    if (device != nil) {
        NSError * error = nil;
        BOOL formatSupported = [SCRecorderTools formatInRange:device.activeFormat frameRate:framePerSeconds];
        
        if (formatSupported) {
            if ([device respondsToSelector:@selector(activeVideoMinFrameDuration)]) {
                if ([device lockForConfiguration:&error]) {
                    device.activeVideoMaxFrameDuration = fps;
                    device.activeVideoMinFrameDuration = fps;
                    [device unlockForConfiguration];
                } else {
                    NSLog(@"Failed to set FramePerSeconds into camera device: %@", error.description);
                }
            } else {
                AVCaptureConnection *connection = [self videoConnection];
                if (connection.isVideoMaxFrameDurationSupported) {
                    connection.videoMaxFrameDuration = fps;
                } else {
                    NSLog(@"Failed to set FrameRate into camera device");
                }
                if (connection.isVideoMinFrameDurationSupported) {
                    connection.videoMinFrameDuration = fps;
                } else {
                    NSLog(@"Failed to set FrameRate into camera device");
                }
            }
        } else {
            NSLog(@"Unsupported frame rate %ld on current device format.", (long)framePerSeconds);
        }
    }
}

- (BOOL)setActiveFormatWithFrameRate:(CMTimeScale)frameRate error:(NSError *__autoreleasing *)error {
    return [self setActiveFormatWithFrameRate:frameRate width:self.videoConfiguration.size.width andHeight:self.videoConfiguration.size.height error:error];
}

- (BOOL)setActiveFormatWithFrameRate:(CMTimeScale)frameRate width:(int)width andHeight:(int)height error:(NSError *__autoreleasing *)error {
    AVCaptureDevice *device = [self videoDevice];
    CMVideoDimensions dimensions;
    dimensions.width = width;
    dimensions.height = height;
    
    BOOL foundSupported = NO;
    
    if (device != nil) {
        AVCaptureDeviceFormat *bestFormat = nil;
        
        for (AVCaptureDeviceFormat *format in device.formats) {
            if ([SCRecorderTools formatInRange:format frameRate:frameRate dimensions:dimensions]) {
                if (bestFormat == nil) {
                    bestFormat = format;
                } else {
                    CMVideoDimensions bestDimensions = CMVideoFormatDescriptionGetDimensions(bestFormat.formatDescription);
                    CMVideoDimensions currentDimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
                    
                    if (currentDimensions.width < bestDimensions.width && currentDimensions.height < bestDimensions.height) {
                        bestFormat = format;
                    } else if (currentDimensions.width == bestDimensions.width && currentDimensions.height == bestDimensions.height) {
                        if ([SCRecorderTools maxFrameRateForFormat:bestFormat minFrameRate:frameRate] > [SCRecorderTools maxFrameRateForFormat:format minFrameRate:frameRate]) {
                            bestFormat = format;
                        }
                    }
                }
            }
        }
        
        if (bestFormat != nil) {
            if ([device lockForConfiguration:error]) {
                CMTime frameDuration = CMTimeMake(1, frameRate);
                
                device.activeFormat = bestFormat;
                foundSupported = true;
                
                device.activeVideoMinFrameDuration = frameDuration;
                device.activeVideoMaxFrameDuration = frameDuration;
                
                [device unlockForConfiguration];
            }
        } else {
            if (error != nil) {
                *error = [SCRecorder createError:[NSString stringWithFormat:@"No format that supports framerate %d and dimensions %d/%d was found", (int)frameRate, dimensions.width, dimensions.height]];
            }
        }
    } else {
        if (error != nil) {
            *error = [SCRecorder createError:@"The camera must be initialized before setting active format"];
        }
    }
    
    if (foundSupported && error != nil) {
        *error = nil;
    }
    
    return foundSupported;
}

- (CGFloat)ratioRecorded {
    CGFloat ratio = 0;
    
    if (CMTIME_IS_VALID(_maxRecordDuration)) {
        Float64 maxRecordDuration = CMTimeGetSeconds(_maxRecordDuration);
        Float64 recordedTime = CMTimeGetSeconds(self.recordSession.currentRecordDuration);
        
        ratio = (CGFloat)(recordedTime / maxRecordDuration);
    }
    
    return ratio;
}

- (AVCaptureVideoDataOutput *)videoOutput {
    return _videoOutput;
}

- (AVCaptureAudioDataOutput *)audioOutput {
    return _audioOutput;
}

- (AVCaptureStillImageOutput *)photoOutput {
    return _photoOutput;
}

- (BOOL)audioEnabledAndReady {
    return _audioOutputAdded && _audioInputAdded && !_audioConfiguration.shouldIgnore;
}

- (BOOL)videoEnabledAndReady {
    return _videoOutputAdded && _videoInputAdded && !_videoConfiguration.shouldIgnore;
}

+ (SCRecorder *)sharedRecorder {
    static SCRecorder *_sharedRecorder = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedRecorder = [SCRecorder new];
    });
    
    return _sharedRecorder;
}

+ (BOOL)isRecordSessionQueue {
    return dispatch_get_specific(kSCRecorderRecordSessionQueueKey) != nil;
}

@end
