//
//  SCNewCamera.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 27/03/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#include <sys/sysctl.h>
#import "SCRecorder.h"

unsigned int SCGetCoreCount()
{
    size_t len;
    unsigned int ncpu;
    
    len = sizeof(ncpu);
    sysctlbyname ("hw.ncpu",&ncpu,&len,NULL,0);
    
    return ncpu;
}

@interface SCRecorder() {
    AVCaptureVideoPreviewLayer *_previewLayer;
    AVCaptureSession *_captureSession;
    UIView *_previewView;
    AVCaptureVideoDataOutput *_videoOutput;
    AVCaptureAudioDataOutput *_audioOutput;
    AVCaptureStillImageOutput *_photoOutput;
    NSMutableArray *_recordSessions;
    dispatch_queue_t _dispatchQueue;
    BOOL _usingMainQueue;
}

@end

@implementation SCRecorder

- (id)init {
    self = [super init];
    
    if (self) {
        // No need to create a different dispatch_queue if
        // the current running phone has only one core
        if (SCGetCoreCount() == 1) {
            _dispatchQueue = dispatch_get_main_queue();
            _usingMainQueue = YES;
        } else {
            _dispatchQueue = dispatch_queue_create("SCVideoRecorder", nil);
            _usingMainQueue = NO;
        }
        
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] init];
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        
        _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_videoOutput setSampleBufferDelegate:self queue:_dispatchQueue];
        
        _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
        [_audioOutput setSampleBufferDelegate:self queue:_dispatchQueue];
     
        _photoOutput = [[AVCaptureStillImageOutput alloc] init];
        _photoOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
        
        _recordSessions = [NSMutableArray array];
        
        self.device = SCCameraDeviceBack;
        self.videoEnabled = YES;
        self.audioEnabled = YES;
        self.photoEnabled = YES;
    }
    
    return self;
}

- (void)dealloc {
    [self closeSession];
}

+ (SCRecorder*)recorder {
    return [[SCRecorder alloc] init];
}

- (void)openSession:(void(^)(NSError *sessionError, NSError * audioError, NSError * videoError, NSError *photoError))completionHandler {
    if (_captureSession != nil) {
        [NSException raise:@"SCCameraException" format:@"The session is already opened"];
    }
    
    NSError *sessionError = nil;
    NSError *audioError = nil;
    NSError *videoError = nil;
    NSError *photoError = nil;
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    [session beginConfiguration];
    
    if ([session canSetSessionPreset:self.sessionPreset]) {
        session.sessionPreset = self.sessionPreset;
    } else {
        sessionError = [SCRecorder createError:@"Cannot set session preset"];
    }
    
    if (_videoEnabled) {
        if ([session canAddOutput:_videoOutput]) {
            [session addOutput:_videoOutput];
        } else {
            videoError = [SCRecorder createError:@"Cannot add videoOutput inside the session"];
        }
    }
    if (_audioEnabled) {
        if ([session canAddOutput:_audioOutput]) {
            [session addOutput:_audioOutput];
        } else {
            audioError = [SCRecorder createError:@"Cannot add audioOutput inside the sesssion"];
        }
    }
    if (_photoEnabled) {
        if ([session canAddOutput:_photoOutput]) {
            [session addOutput:_photoOutput];
        } else {
            photoError = [SCRecorder createError:@"Cannot add photoOutput inside the session"];
        }
    }

    
    _previewLayer.session = session;
    _captureSession = session;
    
    [self reconfigureInputs];
    
    [session commitConfiguration];
    
    if (completionHandler != nil) {
        completionHandler(nil, audioError, videoError, photoError);
    }
}

- (void)startRunningSession:(void (^)())completionHandler {
    if (_captureSession == nil) {
        [NSException raise:@"SCCamera" format:@"Session was not opened before"];
    }
    
    if (!_captureSession.isRunning) {
        dispatch_async(_dispatchQueue, ^{
            [_captureSession startRunning];
            
            if (completionHandler != nil) {
                completionHandler();
            }
        });
    } else {
        if (completionHandler != nil) {
            completionHandler();
        }
    }
}

- (void)endRunningSession {
    [_captureSession stopRunning];
}

- (void)closeSession {
    if (_captureSession != nil) {
        for (AVCaptureDeviceInput *input in _captureSession.inputs) {
            [_captureSession removeInput:input];
        }
        for (AVCaptureOutput *output in _captureSession.outputs) {
            [_captureSession removeOutput:output];
        }
        
        _previewLayer.session = nil;
        _captureSession = nil;
    }
}

- (void)addRecordSession:(SCRecordSession *)recordSession {
    if (recordSession == nil) {
        [NSException raise:@"SCRecorder" format:@"recordSession cannot be nil"];
    }
    
    [recordSession makeTimeOffsetDirty];
    dispatch_async(_dispatchQueue, ^{
        [_recordSessions addObject:recordSession];
    });
}

- (void)removeRecordSession:(SCRecordSession *)recordSession {
    dispatch_async(_dispatchQueue, ^{
        [_recordSessions removeObject:recordSession];
    });
}

- (void)record {
    dispatch_async(_dispatchQueue, ^{
        _isRecording = YES;
    });
}

- (void)pause {
    dispatch_async(_dispatchQueue, ^{
        _isRecording = NO;
        for (SCRecordSession *recordSession in _recordSessions) {
            if (recordSession.shouldTrackRecordSegments) {
                [recordSession endRecordSegment:^(NSInteger segmentIndex, NSError *error) {
                    id<SCRecorderDelegate> delegate = self.delegate;
                    if ([delegate respondsToSelector:@selector(recorder:didEndRecordSegment:segmentIndex:error:)]) {
                        [delegate recorder:self didEndRecordSegment:recordSession segmentIndex:segmentIndex error:error];
                    }
                }];
            } else {
                [recordSession makeTimeOffsetDirty];
            }
        }
    });
}

+ (NSError*)createError:(NSString*)errorDescription {
    return [NSError errorWithDomain:@"SCRecorder" code:200 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
}

- (NSString*)suggestedFileType:(SCRecordSession *)recordSession {
    if (self.videoEnabled && !recordSession.shouldIgnoreVideo) {
        return AVFileTypeMPEG4;
    } else if (self.audioEnabled && !recordSession.shouldIgnoreAudio) {
        return AVFileTypeAppleM4A;
    }
    
    return nil;
}

- (void)beginRecordSegmentIfNeeded:(SCRecordSession *)recordSession {
    if (!recordSession.recordSegmentBegan) {
        NSError *error = nil;
        [recordSession beginRecordSegment:&error];
        
        id<SCRecorderDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(recorder:didBeginRecordSegment:error:)]) {
            [delegate recorder:self didBeginRecordSegment:recordSession error:error];
        }
    }
}

- (void)checkRecordSessionDuration:(SCRecordSession *)recordSession {
    CMTime currentRecordDuration = recordSession.currentRecordDuration;
    CMTime suggestedMaxRecordDuration = recordSession.suggestedMaxRecordDuration;
    
    if (CMTIME_IS_VALID(suggestedMaxRecordDuration)) {
        if (CMTIME_COMPARE_INLINE(currentRecordDuration, >=, suggestedMaxRecordDuration)) {
            [self removeRecordSession:recordSession];
            
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

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    for (SCRecordSession *recordSession in _recordSessions) {
        if (captureOutput == _videoOutput) {
            if (!recordSession.videoInitializationFailed && !recordSession.shouldIgnoreVideo) {
                if (!recordSession.videoInitialized) {
                    NSError *error = nil;
                    [recordSession initializeVideoUsingSampleBuffer:sampleBuffer suggestedFileType:[self suggestedFileType:recordSession] error:&error];
                    
                    id<SCRecorderDelegate> delegate = self.delegate;
                    if ([delegate respondsToSelector:@selector(recorder:didInitializeVideoInRecordSession:error:)]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [delegate recorder:self didInitializeVideoInRecordSession:recordSession error:error];
                        });
                    }
                }
                
                
                if (!_audioEnabled || recordSession.audioInitialized) {
                    [self beginRecordSegmentIfNeeded:recordSession];
                    
                    if (_isRecording) {
                        [recordSession appendVideoSampleBuffer:sampleBuffer];
                        
                        id<SCRecorderDelegate> delegate = self.delegate;
                        if ([delegate respondsToSelector:@selector(recorder:didAppendVideoSampleBuffer:)]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [delegate recorder:self didAppendVideoSampleBuffer:recordSession];
                            });
                        }
                        
                        [self checkRecordSessionDuration:recordSession];
                    }
                }
            }
        } else if (captureOutput == _audioOutput) {
            if (!recordSession.audioInitializationFailed && !recordSession.shouldIgnoreAudio) {
                if (!recordSession.audioInitialized) {
                    NSError * error = nil;
                    [recordSession initializeAudioUsingSampleBuffer:sampleBuffer suggestedFileType:[self suggestedFileType:recordSession] error:&error];
                    
                    id<SCRecorderDelegate> delegate = self.delegate;
                    if ([delegate respondsToSelector:@selector(recorder:didInitializeAudioInRecordSession:error:)]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [delegate recorder:self didInitializeAudioInRecordSession:recordSession error:error];
                        });
                    }
                }
                
                if (!_videoEnabled || recordSession.videoInitialized) {
                    [self beginRecordSegmentIfNeeded:recordSession];
                    
                    if (_isRecording) {
                        [recordSession appendAudioSampleBuffer:sampleBuffer];
                        
                        id<SCRecorderDelegate> delegate = self.delegate;
                        if ([delegate respondsToSelector:@selector(recorder:didAppendAudioSampleBuffer:)]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [delegate recorder:self didAppendAudioSampleBuffer:recordSession];
                            });
                        }
                        
                        [self checkRecordSessionDuration:recordSession];
                    }
                }
            }
        }
    }
}

- (void)configureDevice:(AVCaptureDevice*)newDevice mediaType:(NSString*)mediaType error:(NSError**)error {
    AVCaptureDeviceInput *currentInput = [self currentDeviceInputForMediaType:mediaType];
    AVCaptureDevice *currentUsedDevice = currentInput.device;
    
    if (currentUsedDevice != newDevice) {
        AVCaptureDeviceInput *newInput = [[AVCaptureDeviceInput alloc] initWithDevice:newDevice error:error];
        
        if (*error == nil) {
            if (currentInput != nil) {
                [_captureSession removeInput:currentInput];
            }
            
            if ([_captureSession canAddInput:newInput]) {
                [_captureSession addInput:newInput];
            } else {
                *error = [SCRecorder createError:@"Failed to add input to capture session"];
            }
        }
    }
}

- (void)reconfigureInputs {
    NSError *videoError = nil;
    [self configureDevice:[self videoDevice] mediaType:AVMediaTypeVideo error:&videoError];
    
    NSError *audioError = nil;
    [self configureDevice:[self audioDevice] mediaType:AVMediaTypeAudio error:&audioError];
    
    id<SCRecorderDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(recorder:didReconfigureInputs:audioInputError:)]) {
        [delegate recorder:self didReconfigureInputs:videoError audioInputError:audioError];
    }
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
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
}

- (AVCaptureDevice*)videoDevice {
	NSArray * videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	
	for (AVCaptureDevice * device in videoDevices) {
		if (device.position == (AVCaptureDevicePosition)_device) {
			return device;
		}
	}
	
	return nil;
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

- (void)setDevice:(SCCameraDevice)device {
    _device = device;
    if (_captureSession != nil) {
        [self reconfigureInputs];
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

- (NSArray*)recordSessions {
    return _recordSessions;
}

@end
