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
#define kSCRecorderRecordSessionQueueKey "SCRecorderRecordSessionQueue"
#define kMinTimeBetweenAppend 0.004

@interface SCRecorder() {
    AVCaptureVideoPreviewLayer *_previewLayer;
    AVCaptureSession *_captureSession;
    UIView *_previewView;
    AVCaptureVideoDataOutput *_videoOutput;
    AVCaptureMovieFileOutput *_movieOutput;
    AVCaptureAudioDataOutput *_audioOutput;
    AVCaptureStillImageOutput *_photoOutput;
    SCSampleBufferHolder *_lastVideoBuffer;
    CIContext *_context;
    BOOL _audioInputAdded;
    BOOL _audioOutputAdded;
    BOOL _videoInputAdded;
    BOOL _videoOutputAdded;
    BOOL _shouldAutoresumeRecording;
    BOOL _needsSwitchBackToContinuousFocus;
    BOOL _adjustingFocus;
    int _beginSessionConfigurationCount;
    double _lastAppendedVideoTime;
    NSTimer *_movieOutputProgressTimer;
    CMTime _lastMovieFileOutputTime;
    void(^_pauseCompletionHandler)();
    SCFilter *_transformFilter;
    size_t _transformFilterBufferWidth;
    size_t _transformFilterBufferHeight;
}

@property (readonly, atomic) int buffersWaitingToProcessCount;

@end

@implementation SCRecorder

static char* SCRecorderFocusContext = "FocusContext";
static char* SCRecorderExposureContext = "ExposureContext";
static char* SCRecorderVideoEnabledContext = "VideoEnabledContext";
static char* SCRecorderAudioEnabledContext = "AudioEnabledContext";
static char* SCRecorderPhotoOptionsContext = "PhotoOptionsContext";

- (id)init {
    self = [super init];
    
    if (self) {
        _sessionQueue = dispatch_queue_create("me.corsin.SCRecorder.RecordSession", nil);
        
        dispatch_queue_set_specific(_sessionQueue, kSCRecorderRecordSessionQueueKey, "true", nil);
        dispatch_set_target_queue(_sessionQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        
        _captureSessionPreset = AVCaptureSessionPresetHigh;
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] init];
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _initializeSessionLazily = YES;
        
        _videoOrientation = AVCaptureVideoOrientationPortrait;
        
        [[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(_subjectAreaDidChange) name:AVCaptureDeviceSubjectAreaDidChangeNotification  object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaServicesWereReset:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaServicesWereLost:) name:AVAudioSessionMediaServicesWereLostNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(deviceOrientationChanged:) name:UIDeviceOrientationDidChangeNotification  object:nil];
        
        _lastVideoBuffer = [SCSampleBufferHolder new];
        _maxRecordDuration = kCMTimeInvalid;
        _resetZoomOnChangeDevice = YES;
        
        self.device = AVCaptureDevicePositionBack;
        _videoConfiguration = [SCVideoConfiguration new];
        _audioConfiguration = [SCAudioConfiguration new];
        _photoConfiguration = [SCPhotoConfiguration new];
        
        [_videoConfiguration addObserver:self forKeyPath:@"enabled" options:NSKeyValueObservingOptionNew context:SCRecorderVideoEnabledContext];
        [_audioConfiguration addObserver:self forKeyPath:@"enabled" options:NSKeyValueObservingOptionNew context:SCRecorderAudioEnabledContext];
        [_photoConfiguration addObserver:self forKeyPath:@"options" options:NSKeyValueObservingOptionNew context:SCRecorderPhotoOptionsContext];
        
        _context = [SCContext new].CIContext;
    }
    
    return self;
}

- (void)dealloc {
    [_videoConfiguration removeObserver:self forKeyPath:@"enabled"];
    [_audioConfiguration removeObserver:self forKeyPath:@"enabled"];
    [_photoConfiguration removeObserver:self forKeyPath:@"options"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self unprepare];
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
        dispatch_sync(_sessionQueue, ^{
            [self updateVideoOrientation];
        });
    }
}

- (void)sessionRuntimeError:(id)sender {
    [self startRunning];
}

- (void)updateVideoOrientation {
    if (!_session.currentSegmentHasAudio && !_session.currentSegmentHasVideo) {
        [_session deinitialize];
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
    
    AVCaptureConnection *movieOutputConnection = [_movieOutput connectionWithMediaType:AVMediaTypeVideo];
    if (movieOutputConnection.isVideoOrientationSupported) {
        movieOutputConnection.videoOrientation = videoOrientation;
    }
    
}

- (void)beginConfiguration {
    if (_captureSession != nil) {
        _beginSessionConfigurationCount++;
        if (_beginSessionConfigurationCount == 1) {
            [_captureSession beginConfiguration];
        }
    }
}

- (void)commitConfiguration {
    if (_captureSession != nil) {
        _beginSessionConfigurationCount--;
        if (_beginSessionConfigurationCount == 0) {
            [_captureSession commitConfiguration];
        }
    }
}

- (BOOL)_reconfigureSession {
    NSError *newError = nil;
    
    AVCaptureSession *session = _captureSession;
    
    if (session != nil) {
        [self beginConfiguration];
        
        if (![session.sessionPreset isEqualToString:_captureSessionPreset]) {
            if ([session canSetSessionPreset:_captureSessionPreset]) {
                session.sessionPreset = _captureSessionPreset;
            } else {
                newError = [SCRecorder createError:@"Cannot set session preset"];
            }
        }
        
        if (self.fastRecordMethodEnabled) {
            if (_movieOutput == nil) {
                _movieOutput = [AVCaptureMovieFileOutput new];
            }
            
            if (_videoOutput != nil && [session.outputs containsObject:_videoOutput]) {
                [session removeOutput:_videoOutput];
            }
            
            if (_audioOutput != nil && [session.outputs containsObject:_audioOutput]) {
                [session removeOutput:_audioOutput];
            }
            
            if (![session.outputs containsObject:_movieOutput]) {
                if ([session canAddOutput:_movieOutput]) {
                    [session addOutput:_movieOutput];
                } else {
                    if (newError == nil) {
                        newError = [SCRecorder createError:@"Cannot add movieOutput inside the session"];
                    }
                }
            }
            
        } else {
            if (_movieOutput != nil && [session.outputs containsObject:_movieOutput]) {
                [session removeOutput:_movieOutput];
            }
            
            _videoOutputAdded = NO;
            if (self.videoConfiguration.enabled) {
                if (_videoOutput == nil) {
                    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
                    _videoOutput.alwaysDiscardsLateVideoFrames = NO;
                    [_videoOutput setSampleBufferDelegate:self queue:_sessionQueue];
                }
                
                if (![session.outputs containsObject:_videoOutput]) {
                    if ([session canAddOutput:_videoOutput]) {
                        [session addOutput:_videoOutput];
                        _videoOutputAdded = YES;
                    } else {
                        if (newError == nil) {
                            newError = [SCRecorder createError:@"Cannot add videoOutput inside the session"];
                        }
                    }
                } else {
                    _videoOutputAdded = YES;
                }
            }
            
            _audioOutputAdded = NO;
            if (self.audioConfiguration.enabled) {
                if (_audioOutput == nil) {
                    _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
                    [_audioOutput setSampleBufferDelegate:self queue:_sessionQueue];
                }
                
                if (![session.outputs containsObject:_audioOutput]) {
                    if ([session canAddOutput:_audioOutput]) {
                        [session addOutput:_audioOutput];
                        _audioOutputAdded = YES;
                    } else {
                        if (newError == nil) {
                            newError = [SCRecorder createError:@"Cannot add audioOutput inside the sesssion"];
                        }
                    }
                } else {
                    _audioOutputAdded = YES;
                }
            }
        }
        
        if (self.photoConfiguration.enabled) {
            if (_photoOutput == nil) {
                _photoOutput = [[AVCaptureStillImageOutput alloc] init];
                _photoOutput.outputSettings = [self.photoConfiguration createOutputSettings];
            }
            
            if (![session.outputs containsObject:_photoOutput]) {
                if ([session canAddOutput:_photoOutput]) {
                    [session addOutput:_photoOutput];
                } else {
                    if (newError == nil) {
                        newError = [SCRecorder createError:@"Cannot add photoOutput inside the session"];
                    }
                }
            }
        }
        
        [self commitConfiguration];
    }
    _error = newError;
    
    return newError == nil;
}

- (BOOL)prepare:(NSError **)error {
    if (_captureSession != nil) {
        [NSException raise:@"SCCameraException" format:@"The session is already opened"];
    }
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    _beginSessionConfigurationCount = 0;
    _captureSession = session;
    
    [self beginConfiguration];
    
    BOOL success = [self _reconfigureSession];
    
    if (!success && error != nil) {
        *error = _error;
    }
    
    _previewLayer.session = session;
    
    [self reconfigureVideoInput:YES audioInput:YES];
    
    [self commitConfiguration];
    
    return success;
}

- (BOOL)startRunning {
    BOOL success = YES;
    if (!self.isPrepared) {
        success = [self prepare:nil];
    }
    
    if (!_captureSession.isRunning) {
        [_captureSession startRunning];
    }
    
    return success;
}

- (void)stopRunning {
    [_captureSession stopRunning];
}

- (void)_subjectAreaDidChange {
    id<SCRecorderDelegate> delegate = self.delegate;
    
    if (![delegate respondsToSelector:@selector(recorderShouldAutomaticallyRefocus:)] || [delegate recorderShouldAutomaticallyRefocus:self]) {
        [self focusCenter];        
    }
}

- (UIImage *)_imageFromSampleBufferHolder:(SCSampleBufferHolder *)sampleBufferHolder {
    __block CMSampleBufferRef sampleBuffer = nil;
    dispatch_sync(_sessionQueue, ^{
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
    
    CGImageRef cgImage = [_context createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer))];
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    CFRelease(sampleBuffer);
    
    return image;
}

- (UIImage *)snapshotOfLastVideoBuffer {
    return [self _imageFromSampleBufferHolder:_lastVideoBuffer];
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

- (void)unprepare {
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
    [self _reconfigureSession];
}

- (void)_progressTimerFired:(NSTimer *)progressTimer {
    CMTime recordedDuration = _movieOutput.recordedDuration;
    
    if (CMTIME_COMPARE_INLINE(recordedDuration, !=, _lastMovieFileOutputTime)) {
        SCRecordSession *recordSession = _session;
        id<SCRecorderDelegate> delegate = self.delegate;
        
        if (recordSession != nil) {
            if ([delegate respondsToSelector:@selector(recorder:didAppendVideoSampleBufferInSession:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate recorder:self didAppendVideoSampleBufferInSession:recordSession];
                });
            }
            if ([delegate respondsToSelector:@selector(recorder:didAppendAudioSampleBufferInSession:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate recorder:self didAppendAudioSampleBufferInSession:_session];
                });
            }
        }
    }
    
    _lastMovieFileOutputTime = recordedDuration;
}

- (void)record {
    void (^block)() = ^{
        _isRecording = YES;
        if (_movieOutput != nil && _session != nil) {
            _movieOutput.maxRecordedDuration = self.maxRecordDuration;
            [self beginRecordSegmentIfNeeded:_session];
            if (_movieOutputProgressTimer == nil) {
                _movieOutputProgressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0 target:self selector:@selector(_progressTimerFired:) userInfo:nil repeats:YES];
            }
        }
    };
    
    if ([SCRecorder isSessionQueue]) {
        block();
    } else {
        dispatch_sync(_sessionQueue, block);
    }
}

- (void)pause {
    [self pause:nil];
}

- (void)pause:(void(^)())completionHandler {
    _isRecording = NO;
    
    void (^block)() = ^{
        SCRecordSession *recordSession = _session;
        
        if (recordSession != nil) {
            if (recordSession.recordSegmentReady) {
                NSDictionary *info = [self _createSegmentInfo];
                if (recordSession.isUsingMovieFileOutput) {
                    [_movieOutputProgressTimer invalidate];
                    _movieOutputProgressTimer = nil;
                    if ([recordSession endSegmentWithInfo:info completionHandler:nil]) {
                        _pauseCompletionHandler = completionHandler;
                    } else {
                        dispatch_handler(completionHandler);
                    }
                } else {
                    [recordSession endSegmentWithInfo:info completionHandler:^(SCRecordSessionSegment *segment, NSError *error) {
                        id<SCRecorderDelegate> delegate = self.delegate;
                        if ([delegate respondsToSelector:@selector(recorder:didCompleteSegment:inSession:error:)]) {
                            [delegate recorder:self didCompleteSegment:segment inSession:recordSession error:error];
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
    };
    
    if ([SCRecorder isSessionQueue]) {
        block();
    } else {
        dispatch_async(_sessionQueue, block);
    }
}

+ (NSError*)createError:(NSString*)errorDescription {
    return [NSError errorWithDomain:@"SCRecorder" code:200 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
}

- (void)beginRecordSegmentIfNeeded:(SCRecordSession *)recordSession {
    if (!recordSession.recordSegmentBegan) {
        NSError *error = nil;
        BOOL beginSegment = YES;
        if (_movieOutput != nil && self.fastRecordMethodEnabled) {
            if (recordSession.recordSegmentReady || !recordSession.isUsingMovieFileOutput) {
                [recordSession beginRecordSegmentUsingMovieFileOutput:_movieOutput error:&error delegate:self];
            } else {
                beginSegment = NO;
            }
        } else {
            [recordSession beginSegment:&error];
        }
        
        id<SCRecorderDelegate> delegate = self.delegate;
        if (beginSegment && [delegate respondsToSelector:@selector(recorder:didBeginSegmentInSession:error:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate recorder:self didBeginSegmentInSession:recordSession error:error];
            });
        }
    }
}

- (void)checkRecordSessionDuration:(SCRecordSession *)recordSession {
    CMTime currentRecordDuration = recordSession.duration;
    CMTime suggestedMaxRecordDuration = _maxRecordDuration;
    
    if (CMTIME_IS_VALID(suggestedMaxRecordDuration)) {
        if (CMTIME_COMPARE_INLINE(currentRecordDuration, >=, suggestedMaxRecordDuration)) {
            _isRecording = NO;
            
            dispatch_async(_sessionQueue, ^{
                [recordSession endSegmentWithInfo:[self _createSegmentInfo] completionHandler:^(SCRecordSessionSegment *segment, NSError *error) {
                    id<SCRecorderDelegate> delegate = self.delegate;
                    if ([delegate respondsToSelector:@selector(recorder:didCompleteSegment:inSession:error:)]) {
                        [delegate recorder:self didCompleteSegment:segment inSession:recordSession error:error];
                    }
                    
                    if ([delegate respondsToSelector:@selector(recorder:didCompleteSession:)]) {
                        [delegate recorder:self didCompleteSession:recordSession];
                    }
                }];
            });
        }
    }
}

- (CMTime)frameDurationFromConnection:(AVCaptureConnection *)connection {
    AVCaptureDevice *device = [self currentVideoDeviceInput].device;
    
    if ([device respondsToSelector:@selector(activeVideoMaxFrameDuration)]) {
        return device.activeVideoMinFrameDuration;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return connection.videoMinFrameDuration;
#pragma clang diagnostic pop
}

- (SCFilter *)_transformFilterUsingBufferWidth:(size_t)bufferWidth bufferHeight:(size_t)bufferHeight mirrored:(BOOL)mirrored {
    if (_transformFilter == nil || _transformFilterBufferWidth != bufferWidth || _transformFilterBufferHeight != bufferHeight) {
        BOOL shouldMirrorBuffer = _keepMirroringOnWrite && mirrored;
        
        if (!shouldMirrorBuffer) {
            _transformFilter = nil;
        } else {
            CGAffineTransform tx = CGAffineTransformIdentity;
            
            _transformFilter = [SCFilter filterWithAffineTransform:CGAffineTransformTranslate(CGAffineTransformScale(tx, -1, 1), -(CGFloat)bufferWidth, 0)];
        }
        
        _transformFilterBufferWidth = bufferWidth;
        _transformFilterBufferHeight = bufferHeight;
    }
    
    return _transformFilter;
}

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer toRecordSession:(SCRecordSession *)recordSession duration:(CMTime)duration connection:(AVCaptureConnection *)connection completion:(void(^)(BOOL success))completion {
    CVPixelBufferRef sampleBufferImage = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    size_t bufferWidth = (CGFloat)CVPixelBufferGetWidth(sampleBufferImage);
    size_t bufferHeight = (CGFloat)CVPixelBufferGetHeight(sampleBufferImage);
    
    CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    SCFilter *filterGroup = _videoConfiguration.filter;
    SCFilter *transformFilter = [self _transformFilterUsingBufferWidth:bufferWidth bufferHeight:bufferHeight mirrored:
                                 _device == AVCaptureDevicePositionFront
                                 ];
    
    if (filterGroup == nil && transformFilter == nil) {
        [recordSession appendVideoPixelBuffer:sampleBufferImage atTime:time duration:duration completion:completion];
        return;
    }
    
    CVPixelBufferRef pixelBuffer = [recordSession createPixelBuffer];
    
    if (pixelBuffer == nil) {
        completion(NO);
        return;
    }
    
    CIImage *image = [CIImage imageWithCVPixelBuffer:sampleBufferImage];
    CFTimeInterval seconds = CMTimeGetSeconds(time);
    
    if (transformFilter != nil) {
        image = [transformFilter imageByProcessingImage:image atTime:seconds];
    }
    
    if (filterGroup != nil) {
        image = [filterGroup imageByProcessingImage:image atTime:seconds];
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    [_context render:image toCVPixelBuffer:pixelBuffer];
    
    [recordSession appendVideoPixelBuffer:pixelBuffer atTime:time duration:duration completion:^(BOOL success) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        
        CVPixelBufferRelease(pixelBuffer);
        
        completion(success);
    }];
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections {
    dispatch_async(_sessionQueue, ^{
        [_session notifyMovieFileOutputIsReady];
        
        if (!_isRecording) {
            [self pause:_pauseCompletionHandler];
        }
    });
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    _isRecording = NO;
    
    dispatch_async(_sessionQueue, ^{
        BOOL hasComplete = NO;
        NSError *actualError = error;
        if ([actualError.localizedDescription isEqualToString:@"Recording Stopped"]) {
            actualError = nil;
            hasComplete = YES;
        }
        
        [_session appendRecordSegmentUrl:outputFileURL info:[self _createSegmentInfo] error:actualError completionHandler:^(SCRecordSessionSegment *segment, NSError *error) {
            void (^pauseCompletionHandler)() = _pauseCompletionHandler;
            _pauseCompletionHandler = nil;
            
            SCRecordSession *recordSession = _session;
            
            if (recordSession != nil) {
                id<SCRecorderDelegate> delegate = self.delegate;
                if ([delegate respondsToSelector:@selector(recorder:didCompleteSegment:inSession:error:)]) {
                    [delegate recorder:self didCompleteSegment:segment inSession:recordSession error:error];
                }
                
                if (hasComplete || (CMTIME_IS_VALID(_maxRecordDuration) && CMTIME_COMPARE_INLINE(recordSession.duration, >=, _maxRecordDuration))) {
                    if ([delegate respondsToSelector:@selector(recorder:didCompleteSession:)]) {
                        [delegate recorder:self didCompleteSession:recordSession];
                    }
                }
            }
            
            if (pauseCompletionHandler != nil) {
                pauseCompletionHandler();
            }
        }];
        
        if (_isRecording) {
            [self record];
        }
    });
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (captureOutput == _videoOutput) {
        if (_videoConfiguration.shouldIgnore) {
            return;
        }
        
        _lastVideoBuffer.sampleBuffer = sampleBuffer;
        SCImageView *imageRenderer = _SCImageView;
        if (imageRenderer != nil) {
            CFRetain(sampleBuffer);
            dispatch_async(dispatch_get_main_queue(), ^{
                [imageRenderer setImageBySampleBuffer:sampleBuffer];
                CFRelease(sampleBuffer);
            });
        }
    } else if (_audioConfiguration.shouldIgnore) {
        return;
    }
    
    if (_initializeSessionLazily && !_isRecording) {
        return;
    }
    
    _buffersWaitingToProcessCount++;
    if (_isRecording) {
        //        if (_buffersWaitingToProcessCount > 10) {
        //            NSLog(@"Warning: Reached %d waiting to process", _buffersWaitingToProcessCount);
        //        }
        //        NSLog(@"Waiting to process %d", _buffersWaitingToProcessCount);
    }
    
    SCRecordSession *recordSession = _session;
    
    if (!(_initializeSessionLazily && !_isRecording) && recordSession != nil) {
        if (recordSession != nil) {
            if (captureOutput == _videoOutput) {
                if (!recordSession.videoInitializationFailed && !_videoConfiguration.shouldIgnore) {
                    if (!recordSession.videoInitialized) {
                        NSError *error = nil;
                        NSDictionary *settings = [self.videoConfiguration createAssetWriterOptionsUsingSampleBuffer:sampleBuffer];
                        
                        CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
                        [recordSession initializeVideo:settings formatDescription:formatDescription error:&error];
                        
                        id<SCRecorderDelegate> delegate = self.delegate;
                        if ([delegate respondsToSelector:@selector(recorder:didInitializeVideoInSession:error:)]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [delegate recorder:self didInitializeVideoInSession:recordSession error:error];
                            });
                        }
                    }
                    
                    if (!self.audioEnabledAndReady || recordSession.audioInitialized || recordSession.audioInitializationFailed) {
                        [self beginRecordSegmentIfNeeded:recordSession];
                        
                        if (_isRecording && recordSession.recordSegmentReady) {
                            id<SCRecorderDelegate> delegate = self.delegate;
                            CMTime duration = [self frameDurationFromConnection:connection];
                            
                            double timeToWait = kMinTimeBetweenAppend - (CACurrentMediaTime() - _lastAppendedVideoTime);
                            
                            if (timeToWait > 0) {
                                // Letting some time to for the AVAssetWriter to be ready
                                //                                    NSLog(@"Too fast! Waiting %fs", timeToWait);
                                [NSThread sleepForTimeInterval:timeToWait];
                            }
                            
                            [self appendVideoSampleBuffer:sampleBuffer toRecordSession:recordSession duration:duration connection:connection completion:^(BOOL success) {
                                _lastAppendedVideoTime = CACurrentMediaTime();
                                if (success) {
                                    if ([delegate respondsToSelector:@selector(recorder:didAppendVideoSampleBufferInSession:)]) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [delegate recorder:self didAppendVideoSampleBufferInSession:recordSession];
                                        });
                                    }
                                    
                                    [self checkRecordSessionDuration:recordSession];
                                } else {
                                    if ([delegate respondsToSelector:@selector(recorder:didSkipVideoSampleBufferInSession:)]) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [delegate recorder:self didSkipVideoSampleBufferInSession:recordSession];
                                        });
                                    }
                                }
                            }];
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
                        if ([delegate respondsToSelector:@selector(recorder:didInitializeAudioInSession:error:)]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [delegate recorder:self didInitializeAudioInSession:recordSession error:error];
                            });
                        }
                    }
                    
                    if (!self.videoEnabledAndReady || recordSession.videoInitialized || recordSession.videoInitializationFailed) {
                        [self beginRecordSegmentIfNeeded:recordSession];
                        
                        if (_isRecording && recordSession.recordSegmentReady && (!self.videoEnabledAndReady || recordSession.currentSegmentHasVideo)) {
                            id<SCRecorderDelegate> delegate = self.delegate;
                            
                            [recordSession appendAudioSampleBuffer:sampleBuffer completion:^(BOOL success) {
                                if (success) {
                                    if ([delegate respondsToSelector:@selector(recorder:didAppendAudioSampleBufferInSession:)]) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [delegate recorder:self didAppendAudioSampleBufferInSession:recordSession];
                                        });
                                    }
                                    
                                    [self checkRecordSessionDuration:recordSession];
                                } else {
                                    if ([delegate respondsToSelector:@selector(recorder:didSkipAudioSampleBufferInSession:)]) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [delegate recorder:self didSkipAudioSampleBufferInSession:recordSession];
                                        });
                                    }
                                }
                            }];
                        }
                    }
                }
            }
        }
    }
    
    _buffersWaitingToProcessCount--;
    //        NSLog(@"End waiting to process %d", _buffersWaitingToProcessCount);
}

- (NSDictionary *)_createSegmentInfo {
    id<SCRecorderDelegate> delegate = self.delegate;
    NSDictionary *segmentInfo = nil;
    
    if ([delegate respondsToSelector:@selector(createSegmentInfoForRecorder:)]) {
        segmentInfo = [delegate createSegmentInfoForRecorder:self];
    }
    
    return segmentInfo;
}

- (void)_focusDidComplete {
    id<SCRecorderDelegate> delegate = self.delegate;

    [self setAdjustingFocus:NO];
    
    if ([delegate respondsToSelector:@selector(recorderDidEndFocus:)]) {
        [delegate recorderDidEndFocus:self];
    }
    
    if (_needsSwitchBackToContinuousFocus) {
        _needsSwitchBackToContinuousFocus = NO;
        [self continuousFocusAtPoint:self.focusPointOfInterest];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    id<SCRecorderDelegate> delegate = self.delegate;
    
    if (context == SCRecorderFocusContext) {
        BOOL isFocusing = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (isFocusing) {
            [self setAdjustingFocus:YES];
            
            if ([delegate respondsToSelector:@selector(recorderDidStartFocus:)]) {
                [delegate recorderDidStartFocus:self];
            }
        } else {
            [self _focusDidComplete];
        }
    } else if (context == SCRecorderExposureContext) {
        BOOL isAdjustingExposure = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        
        [self setAdjustingExposure:isAdjustingExposure];

        if (isAdjustingExposure) {
            if ([delegate respondsToSelector:@selector(recorderDidStartAdjustingExposure:)]) {
                [delegate recorderDidStartAdjustingExposure:self];
            }            
        } else {
            if ([delegate respondsToSelector:@selector(recorderDidEndAdjustingExposure:)]) {
                [delegate recorderDidEndAdjustingExposure:self];
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
    [videoDevice addObserver:self forKeyPath:@"adjustingExposure" options:NSKeyValueObservingOptionNew context:SCRecorderExposureContext];
}

- (void)removeVideoObservers:(AVCaptureDevice*)videoDevice {
    [videoDevice removeObserver:self forKeyPath:@"adjustingFocus"];
    [videoDevice removeObserver:self forKeyPath:@"adjustingExposure"];
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                                videoConnection.enablesVideoStabilizationWhenAvailable = YES;
#pragma clang diagnostic pop
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
        [self beginConfiguration];
        
        NSError *videoError = nil;
        if (shouldConfigureVideo) {
            [self configureDevice:[self videoDevice] mediaType:AVMediaTypeVideo error:&videoError];
            _transformFilter = nil;
            dispatch_sync(_sessionQueue, ^{
                [self updateVideoOrientation];
            });
        }
        
        NSError *audioError = nil;
        
        if (shouldConfigureAudio) {
            [self configureDevice:[self audioDevice] mediaType:AVMediaTypeAudio error:&audioError];
        }
        
        [self commitConfiguration];
        
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
    _previewLayer.affineTransform = CGAffineTransformIdentity;
    _previewLayer.frame = _previewView.bounds;
}

#pragma mark - FOCUS

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates {
    return [self.previewLayer captureDevicePointOfInterestForPoint:viewCoordinates];
}

- (CGPoint)convertPointOfInterestToViewCoordinates:(CGPoint)pointOfInterest {
    return [self.previewLayer pointForCaptureDevicePointOfInterest:pointOfInterest];
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

- (void)_applyPointOfInterest:(CGPoint)point continuousMode:(BOOL)continuousMode {
    AVCaptureDevice *device = [self.currentVideoDeviceInput device];
    AVCaptureFocusMode focusMode = continuousMode ? AVCaptureFocusModeContinuousAutoFocus : AVCaptureFocusModeAutoFocus;
    AVCaptureExposureMode exposureMode = continuousMode ? AVCaptureExposureModeContinuousAutoExposure : AVCaptureExposureModeAutoExpose;
    AVCaptureWhiteBalanceMode whiteBalanceMode = continuousMode ? AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance : AVCaptureWhiteBalanceModeAutoWhiteBalance;
    
    NSError *error;
    if ([device lockForConfiguration:&error]) {
        BOOL focusing = NO;
        BOOL adjustingExposure = NO;
        
        if (device.isFocusPointOfInterestSupported) {
            device.focusPointOfInterest = point;
        }
        if ([device isFocusModeSupported:focusMode]) {
            device.focusMode = focusMode;
            focusing = YES;
        }
        
        if (device.isExposurePointOfInterestSupported) {
            device.exposurePointOfInterest = point;
        }
        
        if ([device isExposureModeSupported:exposureMode]) {
            device.exposureMode = exposureMode;
            adjustingExposure = YES;
        }
        
        if ([device isWhiteBalanceModeSupported:whiteBalanceMode]) {
            device.whiteBalanceMode = whiteBalanceMode;
        }
        
        [device unlockForConfiguration];
        
        id<SCRecorderDelegate> delegate = self.delegate;
        if (focusMode != AVCaptureFocusModeContinuousAutoFocus && focusing) {
            if ([delegate respondsToSelector:@selector(recorderWillStartFocus:)]) {
                [delegate recorderWillStartFocus:self];
            }
            
            [self setAdjustingFocus:YES];
        }
        
        if (exposureMode != AVCaptureExposureModeContinuousAutoExposure && adjustingExposure) {
            [self setAdjustingExposure:YES];
            
            if ([delegate respondsToSelector:@selector(recorderWillStartAdjustingExposure:)]) {
                [delegate recorderWillStartAdjustingExposure:self];
            }
        }
    }
}

// Perform an auto focus at the specified point. The focus mode will automatically change to locked once the auto focus is complete.
- (void)autoFocusAtPoint:(CGPoint)point {
    [self _applyPointOfInterest:point continuousMode:NO];
}

// Switch to continuous auto focus mode at the specified point
- (void)continuousFocusAtPoint:(CGPoint)point {
    [self _applyPointOfInterest:point continuousMode:YES];
}

- (void)focusCenter {
    _needsSwitchBackToContinuousFocus = YES;
    [self autoFocusAtPoint:CGPointMake(0.5, 0.5)];
}

- (void)refocus {
    _needsSwitchBackToContinuousFocus = YES;
    [self autoFocusAtPoint:self.focusPointOfInterest];
}

- (CGPoint)exposurePointOfInterest {
    return [self.currentVideoDeviceInput device].exposurePointOfInterest;
}

- (BOOL)exposureSupported {
    return [self.currentVideoDeviceInput device].isExposurePointOfInterestSupported;
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
        [_previewView.layer insertSublayer:_previewLayer atIndex:0];
        
        [self previewViewFrameChanged];
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
    [self willChangeValueForKey:@"device"];
    
    _device = device;
    if (_resetZoomOnChangeDevice) {
        self.videoZoomFactor = 1;
    }
    if (_captureSession != nil) {
        [self reconfigureVideoInput:self.videoConfiguration.enabled audioInput:NO];
    }
    
    [self didChangeValueForKey:@"device"];
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

- (BOOL)isPrepared {
    return _captureSession != nil;
}

- (void)setCaptureSessionPreset:(NSString *)sessionPreset {
    _captureSessionPreset = sessionPreset;
    
    if (_captureSession != nil) {
        [self _reconfigureSession];
        _captureSessionPreset = _captureSession.sessionPreset;
    }
}

- (void)setVideoOrientation:(AVCaptureVideoOrientation)videoOrientation {
    _videoOrientation = videoOrientation;
    [self updateVideoOrientation];
}

- (void)setSession:(SCRecordSession *)recordSession {
    if (_session != recordSession) {
        dispatch_sync(_sessionQueue, ^{
            _session.recorder = nil;
            
            _session = recordSession;
            
            recordSession.recorder = self;
        });
    }
}

- (AVCaptureFocusMode)focusMode {
    return [self currentVideoDeviceInput].device.focusMode;
}

- (BOOL)isAdjustingFocus {
    return _adjustingFocus;
}

- (void)setAdjustingExposure:(BOOL)adjustingExposure {
    if (_isAdjustingExposure != adjustingExposure) {
        [self willChangeValueForKey:@"isAdjustingExposure"];
        
        _isAdjustingExposure = adjustingExposure;
        
        [self didChangeValueForKey:@"isAdjustingExposure"];
    }
}

- (void)setAdjustingFocus:(BOOL)adjustingFocus {
    if (_adjustingFocus != adjustingFocus) {
        [self willChangeValueForKey:@"isAdjustingFocus"];
        
        _adjustingFocus = adjustingFocus;
                
        [self didChangeValueForKey:@"isAdjustingFocus"];
    }
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            AVCaptureConnection *videoConnection = [self videoConnection];
            framerate = videoConnection.videoMaxFrameDuration.timescale;
#pragma clang diagnostic pop
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
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
#pragma clang diagnostic pop
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
        Float64 recordedTime = CMTimeGetSeconds(_session.duration);
        
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

- (void)setKeepMirroringOnWrite:(BOOL)keepMirroringOnWrite {
    dispatch_sync(_sessionQueue, ^{
        _keepMirroringOnWrite = keepMirroringOnWrite;
        _transformFilter = nil;
    });
}

- (CGFloat)videoZoomFactor {
    AVCaptureDevice *device = [self videoDevice];
    
    if ([device respondsToSelector:@selector(videoZoomFactor)]) {
        return device.videoZoomFactor;
    }
    
    return 1;
}

- (CGFloat)maxVideoZoomFactor {
    return [self maxVideoZoomFactorForDevice:_device];
}

- (CGFloat)maxVideoZoomFactorForDevice:(AVCaptureDevicePosition)devicePosition
{
    return [SCRecorderTools videoDeviceForPosition:devicePosition].activeFormat.videoMaxZoomFactor;
}

- (void)setVideoZoomFactor:(CGFloat)videoZoomFactor {
    AVCaptureDevice *device = [self videoDevice];
    
    if ([device respondsToSelector:@selector(videoZoomFactor)]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            if (videoZoomFactor <= device.activeFormat.videoMaxZoomFactor) {
                device.videoZoomFactor = videoZoomFactor;
            } else {
                NSLog(@"Unable to set videoZoom: (max %f, asked %f)", device.activeFormat.videoMaxZoomFactor, videoZoomFactor);
            }
            
            [device unlockForConfiguration];
        } else {
            NSLog(@"Unable to set videoZoom: %@", error.localizedDescription);
        }
    }
}

- (void)setFastRecordMethodEnabled:(BOOL)fastRecordMethodEnabled {
    if (_fastRecordMethodEnabled != fastRecordMethodEnabled) {
        _fastRecordMethodEnabled = fastRecordMethodEnabled;
        
        [self _reconfigureSession];
    }
}

+ (SCRecorder *)sharedRecorder {
    static SCRecorder *_sharedRecorder = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedRecorder = [SCRecorder new];
    });
    
    return _sharedRecorder;
}

+ (BOOL)isSessionQueue {
    return dispatch_get_specific(kSCRecorderRecordSessionQueueKey) != nil;
}

@end
