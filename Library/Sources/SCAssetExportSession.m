//
//  SCAssetExportSession.m
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCAssetExportSession.h"
#import "SCRecorderTools.h"
#import "SCProcessingQueue.h"
#import "SCSampleBufferHolder.h"
#import "SCIOPixelBuffers.h"

#define EnsureSuccess(error, x) if (error != nil) { _error = error; if (x != nil) x(); return; }
#define kAudioFormatType kAudioFormatLinearPCM

@interface SCAssetExportSession() {
    AVAssetWriter *_writer;
    AVAssetReader *_reader;
    AVAssetReaderOutput *_audioOutput;
    AVAssetReaderOutput *_videoOutput;
    AVAssetWriterInput *_audioInput;
    AVAssetWriterInput *_videoInput;
    AVAssetWriterInputPixelBufferAdaptor *_videoPixelAdaptor;
    NSError *_error;
    dispatch_queue_t _audioQueue;
    dispatch_queue_t _videoQueue;
    dispatch_group_t _dispatchGroup;
    EAGLContext *_eaglContext;
    CIContext *_ciContext;
    BOOL _animationsWereEnabled;
    CMTime _nextAllowedVideoFrame;
    Float64 _totalDuration;
    SCFilter *_watermarkFilter;
    CGSize _outputBufferSize;
    BOOL _outputBufferDiffersFromInput;
}

@end

@implementation SCAssetExportSession

-(id)init {
    self = [super init];
    
    if (self) {
        _audioQueue = dispatch_queue_create("me.corsin.SCAssetExportSession.AudioQueue", nil);
        _videoQueue = dispatch_queue_create("me.corsin.SCAssetExportSession.VideoQueue", nil);
        _dispatchGroup = dispatch_group_create();
        _useGPUForRenderingFilters = YES;
        _audioConfiguration = [SCAudioConfiguration new];
        _videoConfiguration = [SCVideoConfiguration new];
        _timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
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

- (AVAssetWriterInput *)addWriter:(NSString *)mediaType withSettings:(NSDictionary *)outputSettings {
    AVAssetWriterInput *writer = [AVAssetWriterInput assetWriterInputWithMediaType:mediaType outputSettings:outputSettings];
    
    if ([_writer canAddInput:writer]) {
        [_writer addInput:writer];
    }
    
    return writer;
}

- (BOOL)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)presentationTime {
    return [_videoPixelAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:presentationTime];
}

- (SCIOPixelBuffers *)createIOPixelBuffers:(CMSampleBufferRef)sampleBuffer {
    CVPixelBufferRef inputPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    if (_outputBufferDiffersFromInput) {
        CVPixelBufferRef outputPixelBuffer = nil;
        
        CVReturn ret = CVPixelBufferPoolCreatePixelBuffer(nil, _videoPixelAdaptor.pixelBufferPool, &outputPixelBuffer);
        
        if (ret != kCVReturnSuccess) {
            NSLog(@"Unable to allocate pixelBuffer: %d", ret);
            return nil;
        }
        
        SCIOPixelBuffers *pixelBuffers = [SCIOPixelBuffers IOPixelBuffersWithInputPixelBuffer:inputPixelBuffer outputPixelBuffer:outputPixelBuffer time:time];
        CVPixelBufferRelease(outputPixelBuffer);
        
        return pixelBuffers;
    } else {
        return [SCIOPixelBuffers IOPixelBuffersWithInputPixelBuffer:inputPixelBuffer outputPixelBuffer:inputPixelBuffer time:time];
    }
}

- (SCIOPixelBuffers *)renderIOPixelBuffersWithCI:(SCIOPixelBuffers *)pixelBuffers {
    SCIOPixelBuffers *outputPixelBuffers = pixelBuffers;
    
    if (_ciContext != nil) {
        CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuffers.inputPixelBuffer];
        
        CIImage *result = image;
        NSTimeInterval timeSeconds = CMTimeGetSeconds(pixelBuffers.time);
        
        if (_videoConfiguration.filter != nil) {
            result = [_videoConfiguration.filter imageByProcessingImage:result atTime:timeSeconds];
        }
        
        if (_watermarkFilter != nil) {
            [_watermarkFilter setParameterValue:result forKey:kCIInputBackgroundImageKey];
            result = [_watermarkFilter parameterValueForKey:kCIOutputImageKey];
        }
        
        if (!CGSizeEqualToSize(result.extent.size, _outputBufferSize)) {
            result = [result imageByCroppingToRect:CGRectMake(0, 0, _outputBufferSize.width, _outputBufferSize.height)];
        }
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        [_ciContext render:result toCVPixelBuffer:pixelBuffers.outputPixelBuffer bounds:result.extent colorSpace:colorSpace];
        
        CGColorSpaceRelease(colorSpace);
        
        if (pixelBuffers.inputPixelBuffer != pixelBuffers.outputPixelBuffer) {
            CVPixelBufferUnlockBaseAddress(pixelBuffers.inputPixelBuffer, 0);
        }
        
        outputPixelBuffers = [SCIOPixelBuffers IOPixelBuffersWithInputPixelBuffer:pixelBuffers.outputPixelBuffer outputPixelBuffer:pixelBuffers.outputPixelBuffer time:pixelBuffers.time];
    }
    
    return outputPixelBuffers;
}

- (void)CGRenderWithInputPixelBuffer:(CVPixelBufferRef)inputPixelBuffer toOutputPixelBuffer:(CVPixelBufferRef)outputPixelBuffer atTimeInterval:(NSTimeInterval)timeSeconds {
    UIView<SCVideoOverlay> *overlay = self.videoConfiguration.overlay;
    
    if (overlay != nil) {
        if ([overlay respondsToSelector:@selector(updateWithVideoTime:)]) {
            [overlay updateWithVideoTime:timeSeconds];
        }
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        CGContextRef ctx = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(outputPixelBuffer), CVPixelBufferGetWidth(outputPixelBuffer), CVPixelBufferGetHeight(outputPixelBuffer), 8, CVPixelBufferGetBytesPerRow(outputPixelBuffer), colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);
        
        CGColorSpaceRelease(colorSpace);
        
        CGContextTranslateCTM(ctx, 1, CGBitmapContextGetHeight(ctx));
        CGContextScaleCTM(ctx, 1, -1);
        
        overlay.frame = CGRectMake(0, 0, CVPixelBufferGetWidth(outputPixelBuffer), CVPixelBufferGetHeight(outputPixelBuffer));
        [overlay layoutIfNeeded];
        
        [overlay.layer renderInContext:ctx];
        
        CGContextRelease(ctx);
    };
}

- (void)markInputComplete:(AVAssetWriterInput *)input error:(NSError *)error {
    if (_reader.status == AVAssetReaderStatusFailed) {
        _error = _reader.error;
    } else if (error != nil) {
        _error = error;
    }
    
    [input markAsFinished];
}

- (void)_didAppendToInput:(AVAssetWriterInput *)input atTime:(CMTime)time {
    if (input == _videoInput || _videoInput == nil) {
        float progress = CMTimeGetSeconds(time) / _totalDuration;
        [self _setProgress:progress];
    }
}

- (void)beginReadWriteOnVideo {
    if (_videoInput != nil) {
        SCProcessingQueue *videoProcessingQueue = nil;
        SCProcessingQueue *filterRenderingQueue = nil;
        SCProcessingQueue *videoReadingQueue = [SCProcessingQueue new];
        
        videoReadingQueue.maxQueueSize = 2;

        [videoReadingQueue startProcessingWithBlock:^id{
            CMSampleBufferRef sampleBuffer = [_videoOutput copyNextSampleBuffer];
            SCSampleBufferHolder *holder = nil;
            
            if (sampleBuffer != nil) {
                holder = [SCSampleBufferHolder sampleBufferHolderWithSampleBuffer:sampleBuffer];
                CFRelease(sampleBuffer);
            }
            
            return holder;
        }];
        
        if (_videoPixelAdaptor != nil) {
            filterRenderingQueue = [SCProcessingQueue new];
            filterRenderingQueue.maxQueueSize = 2;
            [filterRenderingQueue startProcessingWithBlock:^id{
                SCIOPixelBuffers *pixelBuffers = nil;
                SCSampleBufferHolder *bufferHolder = [videoReadingQueue dequeue];
                
                if (bufferHolder != nil) {
                    pixelBuffers = [self createIOPixelBuffers:bufferHolder.sampleBuffer];
                    CVPixelBufferLockBaseAddress(pixelBuffers.inputPixelBuffer, 0);
                    if (pixelBuffers.outputPixelBuffer != pixelBuffers.inputPixelBuffer) {
                        CVPixelBufferLockBaseAddress(pixelBuffers.outputPixelBuffer, 0);
                    }
                    pixelBuffers = [self renderIOPixelBuffersWithCI:pixelBuffers];
                }

                return pixelBuffers;
            }];
            
            videoProcessingQueue = [SCProcessingQueue new];
            videoProcessingQueue.maxQueueSize = 2;
            [videoProcessingQueue startProcessingWithBlock:^id{
                SCIOPixelBuffers *videoBuffers = [filterRenderingQueue dequeue];
                
                if (videoBuffers != nil) {
                    [self CGRenderWithInputPixelBuffer:videoBuffers.inputPixelBuffer toOutputPixelBuffer:videoBuffers.outputPixelBuffer atTimeInterval:CMTimeGetSeconds(videoBuffers.time)];
                }
                
                return videoBuffers;
            }];
        }
        
        dispatch_group_enter(_dispatchGroup);
        [_videoInput requestMediaDataWhenReadyOnQueue:_videoQueue usingBlock:^{
            BOOL shouldReadNextBuffer = YES;
            while (_videoInput.isReadyForMoreMediaData && shouldReadNextBuffer) {
                SCIOPixelBuffers *videoBuffer = nil;
                SCSampleBufferHolder *bufferHolder = nil;
                
                if (videoProcessingQueue != nil) {
                    videoBuffer = [videoProcessingQueue dequeue];
                } else {
                    bufferHolder = [videoReadingQueue dequeue];
                }
                
                if (videoBuffer != nil || bufferHolder != nil) {
                    if (CMTIME_COMPARE_INLINE(videoBuffer.time, >=, _nextAllowedVideoFrame)) {
                        CMTime time;
                        if (bufferHolder != nil) {
                            time = CMSampleBufferGetPresentationTimeStamp(bufferHolder.sampleBuffer);
                            shouldReadNextBuffer = [_videoInput appendSampleBuffer:bufferHolder.sampleBuffer];
                        } else {
                            time = videoBuffer.time;
                            shouldReadNextBuffer = [self encodePixelBuffer:videoBuffer.outputPixelBuffer presentationTime:videoBuffer.time];
                        }
                        
                        if (_videoConfiguration.maxFrameRate > 0) {
                            _nextAllowedVideoFrame = CMTimeAdd(time, CMTimeMake(1, _videoConfiguration.maxFrameRate));
                        }
                        
                        [self _didAppendToInput:_videoInput atTime:time];
                    }
                    
                    if (videoBuffer != nil) {
                        CVPixelBufferUnlockBaseAddress(videoBuffer.outputPixelBuffer, 0);
                    }
                } else {
                    shouldReadNextBuffer = NO;
                }
            }
            
            if (!shouldReadNextBuffer) {
                [filterRenderingQueue stopProcessing];
                [videoProcessingQueue stopProcessing];
                [videoReadingQueue stopProcessing];
                [self markInputComplete:_videoInput error:nil];
                
                dispatch_group_leave(_dispatchGroup);
            }
        }];
    }
}

- (void)beginReadWriteOnAudio {
    if (_audioInput != nil) {
        dispatch_group_enter(_dispatchGroup);
        [_audioInput requestMediaDataWhenReadyOnQueue:_audioQueue usingBlock:^{
            BOOL shouldReadNextBuffer = YES;

            while (_audioInput.isReadyForMoreMediaData && shouldReadNextBuffer) {
                CMSampleBufferRef audioBuffer = [_audioOutput copyNextSampleBuffer];
                
                if (audioBuffer != nil) {
                    shouldReadNextBuffer = [_audioInput appendSampleBuffer:audioBuffer];
                    
                    CMTime time = CMSampleBufferGetPresentationTimeStamp(audioBuffer);
                    
                    CFRelease(audioBuffer);
                    
                    [self _didAppendToInput:_audioInput atTime:time];
                } else {
                    shouldReadNextBuffer = NO;
                }
            }
            
            if (!shouldReadNextBuffer) {
                [self markInputComplete:_audioInput error:nil];
                
                dispatch_group_leave(_dispatchGroup);
            }
        }];
    }
}

- (void)_setProgress:(float)progress {
    [self willChangeValueForKey:@"progress"];
    
    _progress = progress;
    
    [self didChangeValueForKey:@"progress"];
    
    id<SCAssetExportSessionDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(assetExportSessionDidProgress:)]) {
        [delegate assetExportSessionDidProgress:self];
    }
}

- (void)callCompletionHandler:(void (^)())completionHandler {
    [self _setProgress:1];
    
    if (completionHandler != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler();
        });
    }
}

- (BOOL)setupCoreImage:(AVAssetTrack *)videoTrack {
    if ([self needsCIContext] && _videoInput != nil) {
        if (self.useGPUForRenderingFilters) {
            _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        }
        
        if (_eaglContext == nil) {
            NSDictionary *options = @{ kCIContextUseSoftwareRenderer : [NSNumber numberWithBool:YES] };
            _ciContext = [CIContext contextWithOptions:options];
        } else {
            NSDictionary *options = @{ kCIContextWorkingColorSpace : [NSNull null], kCIContextOutputColorSpace : [NSNull null] };

            _ciContext = [CIContext contextWithEAGLContext:_eaglContext options:options];
        }
        
        return YES;
    } else {
        _ciContext = nil;
        _eaglContext = nil;
        
        return NO;
    }
}

- (BOOL)needsInputPixelBufferAdaptor {
    id<SCAssetExportSessionDelegate> delegate = self.delegate;

    if ([delegate respondsToSelector:@selector(assetExportSessionNeedsInputPixelBufferAdaptor:)] && [delegate assetExportSessionNeedsInputPixelBufferAdaptor:self]) {
        return YES;
    }
    
    return _ciContext != nil || self.videoConfiguration.overlay != nil;
}

+ (NSError*)createError:(NSString*)errorDescription {
    return [NSError errorWithDomain:@"SCAssetExportSession" code:200 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
}

- (BOOL)needsCIContext {
    return (_videoConfiguration.filter != nil && !_videoConfiguration.filter.isEmpty) || _videoConfiguration.watermarkImage != nil;
}

- (void)setupPixelBufferAdaptor:(CGSize)videoSize {
    if ([self needsInputPixelBufferAdaptor] && _videoInput != nil) {
        NSDictionary *pixelBufferAttributes = @{
                                                (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],
                                                (id)kCVPixelBufferWidthKey : [NSNumber numberWithFloat:videoSize.width],
                                                (id)kCVPixelBufferHeightKey : [NSNumber numberWithFloat:videoSize.height]
                                                };
        
        _videoPixelAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoInput sourcePixelBufferAttributes:pixelBufferAttributes];
    }
}

- (SCFilter *)_buildWatermarkFilterForVideoTrack:(AVAssetTrack *)videoTrack {
    UIImage *watermarkImage = self.videoConfiguration.watermarkImage;
    
    if (watermarkImage != nil) {
        CGSize videoSize = videoTrack.naturalSize;
        
        CGRect watermarkFrame = self.videoConfiguration.watermarkFrame;
        
        switch (self.videoConfiguration.watermarkAnchorLocation) {
            case SCWatermarkAnchorLocationTopLeft:

                break;
            case SCWatermarkAnchorLocationTopRight:
                watermarkFrame.origin.x = videoSize.width - watermarkFrame.size.width - watermarkFrame.origin.x;
                break;
            case SCWatermarkAnchorLocationBottomLeft:
                watermarkFrame.origin.y = videoSize.height - watermarkFrame.size.height - watermarkFrame.origin.y;
                
                break;
            case SCWatermarkAnchorLocationBottomRight:
                watermarkFrame.origin.y = videoSize.height - watermarkFrame.size.height - watermarkFrame.origin.y;
                watermarkFrame.origin.x = videoSize.width - watermarkFrame.size.width - watermarkFrame.origin.x;
                break;
        }
        
        UIGraphicsBeginImageContextWithOptions(videoSize, NO, 1);
        
        [watermarkImage drawInRect:watermarkFrame];
        
        UIImage *generatedWatermarkImage = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
        
        SCFilter *watermarkFilter = [SCFilter filterWithCIFilterName:@"CISourceOverCompositing"];
        CIImage *watermarkCIImage = [CIImage imageWithCGImage:generatedWatermarkImage.CGImage];
        [watermarkFilter setParameterValue:watermarkCIImage forKey:kCIInputImageKey];
        
        return watermarkFilter;
    }
    
    return nil;
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)())completionHandler {
    _nextAllowedVideoFrame = kCMTimeZero;
    NSError *error = nil;
    
    [[NSFileManager defaultManager] removeItemAtURL:self.outputUrl error:nil];
    
    _writer = [AVAssetWriter assetWriterWithURL:self.outputUrl fileType:self.outputFileType error:&error];
    _writer.metadata = [SCRecorderTools assetWriterMetadata];

    EnsureSuccess(error, completionHandler);
    
    _reader = [AVAssetReader assetReaderWithAsset:self.inputAsset error:&error];
    _reader.timeRange = _timeRange;
    EnsureSuccess(error, completionHandler);
    
    NSArray *audioTracks = [self.inputAsset tracksWithMediaType:AVMediaTypeAudio];
    if (audioTracks.count > 0 && self.audioConfiguration.enabled && !self.audioConfiguration.shouldIgnore) {
        // Input
        NSDictionary *audioSettings = [_audioConfiguration createAssetWriterOptionsUsingSampleBuffer:nil];
        _audioInput = [self addWriter:AVMediaTypeAudio withSettings:audioSettings];
        
        // Output
        AVAudioMix *audioMix = self.audioConfiguration.audioMix;
        
        AVAssetReaderOutput *reader = nil;
        NSDictionary *settings = @{ AVFormatIDKey : [NSNumber numberWithUnsignedInt:kAudioFormatType] };
        if (audioMix == nil) {
            reader = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTracks.firstObject outputSettings:settings];
        } else {
            AVAssetReaderAudioMixOutput *audioMixOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:audioTracks audioSettings:settings];
            audioMixOutput.audioMix = audioMix;
            reader = audioMixOutput;
        }
        reader.alwaysCopiesSampleData = NO;
        
        if ([_reader canAddOutput:reader]) {
            [_reader addOutput:reader];
            _audioOutput = reader;
        } else {
            NSLog(@"Unable to add audio reader output");
        }
    } else {
        _audioOutput = nil;
    }
    
    NSArray *videoTracks = [self.inputAsset tracksWithMediaType:AVMediaTypeVideo];
    CGSize inputBufferSize = CGSizeZero;
    AVAssetTrack *videoTrack = nil;
    if (videoTracks.count > 0 && self.videoConfiguration.enabled && !self.videoConfiguration.shouldIgnore) {
        videoTrack = [videoTracks objectAtIndex:0];

        // Input
        NSDictionary *videoSettings = [_videoConfiguration createAssetWriterOptionsWithVideoSize:videoTrack.naturalSize];
        
        _videoInput = [self addWriter:AVMediaTypeVideo withSettings:videoSettings];
        if (_videoConfiguration.keepInputAffineTransform) {
            _videoInput.transform = videoTrack.preferredTransform;
        } else {
            _videoInput.transform = _videoConfiguration.affineTransform;
        }
        
        // Output
        NSDictionary *settings = nil;
        if ([self needsCIContext] || self.videoConfiguration.overlay != nil) {
            settings = @{
                         (id)kCVPixelBufferPixelFormatTypeKey     : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
                         (id)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary]
                         };
        } else {
            settings = @{
                         (id)kCVPixelBufferPixelFormatTypeKey     : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
                         (id)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary]
                         };
        }
        
        AVVideoComposition *videoComposition = self.videoConfiguration.composition;
        
        _watermarkFilter = [self _buildWatermarkFilterForVideoTrack:videoTrack];
        
        AVAssetReaderOutput *reader = nil;
        
        if (videoComposition == nil) {
            inputBufferSize = videoTrack.naturalSize;
            reader = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:settings];
        } else {
            AVAssetReaderVideoCompositionOutput *videoCompositionOutput = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:videoTracks videoSettings:settings];
            videoCompositionOutput.videoComposition = videoComposition;
            reader = videoCompositionOutput;
            inputBufferSize = videoComposition.renderSize;
        }
        
        reader.alwaysCopiesSampleData = NO;

        if ([_reader canAddOutput:reader]) {
            [_reader addOutput:reader];
            _videoOutput = reader;
        } else {
            NSLog(@"Unable to add video reader output");
        }
    } else {
        _videoOutput = nil;
    }
    
    EnsureSuccess(error, completionHandler);
    
    CGSize outputBufferSize = inputBufferSize;
    if (!CGSizeEqualToSize(self.videoConfiguration.bufferSize, CGSizeZero)) {
        outputBufferSize = self.videoConfiguration.bufferSize;
    }
    
    _outputBufferSize = outputBufferSize;
    _outputBufferDiffersFromInput = !CGSizeEqualToSize(inputBufferSize, outputBufferSize);
    
    [self setupCoreImage:videoTrack];
    [self setupPixelBufferAdaptor:outputBufferSize];
    
    if (![_reader startReading]) {
        EnsureSuccess(_reader.error, completionHandler);
    }
    
    if (![_writer startWriting]) {
        EnsureSuccess(_writer.error, completionHandler);
    }
    
    [_writer startSessionAtSourceTime:kCMTimeZero];
    
    _totalDuration = CMTimeGetSeconds(_inputAsset.duration);
    
    
    [self beginReadWriteOnAudio];
    [self beginReadWriteOnVideo];
    
    dispatch_group_notify(_dispatchGroup, dispatch_get_main_queue(), ^{
        if (_error == nil) {
            _error = _writer.error;
        }
        
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
    return _videoQueue;
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
