//
//  SCAssetExportSession.m
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCAssetExportSession.h"

#define EnsureSuccess(error, x) if (error != nil) { _error = error; if (x != nil) x(); return; }
#define kVideoPixelFormatTypeForCI kCVPixelFormatType_32BGRA
#define kVideoPixelFormatTypeDefault kCVPixelFormatType_422YpCbCr8
#define kAudioFormatType kAudioFormatLinearPCM
#define k *1000.0

@interface SCAssetExportSession() {
    AVAssetWriter *_writer;
    AVAssetReader *_reader;
    AVAssetReaderOutput *_audioOutput;
    AVAssetReaderOutput *_videoOutput;
    AVAssetWriterInput *_audioInput;
    AVAssetWriterInput *_videoInput;
    AVAssetWriterInputPixelBufferAdaptor *_videoPixelAdaptor;
    NSError *_error;
    dispatch_queue_t _dispatchQueue;
    dispatch_group_t _dispatchGroup;
    EAGLContext *_eaglContext;
    CIContext *_ciContext;
    BOOL _animationsWereEnabled;
    uint32_t _pixelFormat;
    CMTime _nextAllowedVideoFrame;
}

@end

const NSString *SCAssetExportSessionPresetHighestQuality = @"HighestQuality";
const NSString *SCAssetExportSessionPresetMediumQuality = @"MediumQuality";
const NSString *SCAssetExportSessionPresetLowQuality = @"LowQuality";

@implementation SCAssetExportSession

-(id)init {
    self = [super init];
    
    if (self) {
        _dispatchQueue = dispatch_queue_create("me.corsin.EvAssetExportSession", nil);
        _dispatchGroup = dispatch_group_create();
        _useGPUForRenderingFilters = YES;
        _keepVideoTransform = YES;
        _videoTransform = CGAffineTransformIdentity;
        _maxVideoFrameDuration = kCMTimeInvalid;
    }
    
    return self;
}

- (id)initWithAsset:(AVAsset *)inputAsset {
    self = [self init];
    
    if (self) {
        self.inputAsset = inputAsset;
    }
    
    return self;
}

- (AVAssetReaderOutput *)addReader:(AVAssetTrack *)track  withSettings:(NSDictionary*)outputSettings {
    AVAssetReaderOutput *reader = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:outputSettings];
    
    if ([_reader canAddOutput:reader]) {
        [_reader addOutput:reader];
    } else {
        NSLog(@"Cannot add input reader %d", kAudioFormatMPEG4AAC);
        reader = nil;
    }
    
    return reader;
}

- (AVAssetWriterInput *)addWriter:(NSString *)mediaType withSettings:(NSDictionary *)outputSettings {
    AVAssetWriterInput *writer = [AVAssetWriterInput assetWriterInputWithMediaType:mediaType outputSettings:outputSettings];
    
    if ([_writer canAddInput:writer]) {
        [_writer addInput:writer];
    }
    
    return writer;
}

- (void)processPixelBuffer:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)presentationTime {
    if (![_videoPixelAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:presentationTime]) {
        NSLog(@"Failed to append to pixel buffer");
    }
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (_ciContext != nil) {
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        if (_eaglContext == nil) {
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        }
        
        CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        CIImage *result = [_filterGroup imageByProcessingImage:image];

        CVPixelBufferRef outputPixelBuffer = nil;
        CVPixelBufferPoolCreatePixelBuffer(NULL, [_videoPixelAdaptor pixelBufferPool], &outputPixelBuffer);
        
        CVPixelBufferLockBaseAddress(outputPixelBuffer, 0);
        
        [_ciContext render:result toCVPixelBuffer:outputPixelBuffer];
        
        [self processPixelBuffer:outputPixelBuffer presentationTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
        
        CVPixelBufferUnlockBaseAddress(outputPixelBuffer, 0);
        
        if (_eaglContext == nil) {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        }
        
        CVPixelBufferRelease(outputPixelBuffer);
        outputPixelBuffer = nil;
    } else {
        [_videoInput appendSampleBuffer:sampleBuffer];
    }
}

- (void)markInputComplete:(AVAssetWriterInput *)input error:(NSError *)error {
    if (_reader.status == AVAssetReaderStatusFailed) {
        _error = _reader.error;
    } else if (error != nil) {
        _error = error;
    }
    
    [input markAsFinished];
}

- (void)beginReadWriteOnInput:(AVAssetWriterInput *)input fromOutput:(AVAssetReaderOutput *)output {
    if (input != nil) {
        dispatch_group_enter(_dispatchGroup);
        [input requestMediaDataWhenReadyOnQueue:_dispatchQueue usingBlock:^{
            while (input.isReadyForMoreMediaData) {
                CMSampleBufferRef buffer = [output copyNextSampleBuffer];
                
                if (buffer != nil) {
                    if (input == _videoInput) {
                        CMTime currentVideoTime = CMSampleBufferGetPresentationTimeStamp(buffer);
                        if (CMTIME_COMPARE_INLINE(currentVideoTime, >=, _nextAllowedVideoFrame)) {
                            [self processSampleBuffer:buffer];
                            
                            if (CMTIME_IS_VALID(_maxVideoFrameDuration)) {
                                _nextAllowedVideoFrame = CMTimeAdd(currentVideoTime, _maxVideoFrameDuration);
                            }
                        }
                    } else {
                        [input appendSampleBuffer:buffer];
                    }
                    
                    CFRelease(buffer);
                } else {
                    [self markInputComplete:input error:nil];
                    
                    dispatch_group_leave(_dispatchGroup);
                    break;
                }
            }
        }];
    }
}

- (void)callCompletionHandler:(void (^)())completionHandler {
    if (completionHandler != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler();
        });
    }
}

- (void)setupCoreImage:(AVAssetTrack *)videoTrack {
    if ([self needsCIContext] && _videoInput != nil) {
        if (self.useGPUForRenderingFilters) {
            _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        }
        
        if (_eaglContext == nil) {
            NSDictionary *options = @{
                                      kCIContextUseSoftwareRenderer : [NSNumber numberWithBool:YES]
                                       };
            _ciContext = [CIContext contextWithOptions:options];
        } else {
            _ciContext = [CIContext contextWithEAGLContext:_eaglContext options:nil];
        }
        
    } else {
        _ciContext = nil;
        _eaglContext = nil;
    }
}

- (BOOL)needsInputPixelBufferAdaptor {
    return _ciContext != nil;
}

+ (NSError*)createError:(NSString*)errorDescription {
    return [NSError errorWithDomain:@"SCAssetExportSession" code:200 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
}

- (void)setupSettings:(AVAssetTrack *)videoTrack error:(NSError **)error {
    if (_sessionPreset != nil) {
        int sampleRate = 0;
        int audioBitrate = 0;
        int channels = 0;
        double width = 0;
        double height = 0;
        double videoBitrate = 0;
        
        if (videoTrack != nil && _keepVideoSize) {
            width = videoTrack.naturalSize.width;
            height = videoTrack.naturalSize.height;
        }
        
        // Because Yoda was my master
        if ([SCAssetExportSessionPresetHighestQuality isEqualToString:_sessionPreset]) {
            sampleRate = 44100;
            audioBitrate = 256 k;
            channels = 2;
            
            if (!_keepVideoSize) {
                width = 1920;
                height = 1080;
            }
            
            videoBitrate = width * height * 4;
        } else if ([SCAssetExportSessionPresetMediumQuality isEqualToString:_sessionPreset]) {
            sampleRate = 44100;
            audioBitrate = 128 k;
            channels = 2;
            
            if (!_keepVideoSize) {
                width = 1280;
                height = 720;
            }
            
            videoBitrate = width * height;
        } else if ([SCAssetExportSessionPresetLowQuality isEqualToString:_sessionPreset]) {
            sampleRate = 44100;
            audioBitrate = 64 k;
            channels = 1;
            
            if (!_keepVideoSize) {
                width = 640;
                height = 480;
            }
            
            videoBitrate = width * height / 2;
        } else {
            *error = [SCAssetExportSession createError:@"Unrecognized export preset"];
            return;
        }
        
        if (_audioSettings == nil) {
            _audioSettings = @{
                               AVFormatIDKey : [NSNumber numberWithInt:kAudioFormatMPEG4AAC],
                               AVSampleRateKey : [NSNumber numberWithInt:sampleRate],
                               AVEncoderBitRateKey : [NSNumber numberWithInt:audioBitrate],
                               AVNumberOfChannelsKey : [NSNumber numberWithInt:channels]
                               };

        }
        if (_videoSettings == nil) {
            _videoSettings = @{
                               AVVideoCodecKey : AVVideoCodecH264,
                               AVVideoWidthKey : [NSNumber numberWithDouble:width],
                               AVVideoHeightKey : [NSNumber numberWithDouble:height],
                               AVVideoCompressionPropertiesKey : @{AVVideoAverageBitRateKey: [NSNumber numberWithDouble:videoBitrate ]}
                               };
        }
    }
}

- (BOOL)needsCIContext {
    return _filterGroup.filters.count > 0;
}

- (void)setupPixelBufferAdaptor:(AVAssetTrack *)videoTrack {
    if ([self needsInputPixelBufferAdaptor] && _videoInput != nil) {
        CGSize videoSize = videoTrack.naturalSize;
        NSDictionary *pixelBufferAttributes = @{
                                                (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:_pixelFormat],
                                                (id)kCVPixelBufferWidthKey : [NSNumber numberWithFloat:videoSize.width],
                                                (id)kCVPixelBufferHeightKey : [NSNumber numberWithFloat:videoSize.height]
                                                };
        
        _videoPixelAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoInput sourcePixelBufferAttributes:pixelBufferAttributes];
    }
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)())completionHandler {
    _nextAllowedVideoFrame = kCMTimeZero;
    NSError *error = nil;
    
    [[NSFileManager defaultManager] removeItemAtURL:self.outputUrl error:nil];
    
    _writer = [AVAssetWriter assetWriterWithURL:self.outputUrl fileType:self.outputFileType error:&error];

    EnsureSuccess(error, completionHandler);
    
    _reader = [AVAssetReader assetReaderWithAsset:self.inputAsset error:&error];
    EnsureSuccess(error, completionHandler);
    
    NSArray *audioTracks = [self.inputAsset tracksWithMediaType:AVMediaTypeAudio];
    if (audioTracks.count > 0 && !self.ignoreAudio) {
        _audioOutput = [self addReader:[audioTracks objectAtIndex:0] withSettings:@{ AVFormatIDKey : [NSNumber numberWithUnsignedInt:kAudioFormatType] }];
    } else {
        _audioOutput = nil;
    }
    
    NSArray *videoTracks = [self.inputAsset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack = nil;
    if (videoTracks.count > 0 && !self.ignoreVideo) {
        videoTrack = [videoTracks objectAtIndex:0];
        
        _pixelFormat = [self needsCIContext] ? kVideoPixelFormatTypeForCI : kVideoPixelFormatTypeDefault;
        _videoOutput = [self addReader:videoTrack withSettings:@{
                                                                 (id)kCVPixelBufferPixelFormatTypeKey     : [NSNumber numberWithUnsignedInt:_pixelFormat],
                                                                 (id)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary]
                                                                 }];
    } else {
        _videoOutput = nil;
    }
    
    [self setupSettings:videoTrack error:&error];
    
    EnsureSuccess(error, completionHandler);
    
    if (_audioOutput != nil) {
        _audioInput = [self addWriter:AVMediaTypeAudio withSettings:self.audioSettings];
    } else {
        _audioInput = nil;
    }
    
    if (_videoOutput != nil) {
        _videoInput = [self addWriter:AVMediaTypeVideo withSettings:self.videoSettings];
        if (_keepVideoTransform) {
            _videoInput.transform = videoTrack.preferredTransform;
        } else {
            _videoInput.transform = self.videoTransform;
        }
    } else {
        _videoInput = nil;
    }
    
    [self setupCoreImage:videoTrack];
    
    [self setupPixelBufferAdaptor:videoTrack];
    
    if (![_reader startReading]) {
        EnsureSuccess(_reader.error, completionHandler);
    }
    
    if (![_writer startWriting]) {
        EnsureSuccess(_writer.error, completionHandler);
    }
    
    [_writer startSessionAtSourceTime:kCMTimeZero];
    
    [self beginReadWriteOnInput:_videoInput fromOutput:_videoOutput];
    [self beginReadWriteOnInput:_audioInput fromOutput:_audioOutput];
    
    dispatch_group_notify(_dispatchGroup, _dispatchQueue, ^{
        if (_error == nil) {
            [_writer finishWritingWithCompletionHandler:^{
                _error = _writer.error;
                [self callCompletionHandler:completionHandler];
            }];
        } else {
            [self callCompletionHandler:completionHandler];
        }
    });
}

- (NSError *)error {
    return _error;
}

- (dispatch_queue_t)dispatchQueue {
    return _dispatchQueue;
}

- (dispatch_group_t)dispatchGroup {
    return _dispatchGroup;
}

- (AVAssetWriterInput *)videoInput {
    return _videoInput;
}

- (AVAssetWriterInput *)audioInput {
    return _audioInput;
}

- (AVAssetReader *)reader {
    return _reader;
}

@end
