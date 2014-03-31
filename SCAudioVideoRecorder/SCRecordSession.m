//
//  SCSession.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 27/03/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCRecordSession.h"

@interface SCRecordSession() {
    AVAssetWriter *_assetWriter;
    AVAssetWriterInput *_videoInput;
    AVAssetWriterInput *_audioInput;
    NSMutableArray *_recordSegments;
    BOOL _audioInitializationFailed;
    BOOL _videoInitializationFailed;
    BOOL _shouldRecomputeTimeOffset;
    BOOL _recordSegmentReady;
    BOOL _currentSegmentEmpty;
    int _currentSegmentCount;
    CMTime _timeOffset;
    CMTime _lastTime;
    NSString *_suggestedFileType;
}
@end

@implementation SCRecordSession

- (id)init {
    self = [super init];
    
    if (self) {
        self.videoSize = CGSizeZero;
        self.videoCodec = kRecordSessionDefaultVideoCodec;
        self.videoScalingMode = kRecordSessionDefaultVideoScalingMode;
        self.videoBitsPerPixel = kRecordSessionDefaultOutputBitPerPixel;
        self.videoAffineTransform = CGAffineTransformIdentity;
        self.videoMaxFrameRate = 0;
        
        self.audioSampleRate = 0;
        self.audioChannels = 0;
        self.audioBitRate = kRecordSessionDefaultAudioBitrate;
        self.audioEncodeType = kRecordSessionDefaultAudioFormat;
        
        self.suggestedMaxRecordDuration = kCMTimeInvalid;
        
        _recordSegments = [[NSMutableArray alloc] init];
        
        _assetWriter = nil;
        _videoInput = nil;
        _audioInput = nil;
        _audioInitializationFailed = NO;
        _videoInitializationFailed = NO;
        _currentSegmentCount = 0;
        _timeOffset = kCMTimeZero;
        _lastTime = kCMTimeZero;
        
        long timeInterval =  (long)[[NSDate date] timeIntervalSince1970];
        self.outputUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%ld%@", NSTemporaryDirectory(), timeInterval, @"SCVideo.mp4"]];
    }
    
    return self;
}

+ (id)recordSession {
    return [[SCRecordSession alloc] init];
}

+ (NSError*)createError:(NSString*)errorDescription {
    return [NSError errorWithDomain:@"SCRecordSession" code:200 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
}

- (void)removeFile:(NSURL *)fileUrl {
    [[NSFileManager defaultManager] removeItemAtPath:fileUrl.path error:nil];
}

- (void)removeSegmentAtIndex:(NSInteger)segmentIndex {
    NSURL *fileUrl = [_recordSegments objectAtIndex:segmentIndex];
    [self removeFile:fileUrl];
    
    [_recordSegments removeObjectAtIndex:segmentIndex];
}

- (void)removeAllSegments {
    while (_recordSegments.count > 0) {
        [self removeSegmentAtIndex:0];
    }
}

- (AVAssetWriter*)createWriter:(NSError**)error {
    NSError *theError = nil;
    AVAssetWriter *writer = nil;
    
    if (self.outputUrl != nil) {
        NSString *extension = [self.outputUrl.path pathExtension];
        NSString *newExtension = [NSString stringWithFormat:@"%d.%@", _currentSegmentCount, extension];
        NSURL *file = [NSURL fileURLWithPath:[self.outputUrl.path.stringByDeletingPathExtension stringByAppendingPathExtension:newExtension]];
        
        [self removeFile:file];
        
        NSString *fileType = self.fileType;
        
        if (fileType == nil) {
            fileType = _suggestedFileType;
        }
        
        writer = [[AVAssetWriter alloc] initWithURL:file fileType:fileType error:&theError];
        
        if (theError == nil) {
            if (_videoInput != nil) {
                if ([writer canAddInput:_videoInput]) {
                    [writer addInput:_videoInput];
                } else {
                    theError = [SCRecordSession createError:@"Cannot add videoInput to the assetWriter with the currently applied settings"];
                }
            }
            
            if (_audioInput != nil) {
                if ([writer canAddInput:_audioInput]) {
                    [writer addInput:_audioInput];
                } else {
                    theError = [SCRecordSession createError:@"Cannot add audioInput to the assetWriter with the currently applied settings"];
                }
            }
            
            if ([writer startWriting]) {
                [writer startSessionAtSourceTime:_lastTime];
                _recordSegmentReady = YES;
            }
            
            _currentSegmentCount++;
        }
    } else {
        theError = [SCRecordSession createError:@"No outputUrl has been set in the SCRecordSession"];
    }
    
    if (error != nil) {
        *error = theError;
    }
    
    return writer;
}

+ (NSInteger) getBitsPerSecondForOutputVideoSize:(CGSize)size andBitsPerPixel:(Float32)bitsPerPixel {
    int numPixels = size.width * size.height;
    
    return (NSInteger)((Float32)numPixels * bitsPerPixel);
}

- (void)initializeVideoUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer suggestedFileType:(NSString *)fileType error:(NSError *__autoreleasing *)error {
    _suggestedFileType = fileType;
    
    NSLog(@"Initialize %@ with suggestedFileType: %@", self, fileType);
    NSDictionary *videoSettings = self.videoOutputSettings;
        
    if (videoSettings == nil) {
        CGSize videoSize = self.videoSize;
        
        if (CGSizeEqualToSize(videoSize, CGSizeZero)) {
            CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            size_t width = CVPixelBufferGetWidth(imageBuffer);
            size_t height = CVPixelBufferGetHeight(imageBuffer);
            videoSize.width = width;
            videoSize.height = height;
        }
        
        NSInteger bitsPerSecond = [SCRecordSession getBitsPerSecondForOutputVideoSize:videoSize andBitsPerPixel:self.videoBitsPerPixel];
        
        videoSettings = @{
                          AVVideoCodecKey : self.videoCodec,
                          AVVideoScalingModeKey : self.videoScalingMode,
                          AVVideoWidthKey : [NSNumber numberWithInteger:videoSize.width],
                          AVVideoHeightKey : [NSNumber numberWithInteger:videoSize.height],
                          AVVideoCompressionPropertiesKey : @{AVVideoAverageBitRateKey: [NSNumber numberWithInteger:bitsPerSecond]}
                          };
    }
    
    
    _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    _videoInput.expectsMediaDataInRealTime = YES;
    _videoInput.transform = self.videoAffineTransform;
    
    *error = nil;
}

- (void)initializeAudioUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer suggestedFileType:(NSString *)fileType error:(NSError *__autoreleasing *)error {
    _suggestedFileType = fileType;
    
    NSLog(@"Initialize %@ with suggestedFileType: %@", self, fileType);

    NSDictionary *audioSettings = self.audioOutputSettings;
    
    if (audioSettings == nil) {
        Float64 sampleRate = self.audioSampleRate;
        int channels = self.audioChannels;
        CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
        const AudioStreamBasicDescription * streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
        
        if (sampleRate == 0) {
            sampleRate = streamBasicDescription->mSampleRate;
        }
        if (channels == 0) {
            channels = streamBasicDescription->mChannelsPerFrame;
        }
        
        audioSettings = @{
                          AVFormatIDKey : [NSNumber numberWithInt: self.audioEncodeType],
                          AVEncoderBitRateKey : [NSNumber numberWithInt: self.audioBitRate],
                          AVSampleRateKey : [NSNumber numberWithFloat: sampleRate],
                          AVNumberOfChannelsKey : [NSNumber numberWithInt: channels]
                          };
    }
    
    _audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    _audioInput.expectsMediaDataInRealTime = YES;
    
    *error = nil;
}

- (void)saveToCameraRoll {
    
}

//
// The following function is from http://www.gdcl.co.uk/2013/02/20/iPhone-Pause.html
//
- (CMSampleBufferRef) adjustBuffer:(CMSampleBufferRef)sample withTimeOffset:(CMTime)offset andDuration:(CMTime)duration {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
        pInfo[i].duration = duration;
    }
    
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}

- (void)beginRecordSegment:(NSError**)error {
    if (_assetWriter == nil) {
        _assetWriter = [self createWriter:error];
        _currentSegmentEmpty = YES;
    } else {
        if (error != nil) {
            *error = [SCRecordSession createError:@"A record segment has already began."];
        }
    }
}

- (void)makeTimeOffsetDirty {
    _shouldRecomputeTimeOffset = YES;
}

- (void)endRecordSegment:(void(^)(NSInteger segmentNumber, NSError* error))completionHandler {
    _recordSegmentReady = NO;
    
    [self makeTimeOffsetDirty];
    AVAssetWriter *writer = _assetWriter;
    
    if (_currentSegmentEmpty) {
        [writer cancelWriting];
        [self removeFile:writer.outputURL];
        _assetWriter = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler != nil) {
                completionHandler(-1, nil);
            }
        });
    } else {
        [writer finishWritingWithCompletionHandler: ^{
            _assetWriter = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                NSInteger segmentNumber = -1;
                if (writer.error == nil) {
                    segmentNumber = _recordSegments.count;
                    [_recordSegments addObject:writer.outputURL];
                }
                
                if (completionHandler != nil) {
                    completionHandler(segmentNumber, writer.error);
                }
            });
        }];
    }
}

- (void)mergeRecordSegments:(void(^)(NSError *error))completionHandler {
    NSURL *outputUrl = self.outputUrl;
    NSString *fileType = self.fileType;

    if (fileType == nil) {
        fileType = _suggestedFileType;
    }
    
    
    if (fileType == nil) {
        if (completionHandler != nil) {
            completionHandler([SCRecordSession createError:@"No output fileType was set"]);
        }
        return;
    }
    
    if (outputUrl == nil) {
        if (completionHandler != nil) {
            completionHandler([SCRecordSession createError:@"No outputUrl was set"]);
        }
        return;
    }
    
    [self removeFile:self.outputUrl];
    
    if (_recordSegments.count == 1) {
        // If we only have one segment, we can just copy that file to the destination
        NSURL *fileUrl = [_recordSegments objectAtIndex:0];
        NSError *error = nil;
        [[NSFileManager defaultManager] copyItemAtURL:fileUrl toURL:outputUrl error:&error];
        
        if (completionHandler != nil) {
            completionHandler(error);
        }
    } else {
        AVAsset *asset = [self assetRepresentingRecordSegments];
        
        NSString *exportPreset = self.recordSegmentsMergePreset;
        
        if (exportPreset == nil) {
            if ([fileType isEqualToString:AVFileTypeAppleM4A]) {
                exportPreset = AVAssetExportPresetAppleM4A;
            } else if ([fileType isEqualToString:AVFileTypeMPEG4] || [fileType isEqualToString:AVFileTypeQuickTimeMovie] || [fileType isEqualToString:AVFileTypeAppleM4V]) {
                // Maybe some others fileTypes support this preset. If you find one that does, please add it in this condition.
                exportPreset = AVAssetExportPresetPassthrough;
            }
        }
        
        if (exportPreset != nil) {
            AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:exportPreset];
            exportSession.outputURL = outputUrl;
            exportSession.outputFileType = fileType;
            exportSession.shouldOptimizeForNetworkUse = YES;
            [exportSession exportAsynchronouslyWithCompletionHandler:^{
                NSError *error = exportSession.error;
                
                if (completionHandler != nil) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionHandler(error);
                    });
                }
            }];
        } else {
            if (completionHandler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *errorString = [NSString stringWithFormat:@"Cannot find out which preset to use for the AVAssetExportSession using fileType %@. Please set one manually", fileType];
                    completionHandler([SCRecordSession createError:errorString]);
                });
            }
        }
    }
}

- (void)finishEndSession:(NSError*)mergeError completionHandler:(void (^)(NSError *))completionHandler {
    if (mergeError == nil) {
        [self removeAllSegments];
        if (completionHandler != nil) {
            completionHandler(nil);
        }
    } else {
        if (completionHandler != nil) {
            completionHandler(mergeError);
        }
    }
}

- (void)endSession:(void (^)(NSError *))completionHandler {
    if (_assetWriter == nil) {
        [self mergeRecordSegments:^(NSError *error) {
            [self finishEndSession:error completionHandler:completionHandler];
        }];
    } else {
        [self endRecordSegment:^(NSInteger segmentNumber, NSError *error) {
            if (error != nil) {
                if (completionHandler != nil) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionHandler(error);
                    });
                }
            } else {
                // We don't recurse, if the user has not removed the recordSession
                // from the recorder, a new recordSegment might has been created,
                // therefore _assetWriter might be != nil
                [self mergeRecordSegments:^(NSError *error) {
                    [self finishEndSession:error completionHandler:completionHandler];
                }];
            }
        }];
    }
}

- (void)appendBuffer:(CMSampleBufferRef)buffer to:(AVAssetWriterInput*)input frameDuration:(CMTime)frameDuration {
    _currentSegmentEmpty = NO;
    
    CMTime actualBufferTime = CMSampleBufferGetPresentationTimeStamp(buffer);
    
    if (_shouldRecomputeTimeOffset) {
        _shouldRecomputeTimeOffset = NO;
        _timeOffset = CMTimeSubtract(actualBufferTime, _lastTime);
    }
    
    CMTime duration = CMSampleBufferGetDuration(buffer);
    CMSampleBufferRef adjustedBuffer = [self adjustBuffer:buffer withTimeOffset:_timeOffset andDuration:duration];
    
    _lastTime = CMSampleBufferGetPresentationTimeStamp(adjustedBuffer);
    
    if (CMTIME_IS_VALID(duration)) {
        _lastTime = CMTimeAdd(_lastTime, duration);
    } else {
        if (_videoMaxFrameRate == 0) {
            _lastTime = CMTimeAdd(_lastTime, frameDuration);
        } else {
            _lastTime = CMTimeAdd(_lastTime, CMTimeMake(1, _videoMaxFrameRate));
        }
    }
    
    if ([input isReadyForMoreMediaData]) {
        [input appendSampleBuffer:adjustedBuffer];
    }
    
    CFRelease(adjustedBuffer);
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer {
    [self appendBuffer:audioSampleBuffer to:_audioInput frameDuration:kCMTimeZero];
}

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)videoSampleBuffer frameDuration:(CMTime)frameDuration {
    [self appendBuffer:videoSampleBuffer to:_videoInput frameDuration:frameDuration];
}

- (AVAsset *)assetRepresentingRecordSegments {
    AVMutableComposition * composition = [AVMutableComposition composition];
	
    int currentSegment = 0;
    for (NSURL *recordSegment in _recordSegments) {
        AVURLAsset *asset = [AVURLAsset assetWithURL:recordSegment];
        CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
        
        NSError *error = nil;
        [composition insertTimeRange:timeRange ofAsset:asset atTime:composition.duration error:&error];
        
        currentSegment++;
    }

    return composition;
}

- (BOOL)videoInitialized {
    return _videoInput != nil;
}

- (BOOL)audioInitialized {
    return _audioInput != nil;
}

- (BOOL)recordSegmentBegan {
    return _assetWriter != nil;
}

- (CMTime)currentRecordDuration {
    return _lastTime;
}

- (BOOL)recordSegmentReady {
    return _recordSegmentReady;
}

- (CGFloat)ratioRecorded {
    CGFloat ratio = 0;
    
    if (CMTIME_IS_VALID(_suggestedMaxRecordDuration)) {
        Float64 maxRecordDuration = CMTimeGetSeconds(_suggestedMaxRecordDuration);
        Float64 recordedTime = CMTimeGetSeconds(_lastTime);
        
        ratio = (CGFloat)(recordedTime / maxRecordDuration);
    }
    
    return ratio;
}

@end
