//
//  SCSession.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 27/03/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCRecordSession.h"
// These are sets in defines to avoid repeated method calls
#define CAN_HANDLE_AUDIO (_recorderHasAudio && !_shouldIgnoreAudio && !_audioInitializationFailed)
#define CAN_HANDLE_VIDEO (_recorderHasVideo && !_shouldIgnoreVideo && !_videoInitializationFailed)
#define IS_WAITING_AUDIO (CAN_HANDLE_AUDIO && !_currentSegmentHasAudio)
#define IS_WAITING_VIDEO (CAN_HANDLE_VIDEO && !_currentSegmentHasVideo)

#pragma mark - Private definition

const NSString *SCRecordSessionSegmentsKey = @"RecordSegments";
const NSString *SCRecordSessionOutputUrlKey = @"OutputUrl";
const NSString *SCRecordSessionDurationKey = @"Duration";
const NSString *SCRecordSessionIdentifierKey = @"Identifier";
const NSString *SCRecordSessionDateKey = @"Date";

@interface SCRecordSession() {
    AVAssetWriter *_assetWriter;
    AVAssetWriterInput *_videoInput;
    AVAssetWriterInput *_audioInput;
    NSMutableArray *_recordSegments;
    BOOL _audioInitializationFailed;
    BOOL _videoInitializationFailed;
    BOOL _shouldRecomputeTimeOffset;
    BOOL _recordSegmentReady;
    BOOL _currentSegmentHasVideo;
    BOOL _currentSegmentHasAudio;
    BOOL _recorderHasAudio;
    BOOL _recorderHasVideo;
    int _currentSegmentCount;
    CMTime _timeOffset;
    CMTime _lastTime;
    CMTime _lastTimeVideo;
    CMTime _lastTimeAudio;
    CMTime _sessionStartedTime;
    CMTime _currentRecordDurationWithoutCurrentSegment;
}
@end

@implementation SCRecordSession

- (id)initWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation {
    self = [self init];
    
    if (self) {
        NSArray *recordSegments = [dictionaryRepresentation objectForKey:SCRecordSessionSegmentsKey];
        
        int i = 0;
        for (NSString *recordSegment in recordSegments) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:recordSegment]) {
                NSURL *url = [NSURL fileURLWithPath:recordSegment];
                [_recordSegments addObject:url];
            } else {
                NSLog(@"Skipping record segment %d: File does not exist", i);
            }
            i++;
        }
        _currentSegmentCount = i;
        NSString *outputUrl = [dictionaryRepresentation objectForKey:SCRecordSessionOutputUrlKey];
        if (outputUrl != nil) {
            self.outputUrl = [NSURL fileURLWithPath:outputUrl];
        }
        NSNumber *recordDuration = [dictionaryRepresentation objectForKey:SCRecordSessionDurationKey];
        if (recordDuration != nil) {
            _currentRecordDuration = CMTimeMakeWithSeconds(recordDuration.doubleValue, 10000);
            _currentRecordDurationWithoutCurrentSegment = _currentRecordDuration;
        }
        _identifier = [dictionaryRepresentation objectForKey:SCRecordSessionIdentifierKey];
        _date = [dictionaryRepresentation objectForKey:SCRecordSessionDateKey];
        
//        [self recomputeRecordDuration];
    }
    
    return self;
}

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
        self.videoShouldKeepOnlyKeyFrames = NO;
        
        _recordSegments = [[NSMutableArray alloc] init];
        
        _assetWriter = nil;
        _videoInput = nil;
        _audioInput = nil;
        _audioInitializationFailed = NO;
        _videoInitializationFailed = NO;
        _currentSegmentCount = 0;
        _timeOffset = kCMTimeZero;
        _lastTime = kCMTimeZero;
        _lastTimeVideo = kCMTimeZero;
        _lastTimeAudio = kCMTimeZero;
        _currentRecordDurationWithoutCurrentSegment = kCMTimeZero;
        _currentRecordDuration = kCMTimeZero;
        _videoTimeScale = 1;
        _shouldTrackRecordSegments = YES;
        _date = [NSDate date];
        
        long timeInterval =  (long)[_date timeIntervalSince1970];
        _identifier = [NSString stringWithFormat:@"%ld", timeInterval];
        
        self.outputUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%ld%@", NSTemporaryDirectory(), timeInterval, @"SCVideo.mp4"]];
    }
    
    return self;
}

+ (id)recordSession {
    return [[SCRecordSession alloc] init];
}

+ (id)recordSession:(NSDictionary *)dictionaryRepresentation {
    return [[SCRecordSession alloc] initWithDictionaryRepresentation:dictionaryRepresentation];
}

+ (NSError*)createError:(NSString*)errorDescription {
    return [NSError errorWithDomain:@"SCRecordSession" code:200 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
}

- (void)removeFile:(NSURL *)fileUrl {
    [[NSFileManager defaultManager] removeItemAtPath:fileUrl.path error:nil];
}

- (void)removeSegmentAtIndex:(NSInteger)segmentIndex deleteFile:(BOOL)deleteFile {
    if (deleteFile) {
        NSURL *fileUrl = [_recordSegments objectAtIndex:segmentIndex];
        [self removeFile:fileUrl];
    }
    
    [_recordSegments removeObjectAtIndex:segmentIndex];
    [self recomputeRecordDuration];
}

- (void)removeAllSegments {
    while (_recordSegments.count > 0) {
        NSURL *fileUrl = [_recordSegments objectAtIndex:0];
        [self removeFile:fileUrl];
        [_recordSegments removeObjectAtIndex:0];
    }
    
    [self recomputeRecordDuration];
}

- (NSString*)suggestedFileType {
    NSString *fileType = self.fileType;
    
    if (fileType == nil) {
        if (_recorderHasVideo && !_shouldIgnoreVideo) {
            fileType = AVFileTypeMPEG4;
        } else if (_recorderHasAudio && !_shouldIgnoreAudio) {
            fileType = AVFileTypeAppleM4A;
        }
    }
    
    return fileType;
}

- (AVAssetWriter*)createWriter:(NSError**)error {
    NSError *theError = nil;
    AVAssetWriter *writer = nil;
    
    if (self.outputUrl != nil) {
        NSString *extension = [self.outputUrl.path pathExtension];
        NSString *newExtension = [NSString stringWithFormat:@"%d.%@", _currentSegmentCount, extension];
        NSURL *file = [NSURL fileURLWithPath:[self.outputUrl.path.stringByDeletingPathExtension stringByAppendingPathExtension:newExtension]];
        
        [self removeFile:file];
        
        NSString *fileType = [self suggestedFileType];
        
        if (fileType != nil) {
            writer = [[AVAssetWriter alloc] initWithURL:file fileType:fileType error:&theError];
        } else {
            theError = [SCRecordSession createError:@"No fileType has been set in the SCRecordSession"];
        }
        
        if (theError == nil) {
            writer.shouldOptimizeForNetworkUse = YES;
            
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
                _sessionStartedTime = _lastTime;
                _currentRecordDurationWithoutCurrentSegment = _currentRecordDuration;
                _recordSegmentReady = YES;
            } else {
                theError = writer.error;
                writer = nil;
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

+ (NSInteger)getBitsPerSecondForOutputVideoSize:(CGSize)size andBitsPerPixel:(Float32)bitsPerPixel {
    int numPixels = size.width * size.height;
    
    return (NSInteger)((Float32)numPixels * bitsPerPixel);
}

- (void)uninitialize {
    [self endRecordSegment:nil];
    
    _recorderHasAudio = NO;
    _recorderHasVideo = NO;
    _audioInitializationFailed = NO;
    _videoInitializationFailed = NO;
    _videoInput = nil;
    _audioInput = nil;
}

- (void)initializeVideoUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer hasAudio:(BOOL)hasAudio error:(NSError *__autoreleasing *)error {
    _recorderHasVideo = YES;
    _recorderHasAudio = hasAudio;
    NSDictionary *videoSettings = self.videoOutputSettings;
        
    if (videoSettings == nil) {
        CGSize videoSize = self.videoSize;
        
        if (CGSizeEqualToSize(videoSize, CGSizeZero)) {
            CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            size_t width = CVPixelBufferGetWidth(imageBuffer);
            size_t height = CVPixelBufferGetHeight(imageBuffer);
            videoSize.width = width;
            videoSize.height = height;
            
            if (self.videoSizeAsSquare) {
                if (width > height) {
                    videoSize.width = height;
                } else {
                    videoSize.height = width;
                }
            }
        }
        
        NSInteger bitsPerSecond = [SCRecordSession getBitsPerSecondForOutputVideoSize:videoSize andBitsPerPixel:self.videoBitsPerPixel];
        
        NSMutableDictionary *compressionSettings = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInteger:bitsPerSecond] forKey:AVVideoAverageBitRateKey];
        
        if (self.videoShouldKeepOnlyKeyFrames) {
            [compressionSettings setObject:@1 forKey:AVVideoMaxKeyFrameIntervalKey];
        }
        
        videoSettings = @{
                          AVVideoCodecKey : self.videoCodec,
                          AVVideoScalingModeKey : self.videoScalingMode,
                          AVVideoWidthKey : [NSNumber numberWithInteger:videoSize.width],
                          AVVideoHeightKey : [NSNumber numberWithInteger:videoSize.height],
                          AVVideoCompressionPropertiesKey : compressionSettings
                          };
    }
    
    NSError *theError = nil;
    @try {
        _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
        _videoInput.expectsMediaDataInRealTime = YES;
        _videoInput.transform = self.videoAffineTransform;
    }
    @catch (NSException *exception) {
        theError = [SCRecordSession createError:exception.reason];
    }
    
    _videoInitializationFailed = theError != nil;
    
    if (error != nil) {
        *error = theError;
    }
}

- (void)initializeAudioUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer hasVideo:(BOOL)hasVideo error:(NSError *__autoreleasing *)error {
    _recorderHasAudio = YES;
    _recorderHasVideo = hasVideo;
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
    
    NSError *theError = nil;
    @try {
        _audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
        _audioInput.expectsMediaDataInRealTime = YES;
    } @catch (NSException *exception) {
        theError = [SCRecordSession createError:exception.reason];
    }
    
    _audioInitializationFailed = theError != nil;
    
    if (error != nil) {
        *error = theError;
    }
}

- (void)saveToCameraRoll {
    UISaveVideoAtPathToSavedPhotosAlbum(self.outputUrl.path, nil, nil, nil);
}

- (void)recomputeRecordDuration {
    _currentRecordDurationWithoutCurrentSegment = self.assetRepresentingRecordSegments.duration;
    [self updateRecordDuration];
}

- (void)addSegment:(NSURL *)fileUrl {
    [_recordSegments addObject:fileUrl];
    [self recomputeRecordDuration];
}

- (void)insertSegment:(NSURL *)fileUrl atIndex:(NSInteger)segmentIndex {
    [_recordSegments insertObject:fileUrl atIndex:segmentIndex];
    [self recomputeRecordDuration];
}

//
// The following function is from http://www.gdcl.co.uk/2013/02/20/iPhone-Pause.html
//
- (CMSampleBufferRef)adjustBuffer:(CMSampleBufferRef)sample withTimeOffset:(CMTime)offset andDuration:(CMTime)duration {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
//        pInfo[i].duration = duration;
    }
    
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}

- (void)beginRecordSegment:(NSError**)error {
    if (_assetWriter == nil) {
        _assetWriter = [self createWriter:error];
        _currentSegmentHasAudio = NO;
        _currentSegmentHasVideo = NO;
    } else {
        if (error != nil) {
            *error = [SCRecordSession createError:@"A record segment has already began."];
        }
    }
}

- (void)_destroyAssetWriter {
    _currentSegmentHasAudio = NO;
    _currentSegmentHasVideo = NO;
    _assetWriter = nil;
}

- (void)endRecordSegment:(void(^)(NSInteger segmentNumber, NSError* error))completionHandler {
    if (_recordSegmentReady) {
        _recordSegmentReady = NO;
        
        [self makeTimeOffsetDirty];
        AVAssetWriter *writer = _assetWriter;
        
        BOOL currentSegmentEmpty = IS_WAITING_AUDIO || IS_WAITING_VIDEO;
        
        if (currentSegmentEmpty) {
            [writer cancelWriting];
            [self _destroyAssetWriter];

            [self removeFile:writer.outputURL];
            
            if (completionHandler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(-1, nil);
                });
            }
        } else {
            [writer endSessionAtSourceTime:_lastTime];
            
            [writer finishWritingWithCompletionHandler: ^{
                [self _destroyAssetWriter];
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
        _lastTime = _sessionStartedTime;
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler != nil) {
                completionHandler(-1, [SCRecordSession createError:@"The current record segment is not ready for this operation"]);
            }
        });
    }
}

- (void)makeTimeOffsetDirty {
    _shouldRecomputeTimeOffset = YES;
}

- (void)mergeRecordSegments:(void(^)(NSError *error))completionHandler {
    NSURL *outputUrl = self.outputUrl;
    NSString *fileType = [self suggestedFileType];
    
    
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
                exportPreset = AVAssetExportPresetHighestQuality;
            }
        }
        
        if (exportPreset != nil) {
            AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:exportPreset];
            exportSession.outputURL = outputUrl;
            exportSession.outputFileType = fileType;
            exportSession.shouldOptimizeForNetworkUse = YES;
            exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
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
                    NSString *errorString = [NSString stringWithFormat:@"Cannot figure out which preset to use for the AVAssetExportSession using fileType %@. Please set one manually", fileType];
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

- (void)cancelSession:(void (^)())completionHandler {
    if (_assetWriter == nil) {
        [self removeAllSegments];
        [self removeFile:self.outputUrl];
        if (completionHandler != nil) {
            completionHandler();
        }
    } else {
        [self endRecordSegment:^(NSInteger segmentIndex, NSError *error) {
            [self removeAllSegments];
            [self removeFile:self.outputUrl];
            if (completionHandler != nil) {
                completionHandler();
            }
        }];
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

- (void)updateRecordDuration {
    _currentRecordDuration = CMTimeAdd(_currentRecordDurationWithoutCurrentSegment, CMTimeSubtract(_lastTime, _sessionStartedTime));
}

- (BOOL)appendAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer {
    if (!IS_WAITING_VIDEO && [_audioInput isReadyForMoreMediaData]) {
        CMTime actualBufferTime = CMSampleBufferGetPresentationTimeStamp(audioSampleBuffer);
        
        if (_shouldRecomputeTimeOffset) {
            _shouldRecomputeTimeOffset = NO;
            _timeOffset = CMTimeSubtract(actualBufferTime, _lastTime);
        }
        
        CMTime duration = CMSampleBufferGetDuration(audioSampleBuffer);
        CMSampleBufferRef adjustedBuffer = [self adjustBuffer:audioSampleBuffer withTimeOffset:_timeOffset andDuration:duration];
        
        CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(adjustedBuffer);
        CMTime lastTimeAudio = CMTimeAdd(presentationTime, duration);
        
        if (CMTIME_COMPARE_INLINE(presentationTime, >=, kCMTimeZero)) {
            _lastTimeAudio = lastTimeAudio;
            
            if (!CAN_HANDLE_VIDEO) {
                _lastTime = lastTimeAudio;
                [self updateRecordDuration];
            }
            
//            NSLog(@"Appended audio at %f/%f", CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(adjustedBuffer)), CMTimeGetSeconds(duration));
            
            [_audioInput appendSampleBuffer:adjustedBuffer];
            _currentSegmentHasAudio = YES;
        }
        
        CFRelease(adjustedBuffer);
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)appendVideoSampleBuffer:(CMSampleBufferRef)videoSampleBuffer frameDuration:(CMTime)frameDuration {
    if ([_videoInput isReadyForMoreMediaData]) {
        CMTime actualBufferTime = CMSampleBufferGetPresentationTimeStamp(videoSampleBuffer);
        
        if (_shouldRecomputeTimeOffset) {
            _shouldRecomputeTimeOffset = NO;
            _timeOffset = CMTimeSubtract(actualBufferTime, _lastTime);
        }
        
        CMSampleBufferRef adjustedBuffer = [self adjustBuffer:videoSampleBuffer withTimeOffset:_timeOffset andDuration:kCMTimeInvalid];
        
        CMTime lastTimeVideo = CMSampleBufferGetPresentationTimeStamp(adjustedBuffer);
        CMTime duration = CMSampleBufferGetDuration(videoSampleBuffer);
        
//        if (CMTIME_COMPARE_INLINE(lastTimeVideo, >=, _lastTimeVideo)) {
        if (CMTIME_IS_INVALID(duration)) {
            if (_videoMaxFrameRate == 0) {
                duration = frameDuration;
            } else {
                duration = CMTimeMake(1, _videoMaxFrameRate);
            }
        }
        
        CMTime computedFrameDuration = duration;
        
        if (_videoTimeScale != 1.0) {
            computedFrameDuration = CMTimeMultiplyByFloat64(computedFrameDuration, _videoTimeScale);
            _timeOffset = CMTimeAdd(_timeOffset, CMTimeSubtract(duration, computedFrameDuration));
        }
        
//            NSLog(@"%f - Appended video %f (%f)", CMTimeGetSeconds(lastTimeVideo), CMTimeGetSeconds(computedFrameDuration), CMTimeGetSeconds(CMTimeSubtract(lastTimeVideo, _lastTimeVideo)));
        
        lastTimeVideo = CMTimeAdd(lastTimeVideo, computedFrameDuration);
        
        _lastTimeVideo = lastTimeVideo;
        _lastTime = lastTimeVideo;
        [self updateRecordDuration];

        [_videoInput appendSampleBuffer:adjustedBuffer];
        
        _currentSegmentHasVideo = YES;
//        } else {
//            NSLog(@"%f - Skipped video", CMTimeGetSeconds(lastTimeVideo));
//        }
        
        CFRelease(adjustedBuffer);
        return YES;
    } else {
        return NO;
    }
}

- (AVAsset *)assetRepresentingRecordSegments {
    AVMutableComposition *composition = [AVMutableComposition composition];
    
    NSDictionary *options = @{AVURLAssetPreferPreciseDurationAndTimingKey : @YES};
    int currentSegment = 0;
    for (NSURL *recordSegment in _recordSegments) {
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:recordSegment options:options];
        CMTime currentTime = composition.duration;

        NSError *error = nil;
        [composition insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofAsset:asset atTime:currentTime error:&error];
        
        if (error != nil) {
            NSLog(@"Failed to insert recordSegment at %@: %@", recordSegment, error);
        }
        
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

- (BOOL)recordSegmentReady {
    return _recordSegmentReady;
}

- (CGFloat)ratioRecorded {
    CGFloat ratio = 0;
    
    if (CMTIME_IS_VALID(_suggestedMaxRecordDuration)) {
        Float64 maxRecordDuration = CMTimeGetSeconds(_suggestedMaxRecordDuration);
        Float64 recordedTime = CMTimeGetSeconds(_currentRecordDuration);
        
        ratio = (CGFloat)(recordedTime / maxRecordDuration);
    }
    
    return ratio;
}

- (BOOL)currentSegmentHasVideo {
    return _currentSegmentHasVideo;
}

- (BOOL)currentSegmentHasAudio {
    return _currentSegmentHasAudio;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *recordSegments = [NSMutableArray array];
    
    for (NSURL *recordSegment in self.recordSegments) {
        [recordSegments addObject:recordSegment.path];
    }
    
    return @{
             SCRecordSessionSegmentsKey: recordSegments,
             SCRecordSessionOutputUrlKey : self.outputUrl.path,
             SCRecordSessionDurationKey : [NSNumber numberWithDouble:CMTimeGetSeconds(self.currentRecordDuration)],
             SCRecordSessionIdentifierKey : _identifier,
             SCRecordSessionDateKey : _date
             };
}

@end
