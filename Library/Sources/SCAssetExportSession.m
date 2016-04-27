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
#import "SCFilter+VideoComposition.h"

#define EnsureSuccess(error, x) if (error != nil) { _error = error; if (x != nil) x(); return; }
#define kAudioFormatType kAudioFormatLinearPCM

@interface SCAssetExportSession() {
    AVAssetWriter *_writer;
    AVAssetReader *_reader;
    AVAssetWriterInputPixelBufferAdaptor *_videoPixelAdaptor;
    dispatch_queue_t _audioQueue;
    dispatch_queue_t _videoQueue;
    dispatch_group_t _dispatchGroup;
    BOOL _animationsWereEnabled;
    Float64 _totalDuration;
    CGSize _inputBufferSize;
    CGSize _outputBufferSize;
    BOOL _outputBufferDiffersFromInput;
    SCContext *_context;
    CVPixelBufferRef _contextPixelBuffer;
    SCFilter *_filter;
}

@property (nonatomic, strong) AVAssetReaderOutput *videoOutput;
@property (nonatomic, strong) AVAssetReaderOutput *audioOutput;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;
@property (nonatomic, assign) BOOL needsLeaveAudio;
@property (nonatomic, assign) BOOL needsLeaveVideo;
@property (nonatomic, assign) CMTime nextAllowedVideoFrame;

@end

@implementation SCAssetExportSession

-(instancetype)init {
    self = [super init];
    
    if (self) {
        _audioQueue = dispatch_queue_create("me.corsin.SCAssetExportSession.AudioQueue", nil);
        _videoQueue = dispatch_queue_create("me.corsin.SCAssetExportSession.VideoQueue", nil);
        _dispatchGroup = dispatch_group_create();
        _contextType = SCContextTypeAuto;
        _audioConfiguration = [SCAudioConfiguration new];
        _videoConfiguration = [SCVideoConfiguration new];
        _timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
        _translatesFilterIntoComposition = YES;
        _shouldOptimizeForNetworkUse = NO;
    }

    return self;
}

- (instancetype)initWithAsset:(AVAsset *)inputAsset {
    self = [self init];
    
    if (self) {
        self.inputAsset = inputAsset;
    }
    
    return self;
}

- (void)dealloc {
    if (_contextPixelBuffer != nil) {
        CVPixelBufferRelease(_contextPixelBuffer);
    }
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

    if (_context != nil) {
        @autoreleasepool {
            CIImage *result = [CIImage imageWithCVPixelBuffer:pixelBuffers.inputPixelBuffer];

            NSTimeInterval timeSeconds = CMTimeGetSeconds(pixelBuffers.time);

            if (_filter != nil) {
                result = [_filter imageByProcessingImage:result atTime:timeSeconds];
            }

            if (!CGSizeEqualToSize(result.extent.size, _outputBufferSize)) {
                result = [result imageByCroppingToRect:CGRectMake(result.extent.origin.x, result.extent.origin.y, _outputBufferSize.width, _outputBufferSize.height)];
            }

            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

            [_context.CIContext render:result toCVPixelBuffer:pixelBuffers.outputPixelBuffer bounds:result.extent colorSpace:colorSpace];

            CGColorSpaceRelease(colorSpace);

            if (pixelBuffers.inputPixelBuffer != pixelBuffers.outputPixelBuffer) {
                CVPixelBufferUnlockBaseAddress(pixelBuffers.inputPixelBuffer, 0);
            }
        }

        outputPixelBuffers = [SCIOPixelBuffers IOPixelBuffersWithInputPixelBuffer:pixelBuffers.outputPixelBuffer outputPixelBuffer:pixelBuffers.outputPixelBuffer time:pixelBuffers.time];
    }
    
    return outputPixelBuffers;
}

static CGContextRef SCCreateContextFromPixelBuffer(CVPixelBufferRef pixelBuffer) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;

    CGContextRef ctx = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(pixelBuffer), CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), 8, CVPixelBufferGetBytesPerRow(pixelBuffer), colorSpace, bitmapInfo);

    CGColorSpaceRelease(colorSpace);

    CGContextTranslateCTM(ctx, 1, CGBitmapContextGetHeight(ctx));
    CGContextScaleCTM(ctx, 1, -1);

    return ctx;
}

- (void)CGRenderWithInputPixelBuffer:(CVPixelBufferRef)inputPixelBuffer toOutputPixelBuffer:(CVPixelBufferRef)outputPixelBuffer atTimeInterval:(NSTimeInterval)timeSeconds {
    UIView<SCVideoOverlay> *overlay = self.videoConfiguration.overlay;
    
    if (overlay != nil) {
        if ([overlay respondsToSelector:@selector(updateWithVideoTime:)]) {
            [overlay updateWithVideoTime:timeSeconds];
        }

        CGContextRef ctx = SCCreateContextFromPixelBuffer(outputPixelBuffer);
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

    if (_writer.status != AVAssetWriterStatusCancelled) {
        [input markAsFinished];
    }
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

        __weak typeof(self) wSelf = self;
        
        videoReadingQueue.maxQueueSize = 2;

        [videoReadingQueue startProcessingWithBlock:^id{
            CMSampleBufferRef sampleBuffer = [wSelf.videoOutput copyNextSampleBuffer];
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
                    __strong typeof(self) strongSelf = wSelf;

                    if (strongSelf != nil) {
                        pixelBuffers = [strongSelf createIOPixelBuffers:bufferHolder.sampleBuffer];
                        CVPixelBufferLockBaseAddress(pixelBuffers.inputPixelBuffer, 0);
                        if (pixelBuffers.outputPixelBuffer != pixelBuffers.inputPixelBuffer) {
                            CVPixelBufferLockBaseAddress(pixelBuffers.outputPixelBuffer, 0);
                        }
                        pixelBuffers = [strongSelf renderIOPixelBuffersWithCI:pixelBuffers];
                    }
                }

                return pixelBuffers;
            }];
            
            videoProcessingQueue = [SCProcessingQueue new];
            videoProcessingQueue.maxQueueSize = 2;
            [videoProcessingQueue startProcessingWithBlock:^id{
                SCIOPixelBuffers *videoBuffers = [filterRenderingQueue dequeue];
                
                if (videoBuffers != nil) {
                    [wSelf CGRenderWithInputPixelBuffer:videoBuffers.inputPixelBuffer toOutputPixelBuffer:videoBuffers.outputPixelBuffer atTimeInterval:CMTimeGetSeconds(videoBuffers.time)];
                }
                
                return videoBuffers;
            }];
        }
        
        dispatch_group_enter(_dispatchGroup);
        _needsLeaveVideo = YES;

        [_videoInput requestMediaDataWhenReadyOnQueue:_videoQueue usingBlock:^{
            BOOL shouldReadNextBuffer = YES;
            __strong typeof(self) strongSelf = wSelf;
            while (strongSelf.videoInput.isReadyForMoreMediaData && shouldReadNextBuffer && !strongSelf.cancelled) {
                SCIOPixelBuffers *videoBuffer = nil;
                SCSampleBufferHolder *bufferHolder = nil;

                CMTime time;
                if (videoProcessingQueue != nil) {
                    videoBuffer = [videoProcessingQueue dequeue];
                    time = videoBuffer.time;
                } else {
                    bufferHolder = [videoReadingQueue dequeue];
                    if (bufferHolder != nil) {
                        time = CMSampleBufferGetPresentationTimeStamp(bufferHolder.sampleBuffer);
                    }
                }

                if (videoBuffer != nil || bufferHolder != nil) {
                    if (CMTIME_COMPARE_INLINE(time, >=, strongSelf.nextAllowedVideoFrame)) {
                        if (bufferHolder != nil) {
                            shouldReadNextBuffer = [strongSelf.videoInput appendSampleBuffer:bufferHolder.sampleBuffer];
                        } else {
                            shouldReadNextBuffer = [strongSelf encodePixelBuffer:videoBuffer.outputPixelBuffer presentationTime:videoBuffer.time];
                        }

                        if (strongSelf.videoConfiguration.maxFrameRate > 0) {
                            strongSelf.nextAllowedVideoFrame = CMTimeAdd(time, CMTimeMake(1, strongSelf.videoConfiguration.maxFrameRate));
                        }

                        [strongSelf _didAppendToInput:strongSelf.videoInput atTime:time];
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
                [strongSelf markInputComplete:strongSelf.videoInput error:nil];

                if (strongSelf.needsLeaveVideo) {
                    strongSelf.needsLeaveVideo = NO;
                    dispatch_group_leave(strongSelf.dispatchGroup);
                }
            }
        }];
    }
}

- (void)beginReadWriteOnAudio {
    if (_audioInput != nil) {
        dispatch_group_enter(_dispatchGroup);
        _needsLeaveAudio = YES;
        __weak typeof(self) wSelf = self;
        [_audioInput requestMediaDataWhenReadyOnQueue:_audioQueue usingBlock:^{
            __strong typeof(self) strongSelf = wSelf;
            BOOL shouldReadNextBuffer = YES;
            while (strongSelf.audioInput.isReadyForMoreMediaData && shouldReadNextBuffer && !strongSelf.cancelled) {
                CMSampleBufferRef audioBuffer = [strongSelf.audioOutput copyNextSampleBuffer];
                
                if (audioBuffer != nil) {
                    shouldReadNextBuffer = [strongSelf.audioInput appendSampleBuffer:audioBuffer];
                    
                    CMTime time = CMSampleBufferGetPresentationTimeStamp(audioBuffer);
                    
                    CFRelease(audioBuffer);
                    
                    [strongSelf _didAppendToInput:strongSelf.audioInput atTime:time];
                } else {
                    shouldReadNextBuffer = NO;
                }
            }
            
            if (!shouldReadNextBuffer) {
                [strongSelf markInputComplete:strongSelf.audioInput error:nil];
                if (strongSelf.needsLeaveAudio) {
                    strongSelf.needsLeaveAudio = NO;
                    dispatch_group_leave(strongSelf.dispatchGroup);
                }
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
    if (!_cancelled) {
        [self _setProgress:1];
    }

    if (completionHandler != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler();
        });
    }
}

- (BOOL)_setupContextIfNeeded {
    if (_videoInput != nil && _filter != nil) {
        SCContextType contextType = _contextType;
        if (contextType == SCContextTypeAuto) {
            contextType = [SCContext suggestedContextType];
        }
        CGContextRef cgContext = nil;
        NSDictionary *options = nil;
        if (contextType == SCContextTypeCoreGraphics) {
            CVPixelBufferRef pixelBuffer = nil;
            CVReturn ret = CVPixelBufferPoolCreatePixelBuffer(nil, _videoPixelAdaptor.pixelBufferPool, &pixelBuffer);
            if (ret != kCVReturnSuccess) {
                NSString *format = [NSString stringWithFormat:@"Unable to create pixel buffer for creating CoreGraphics context: %d", ret];
                _error = [NSError errorWithDomain:@"InternalError" code:500 userInfo:@{NSLocalizedDescriptionKey: format}];
                return NO;
            }
            if (_contextPixelBuffer != nil) {
                CVPixelBufferRelease(_contextPixelBuffer);
            }
            _contextPixelBuffer = pixelBuffer;

            cgContext = SCCreateContextFromPixelBuffer(pixelBuffer);

            options = @{
                        SCContextOptionsCGContextKey: (__bridge id)cgContext
                        };
        }

        _context = [SCContext contextWithType:_contextType options:options];

        if (cgContext != nil) {
            CGContextRelease(cgContext);
        }

        return YES;
    } else {
        _context = nil;

        return NO;
    }
}

+ (NSError*)createError:(NSString*)errorDescription {
    return [NSError errorWithDomain:@"SCAssetExportSession" code:200 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
}

- (void)_setupPixelBufferAdaptorIfNeeded:(BOOL)needed {
    id<SCAssetExportSessionDelegate> delegate = self.delegate;
    BOOL needsPixelBuffer = needed;

    if ([delegate respondsToSelector:@selector(assetExportSessionNeedsInputPixelBufferAdaptor:)] && [delegate assetExportSessionNeedsInputPixelBufferAdaptor:self]) {
        needsPixelBuffer = YES;
    }

    if (needsPixelBuffer && _videoInput != nil) {
        NSDictionary *pixelBufferAttributes = @{
                                                (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],
                                                (id)kCVPixelBufferWidthKey : [NSNumber numberWithFloat:_outputBufferSize.width],
                                                (id)kCVPixelBufferHeightKey : [NSNumber numberWithFloat:_outputBufferSize.height]
                                                };
        
        _videoPixelAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoInput sourcePixelBufferAttributes:pixelBufferAttributes];
    }
}

- (void)cancelExport
{
    _cancelled = YES;

    dispatch_sync(_videoQueue, ^{
        if (_needsLeaveVideo) {
            _needsLeaveVideo = NO;
            dispatch_group_leave(_dispatchGroup);
        }

        dispatch_sync(_audioQueue, ^{
            if (_needsLeaveAudio) {
                _needsLeaveAudio = NO;
                dispatch_group_leave(_dispatchGroup);
            }
        });

        [_reader cancelReading];
        [_writer cancelWriting];
    });
}

- (SCFilter *)_generateRenderingFilterForVideoSize:(CGSize)videoSize {
    SCFilter *watermarkFilter = [self _buildWatermarkFilterForVideoSize:videoSize];
    SCFilter *renderingFilter = nil;
    SCFilter *customFilter = self.videoConfiguration.filter;

    if (customFilter != nil) {
        if (watermarkFilter != nil) {
            renderingFilter = [SCFilter emptyFilter];
            [renderingFilter addSubFilter:customFilter];
            [renderingFilter addSubFilter:watermarkFilter];
        } else {
            renderingFilter = customFilter;
        }
    } else {
        renderingFilter = watermarkFilter;
    }

    if (renderingFilter.isEmpty) {
        renderingFilter = nil;
    }

    return renderingFilter;
}


- (SCFilter *)_buildWatermarkFilterForVideoSize:(CGSize)videoSize {
    UIImage *watermarkImage = self.videoConfiguration.watermarkImage;

    if (watermarkImage != nil) {
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

        CIImage *watermarkCIImage = [CIImage imageWithCGImage:generatedWatermarkImage.CGImage];
        return [SCFilter filterWithCIImage:watermarkCIImage];
    }

    return nil;
}

- (void)_setupAudioUsingTracks:(NSArray *)audioTracks {
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
}

- (void)_setupVideoUsingTracks:(NSArray *)videoTracks {
    _inputBufferSize = CGSizeZero;
    if (videoTracks.count > 0 && self.videoConfiguration.enabled && !self.videoConfiguration.shouldIgnore) {
        AVAssetTrack *videoTrack = [videoTracks objectAtIndex:0];

        // Input
        NSDictionary *videoSettings = [_videoConfiguration createAssetWriterOptionsWithVideoSize:videoTrack.naturalSize];

        _videoInput = [self addWriter:AVMediaTypeVideo withSettings:videoSettings];
        if (_videoConfiguration.keepInputAffineTransform) {
            _videoInput.transform = videoTrack.preferredTransform;
        } else {
            _videoInput.transform = _videoConfiguration.affineTransform;
        }

        // Output
        AVVideoComposition *videoComposition = self.videoConfiguration.composition;
        if (videoComposition == nil) {
            _inputBufferSize = videoTrack.naturalSize;
        } else {
            _inputBufferSize = videoComposition.renderSize;
        }

        CGSize outputBufferSize = _inputBufferSize;
        if (!CGSizeEqualToSize(self.videoConfiguration.bufferSize, CGSizeZero)) {
            outputBufferSize = self.videoConfiguration.bufferSize;
        }

        _outputBufferSize = outputBufferSize;
        _outputBufferDiffersFromInput = !CGSizeEqualToSize(_inputBufferSize, outputBufferSize);

        _filter = [self _generateRenderingFilterForVideoSize:outputBufferSize];

        if (videoComposition == nil && _filter != nil && self.translatesFilterIntoComposition) {
            videoComposition = [_filter videoCompositionWithAsset:_inputAsset];
            if (videoComposition != nil) {
                _filter = nil;
            }
        }

        NSDictionary *settings = nil;
        if (_filter != nil || self.videoConfiguration.overlay != nil) {
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

        AVAssetReaderOutput *reader = nil;
        if (videoComposition == nil) {
            reader = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:settings];
        } else {
            AVAssetReaderVideoCompositionOutput *videoCompositionOutput = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:videoTracks videoSettings:settings];
            videoCompositionOutput.videoComposition = videoComposition;
            reader = videoCompositionOutput;
        }
        reader.alwaysCopiesSampleData = NO;

        if ([_reader canAddOutput:reader]) {
            [_reader addOutput:reader];
            _videoOutput = reader;
        } else {
            NSLog(@"Unable to add video reader output");
        }

        [self _setupPixelBufferAdaptorIfNeeded:_filter != nil || self.videoConfiguration.overlay != nil];
        [self _setupContextIfNeeded];
    } else {
        _videoOutput = nil;
    }
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)())completionHandler {
    _cancelled = NO;
    _nextAllowedVideoFrame = kCMTimeZero;
    NSError *error = nil;
    
    [[NSFileManager defaultManager] removeItemAtURL:self.outputUrl error:nil];
    
    _writer = [AVAssetWriter assetWriterWithURL:self.outputUrl fileType:self.outputFileType error:&error];
    _writer.shouldOptimizeForNetworkUse = _shouldOptimizeForNetworkUse;
    _writer.metadata = [SCRecorderTools assetWriterMetadata];

    EnsureSuccess(error, completionHandler);
    
    _reader = [AVAssetReader assetReaderWithAsset:self.inputAsset error:&error];
    _reader.timeRange = _timeRange;
    EnsureSuccess(error, completionHandler);

    [self _setupAudioUsingTracks:[self.inputAsset tracksWithMediaType:AVMediaTypeAudio]];
    [self _setupVideoUsingTracks:[self.inputAsset tracksWithMediaType:AVMediaTypeVideo]];

    if (_error != nil) {
        [self callCompletionHandler:completionHandler];
        return;
    }

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
        
        if (_error == nil && _writer.status != AVAssetWriterStatusCancelled) {
            [_writer finishWritingWithCompletionHandler:^{
                _error = _writer.error;
                [self callCompletionHandler:completionHandler];
            }];
        } else {
            [self callCompletionHandler:completionHandler];
        }
    });
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
