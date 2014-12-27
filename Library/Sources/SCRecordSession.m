//
//  SCSession.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 27/03/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCRecordSession_Internal.h"
#import "SCRecorder.h"

// These are sets in defines to avoid repeated method calls
//#define CAN_HANDLE_AUDIO (_recorderHasAudio && !_shouldIgnoreAudio && !_audioInitializationFailed)
//#define CAN_HANDLE_VIDEO (_recorderHasVideo && !_shouldIgnoreVideo && !_videoInitializationFailed)
//#define IS_WAITING_AUDIO (CAN_HANDLE_AUDIO && !_currentSegmentHasAudio)
//#define IS_WAITING_VIDEO (CAN_HANDLE_VIDEO && !_currentSegmentHasVideo)

#pragma mark - Private definition

NSString *SCRecordSessionSegmentFilenamesKey = @"RecordSegmentFilenames";
NSString *SCRecordSessionDurationKey = @"Duration";
NSString *SCRecordSessionIdentifierKey = @"Identifier";
NSString *SCRecordSessionDateKey = @"Date";
NSString *SCRecordSessionDirectoryKey = @"Directory";

NSString *SCRecordSessionTemporaryDirectory = @"TemporaryDirectory";
NSString *SCRecordSessionCacheDirectory = @"CacheDirectory";

@implementation SCRecordSession

- (id)initWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation {
    self = [self init];
    
    if (self) {
        NSString *directory = dictionaryRepresentation[SCRecordSessionDirectoryKey];
        if (directory != nil) {
            _recordSegmentsDirectory = directory;
        }
        
        NSArray *recordSegments = [dictionaryRepresentation objectForKey:SCRecordSessionSegmentFilenamesKey];
        
        int i = 0;
        BOOL shouldRecomputeDuration = NO;
        for (NSString *recordSegment in recordSegments) {
            NSURL *url = [SCRecordSession recordSegmentURLForFilename:recordSegment andDirectory:_recordSegmentsDirectory];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
                [_recordSegments addObject:url];
            } else {
                NSLog(@"Skipping record segment %d: File does not exist", i);
                shouldRecomputeDuration = YES;
            }
            i++;
        }
        _currentSegmentCount = i;
        
        NSNumber *recordDuration = [dictionaryRepresentation objectForKey:SCRecordSessionDurationKey];
        if (recordDuration != nil) {
            _segmentsDuration = CMTimeMakeWithSeconds(recordDuration.doubleValue, 10000);
        } else {
            shouldRecomputeDuration = YES;
        }
        
        if (shouldRecomputeDuration) {
            _segmentsDuration = self.assetRepresentingRecordSegments.duration;
            
            if (CMTIME_IS_INVALID(_segmentsDuration)) {
                NSLog(@"Unable to set the segments duration: one or most input assets are invalid");
                NSLog(@"The imported SCRecordSession is probably not useable.");
            }
        }
        
        _identifier = [dictionaryRepresentation objectForKey:SCRecordSessionIdentifierKey];
        _date = [dictionaryRepresentation objectForKey:SCRecordSessionDateKey];
    }
    
    return self;
}

- (id)init {
    self = [super init];
    
    if (self) {
        _recordSegments = [[NSMutableArray alloc] init];
        
        _assetWriter = nil;
        _videoInput = nil;
        _audioInput = nil;
        _audioInitializationFailed = NO;
        _videoInitializationFailed = NO;
        _currentSegmentCount = 0;
        _timeOffset = kCMTimeZero;
        _lastTimeAudio = kCMTimeZero;
        _currentSegmentDuration = kCMTimeZero;
        _segmentsDuration = kCMTimeZero;
        _date = [NSDate date];
        _recordSegmentsDirectory = SCRecordSessionTemporaryDirectory;
        _identifier = [NSString stringWithFormat:@"%ld", (long)[_date timeIntervalSince1970]];
    }
    
    return self;
}

+ (NSURL *)recordSegmentURLForFilename:(NSString *)filename andDirectory:(NSString *)directory {
    NSURL *directoryUrl = nil;
    
    if ([SCRecordSessionTemporaryDirectory isEqualToString:directory]) {
        directoryUrl = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    } else if ([SCRecordSessionCacheDirectory isEqualToString:directory]) {
        NSArray *myPathList = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        directoryUrl = [NSURL fileURLWithPath:myPathList.firstObject];
    } else {
        directoryUrl = [NSURL fileURLWithPath:directory];
    }
    
    return [directoryUrl URLByAppendingPathComponent:filename];
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

- (void)_dispatchSynchronouslyOnSafeQueue:(void(^)())block {
    SCRecorder *recorder = self.recorder;
    
    if (recorder == nil || [SCRecorder isRecordSessionQueue]) {
        block();
    } else {
        dispatch_sync(recorder.recordSessionQueue, block);
    }
}

- (void)removeFile:(NSURL *)fileUrl {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:fileUrl.path error:&error];
}

- (void)removeSegmentAtIndex:(NSInteger)segmentIndex deleteFile:(BOOL)deleteFile {
    [self _dispatchSynchronouslyOnSafeQueue:^{
        NSURL *fileUrl = [_recordSegments objectAtIndex:segmentIndex];
        CMTime segmentDuration = [(AVAsset *)[AVAsset assetWithURL:fileUrl] duration];
        [_recordSegments removeObjectAtIndex:segmentIndex];
        
        if (CMTIME_IS_VALID(segmentDuration)) {
//            NSLog(@"Removed duration of %fs", CMTimeGetSeconds(segmentDuration));
            _segmentsDuration = CMTimeSubtract(_segmentsDuration, segmentDuration);
        } else {
            NSLog(@"Removed invalid segment index %d. Recomputing duration manually", (int)segmentIndex);
            _segmentsDuration = self.assetRepresentingRecordSegments.duration;
        }
        
        if (deleteFile) {
            [self removeFile:fileUrl];
        }
    }];
}

- (void)removeLastSegment {
    [self _dispatchSynchronouslyOnSafeQueue:^{
        if (_recordSegments.count > 0) {
            [self removeSegmentAtIndex:_recordSegments.count - 1 deleteFile:YES];
        }
    }];
}

- (void)removeAllSegments {
    [self removeAllSegments:YES];
}

- (void)removeAllSegments:(BOOL)removeFiles {
    [self _dispatchSynchronouslyOnSafeQueue:^{
        while (_recordSegments.count > 0) {
            if (removeFiles) {
                NSURL *fileUrl = [_recordSegments objectAtIndex:0];
                [self removeFile:fileUrl];
            }
            [_recordSegments removeObjectAtIndex:0];
        }
        
        _segmentsDuration = kCMTimeZero;
    }];
}

- (NSString*)_suggestedFileType {
    NSString *fileType = self.fileType;
    
    if (fileType == nil) {
        SCRecorder *recorder = self.recorder;
        if (recorder.videoEnabledAndReady) {
            fileType = AVFileTypeMPEG4;
        } else if (recorder.audioEnabledAndReady) {
            fileType = AVFileTypeAppleM4A;
        }
    }
    
    return fileType;
}

- (NSString *)_suggestedFileExtension {
    NSString *extension = self.fileExtension;
    
    if (extension != nil) {
        return extension;
    }
    
    NSString *fileType = [self _suggestedFileType];
    
    if (fileType == nil) {
        return nil;
    }
    
    if ([fileType isEqualToString:AVFileTypeMPEG4]) {
        return @"mp4";
    } else if ([fileType isEqualToString:AVFileTypeAppleM4A]) {
        return @"m4a";
    } else if ([fileType isEqualToString:AVFileTypeAppleM4V]) {
        return @"m4v";
    } else if ([fileType isEqualToString:AVFileTypeQuickTimeMovie]) {
        return @"mov";
    } else if ([fileType isEqualToString:AVFileTypeWAVE]) {
        return @"wav";
    } else if ([fileType isEqualToString:AVFileTypeMPEGLayer3]) {
        return @"mp3";
    }
    
    return nil;
}

- (AVAssetWriter *)createWriter:(NSError **)error {
    NSError *theError = nil;
    AVAssetWriter *writer = nil;
    
    NSString *fileType = [self _suggestedFileType];
    
    if (fileType != nil) {
        NSString *extension = [self _suggestedFileExtension];
        if (extension != nil) {
            NSString *filename = [NSString stringWithFormat:@"%@SCVideo.%d.%@", _identifier, _currentSegmentCount, extension];
            NSURL *file = [SCRecordSession recordSegmentURLForFilename:filename andDirectory:self.recordSegmentsDirectory];
            
            [self removeFile:file];
            
            writer = [[AVAssetWriter alloc] initWithURL:file fileType:fileType error:&theError];
        } else {
            theError = [SCRecordSession createError:[NSString stringWithFormat:@"Unable to figure out an extension using file type %@", fileType]];
        }
        
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
            //                NSLog(@"Starting session at %fs", CMTimeGetSeconds(_lastTime));
            [writer startSessionAtSourceTime:kCMTimeZero];
            _timeOffset = kCMTimeInvalid;
            //                _sessionStartedTime = _lastTime;
            //                _currentRecordDurationWithoutCurrentSegment = _currentRecordDuration;
            _recordSegmentReady = YES;
        } else {
            theError = writer.error;
            writer = nil;
        }
        
        _currentSegmentCount++;
    }
    
    if (error != nil) {
        *error = theError;
    }
    
    return writer;
}

- (void)uninitialize {
    [self endRecordSegment:nil];

    _audioConfiguration = nil;
    _videoConfiguration = nil;
    _audioInitializationFailed = NO;
    _videoInitializationFailed = NO;
    _videoInput = nil;
    _audioInput = nil;
    _videoPixelBufferAdaptor = nil;
}

- (void)initializeVideo:(NSDictionary *)videoSettings error:(NSError *__autoreleasing *)error {
    NSError *theError = nil;
    @try {
        _videoConfiguration = self.recorder.videoConfiguration;
        _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
        _videoInput.expectsMediaDataInRealTime = YES;
        _videoInput.transform = _videoConfiguration.affineTransform;
        
        SCFilterGroup *filterGroup = _videoConfiguration.filterGroup;
        if (filterGroup != nil) {
            NSDictionary *pixelBufferAttributes = @{
                                                    (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],
                                                    (id)kCVPixelBufferWidthKey : videoSettings[AVVideoWidthKey],
                                                    (id)kCVPixelBufferHeightKey : videoSettings[AVVideoHeightKey]
                                                    };
            
            _videoPixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoInput sourcePixelBufferAttributes:pixelBufferAttributes];
            
            if (_CIContext == nil) {
                NSDictionary *options = @{ kCIContextWorkingColorSpace : [NSNull null], kCIContextOutputColorSpace : [NSNull null] };
                
                _CIContext = [CIContext contextWithEAGLContext:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2] options:options];
            }
        } else {
            _CIContext = nil;
        }
    }
    @catch (NSException *exception) {
        theError = [SCRecordSession createError:exception.reason];
    }
    
    _videoInitializationFailed = theError != nil;
    
    if (error != nil) {
        *error = theError;
    }
}

- (void)initializeAudio:(NSDictionary *)audioSettings error:(NSError *__autoreleasing *)error {
    NSError *theError = nil;
    @try {
        _audioConfiguration = self.recorder.audioConfiguration;
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

- (void)addSegment:(NSURL *)fileUrl {
    AVAsset *asset = [AVAsset assetWithURL:fileUrl];
    CMTime duration = asset.duration;
    
    if (CMTIME_IS_VALID(duration)) {
        [self _addSegment:fileUrl duration:duration];
    } else {
        NSLog(@"Unable to read asset at url %@", fileUrl);
    }
}

- (void)insertSegment:(NSURL *)fileUrl atIndex:(NSInteger)segmentIndex {
    AVAsset *asset = [AVAsset assetWithURL:fileUrl];
    CMTime duration = asset.duration;
    
    if (CMTIME_IS_VALID(duration)) {
        [self _insertSegment:fileUrl atIndex:segmentIndex duration:duration];
    } else {
        NSLog(@"Unable to read asset at url %@", fileUrl);
    }
}

- (void)_addSegment:(NSURL *)fileUrl duration:(CMTime)duration {
    [self _dispatchSynchronouslyOnSafeQueue:^{
        [_recordSegments addObject:fileUrl];
        _segmentsDuration = CMTimeAdd(_segmentsDuration, duration);
    }];
}

- (void)_insertSegment:(NSURL *)fileUrl atIndex:(NSInteger)segmentIndex duration:(CMTime)duration{
    [self _dispatchSynchronouslyOnSafeQueue:^{
        [_recordSegments insertObject:fileUrl atIndex:segmentIndex];
        _segmentsDuration = CMTimeAdd(_segmentsDuration, duration);
    }];
}

//
// The following function is from http://www.gdcl.co.uk/2013/02/20/iPhone-Pause.html
//
- (CMSampleBufferRef)adjustBuffer:(CMSampleBufferRef)sample withTimeOffset:(CMTime)offset andDuration:(CMTime)duration {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo *pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
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
    [self _dispatchSynchronouslyOnSafeQueue:^{
        if (_assetWriter == nil) {
            _assetWriter = [self createWriter:error];
            _currentSegmentHasAudio = NO;
            _currentSegmentHasVideo = NO;
        } else {
            if (error != nil) {
                *error = [SCRecordSession createError:@"A record segment has already began."];
            }
        }
    }];
}

- (void)_destroyAssetWriter {
    _currentSegmentHasAudio = NO;
    _currentSegmentHasVideo = NO;
    _assetWriter = nil;
    _lastTimeAudio = kCMTimeInvalid;
    _currentSegmentDuration = kCMTimeZero;
}

- (void)endRecordSegment:(void(^)(NSInteger segmentNumber, NSError* error))completionHandler {
    [self _dispatchSynchronouslyOnSafeQueue:^{
        if (_recordSegmentReady) {
            _recordSegmentReady = NO;
            
            AVAssetWriter *writer = _assetWriter;
            SCRecorder *recorder = self.recorder;
            
            BOOL currentSegmentEmpty = (!_currentSegmentHasVideo && recorder.videoEnabledAndReady) || (!_currentSegmentHasAudio && recorder.audioEnabledAndReady);
            
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
//                NSLog(@"Ending session at %fs", CMTimeGetSeconds(_currentSegmentDuration));
                [writer endSessionAtSourceTime:_currentSegmentDuration];
                
                [writer finishWritingWithCompletionHandler: ^{
                    [self _dispatchSynchronouslyOnSafeQueue:^{
                        NSInteger segmentNumber = -1;
                        
                        if (writer.error == nil) {
                            segmentNumber = _recordSegments.count;
                            [self _addSegment:writer.outputURL duration:_currentSegmentDuration];
                        }
                        
                        [self _destroyAssetWriter];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (completionHandler != nil) {
                                completionHandler(segmentNumber, writer.error);
                            }
                        });
                    }];
                    
                }];
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandler != nil) {
                    completionHandler(-1, [SCRecordSession createError:@"The current record segment is not ready for this operation"]);
                }
            });
        }
    }];
}

- (void)mergeRecordSegmentsUsingPreset:(NSString *)exportSessionPreset completionHandler:(void(^)(NSURL *outputUrl, NSError *error))completionHandler {
    [self _dispatchSynchronouslyOnSafeQueue:^{
        NSString *fileType = [self _suggestedFileType];
        
        if (fileType == nil) {
            if (completionHandler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(nil, [SCRecordSession createError:@"No output fileType was set"]);
                });
            }
            return;
        }
        
        NSString *fileExtension = [self _suggestedFileExtension];
        if (fileExtension == nil) {
            if (completionHandler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(nil, [SCRecordSession createError:@"Unable to figure out a file extension"]);
                });
            }
            return;
        }
        
        NSString *filename = [NSString stringWithFormat:@"%@SCVideo-Merged.%@", _identifier, fileExtension];
        NSURL *outputUrl = [SCRecordSession recordSegmentURLForFilename:filename andDirectory:_recordSegmentsDirectory];
        [self removeFile:outputUrl];

        if (_recordSegments.count == 0) {
            if (completionHandler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(nil, [SCRecordSession createError:@"The session does not contains any record segment"]);
                });
            }
        } else {
            AVAsset *asset = [self assetRepresentingRecordSegments];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:exportSessionPreset];
                exportSession.outputURL = outputUrl;
                exportSession.outputFileType = fileType;
                exportSession.shouldOptimizeForNetworkUse = YES;
                [exportSession exportAsynchronouslyWithCompletionHandler:^{
                    NSError *error = exportSession.error;
                    
                    if (completionHandler != nil) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completionHandler(outputUrl, error);
                        });
                    }
                }];
            });

        }
    }];
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
    [self _dispatchSynchronouslyOnSafeQueue:^{
        if (_assetWriter == nil) {
            [self removeAllSegments];
            if (completionHandler != nil) {
                completionHandler();
            }
        } else {
            [self endRecordSegment:^(NSInteger segmentIndex, NSError *error) {
                [self removeAllSegments];
                if (completionHandler != nil) {
                    completionHandler();
                }
            }];
        }
    }];
}

- (BOOL)appendAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer {
    if ([_audioInput isReadyForMoreMediaData]) {
        CMTime actualBufferTime = CMSampleBufferGetPresentationTimeStamp(audioSampleBuffer);
        
        if (CMTIME_IS_INVALID(_timeOffset)) {
            _timeOffset = CMTimeSubtract(actualBufferTime, _currentSegmentDuration);
        }
        
        CMTime duration = CMSampleBufferGetDuration(audioSampleBuffer);
        CMSampleBufferRef adjustedBuffer = [self adjustBuffer:audioSampleBuffer withTimeOffset:_timeOffset andDuration:duration];
        
        CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(adjustedBuffer);
        CMTime lastTimeAudio = CMTimeAdd(presentationTime, duration);
        
        if (CMTIME_COMPARE_INLINE(presentationTime, >=, kCMTimeZero)) {
            _lastTimeAudio = lastTimeAudio;
            
            if (!_currentSegmentHasVideo) {
                _currentSegmentDuration = lastTimeAudio;
            }
            
            [_audioInput appendSampleBuffer:adjustedBuffer];
            _currentSegmentHasAudio = YES;
        }
        
        CFRelease(adjustedBuffer);
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)appendVideoSampleBuffer:(CMSampleBufferRef)videoSampleBuffer duration:(CMTime)duration {
    if ([_videoInput isReadyForMoreMediaData]) {
        CMTime actualBufferTime = CMSampleBufferGetPresentationTimeStamp(videoSampleBuffer);
        
        if (CMTIME_IS_INVALID(_timeOffset)) {
            _timeOffset = CMTimeSubtract(actualBufferTime, _currentSegmentDuration);
//            NSLog(@"Recomputed time offset to: %fs", CMTimeGetSeconds(_timeOffset));
        }
        
        CGFloat videoTimeScale = _videoConfiguration.timeScale;
        if (videoTimeScale != 1.0) {
            CMTime computedFrameDuration = CMTimeMultiplyByFloat64(duration, videoTimeScale);
            if (_currentSegmentDuration.value > 0) {
                _timeOffset = CMTimeAdd(_timeOffset, CMTimeSubtract(duration, computedFrameDuration));
            }
            duration = computedFrameDuration;
        }
        
        CMTime bufferTimestamp = CMTimeSubtract(actualBufferTime, _timeOffset);
        
        if (_videoPixelBufferAdaptor != nil) {
            CIImage *image = [CIImage imageWithCVPixelBuffer:CMSampleBufferGetImageBuffer(videoSampleBuffer)];
            
            CIImage *result = [_videoConfiguration.filterGroup imageByProcessingImage:image];
            
            CVPixelBufferRef outputPixelBuffer = nil;
            CVPixelBufferPoolCreatePixelBuffer(NULL, [_videoPixelBufferAdaptor pixelBufferPool], &outputPixelBuffer);
            
            CVPixelBufferLockBaseAddress(outputPixelBuffer, 0);
            
            [_CIContext render:result toCVPixelBuffer:outputPixelBuffer];
            
            [_videoPixelBufferAdaptor appendPixelBuffer:outputPixelBuffer withPresentationTime:bufferTimestamp];
            
            CVPixelBufferUnlockBaseAddress(outputPixelBuffer, 0);
            
            CVPixelBufferRelease(outputPixelBuffer);
        } else {
            CMSampleTimingInfo timingInfo = {0,};
            timingInfo.duration = kCMTimeInvalid;
            timingInfo.decodeTimeStamp = kCMTimeInvalid;
            timingInfo.presentationTimeStamp = bufferTimestamp;

            CMSampleBufferRef adjustedBuffer = nil;
            
            CMSampleBufferCreateCopyWithNewTiming(nil, videoSampleBuffer, 1, &timingInfo, &adjustedBuffer);
            
            [_videoInput appendSampleBuffer:adjustedBuffer];

            CFRelease(adjustedBuffer);
        }

        _currentSegmentDuration = CMTimeAdd(bufferTimestamp, duration);
        
        _currentSegmentHasVideo = YES;

        return YES;
    } else {
        return NO;
    }
}

- (CMTime)_appendTrack:(AVAssetTrack *)track toCompositionTrack:(AVMutableCompositionTrack *)compositionTrack atTime:(CMTime)time withBounds:(CMTime)bounds {
    CMTimeRange timeRange = track.timeRange;
    time = CMTimeAdd(time, timeRange.start);
    
    if (CMTIME_IS_VALID(bounds)) {
        CMTime currentBounds = CMTimeAdd(time, timeRange.duration);

        if (CMTIME_COMPARE_INLINE(currentBounds, >, bounds)) {
            timeRange = CMTimeRangeMake(timeRange.start, CMTimeSubtract(timeRange.duration, CMTimeSubtract(currentBounds, bounds)));
        }
    }
    
    if (CMTIME_COMPARE_INLINE(timeRange.duration, >, kCMTimeZero)) {
        NSError *error = nil;
        [compositionTrack insertTimeRange:timeRange ofTrack:track atTime:time error:&error];
        
        if (error != nil) {
            NSLog(@"Failed to insert append %@ track: %@", compositionTrack.mediaType, error);
        } else {
            //        NSLog(@"Inserted %@ at %fs (%fs -> %fs)", track.mediaType, CMTimeGetSeconds(time), CMTimeGetSeconds(timeRange.start), CMTimeGetSeconds(timeRange.duration));
        }
        
        return CMTimeAdd(time, timeRange.duration);
    }
    
    return time;
}

- (AVAsset *)assetRepresentingRecordSegments {
    __block AVAsset *asset = nil;
    [self _dispatchSynchronouslyOnSafeQueue:^{
        if (_recordSegments.count == 1) {
            asset = [AVAsset assetWithURL:_recordSegments.firstObject];
        } else {
            AVMutableComposition *composition = [AVMutableComposition composition];
            AVMutableCompositionTrack *audioTrack = nil;
            AVMutableCompositionTrack *videoTrack = nil;
            
            NSDictionary *options = @{ AVURLAssetPreferPreciseDurationAndTimingKey : @YES };
            int currentSegment = 0;
            CMTime currentTime = kCMTimeZero;
            for (NSURL *recordSegment in _recordSegments) {
                AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:recordSegment options:options];
                
                NSArray *audioAssetTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
                NSArray *videoAssetTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
                
                CMTime maxBounds = kCMTimeInvalid;
                
                CMTime videoTime = currentTime;
                for (AVAssetTrack *videoAssetTrack in videoAssetTracks) {
                    if (videoTrack == nil) {
                        videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
                    }
                    
                    videoTime = [self _appendTrack:videoAssetTrack toCompositionTrack:videoTrack atTime:videoTime withBounds:maxBounds];
                    maxBounds = videoTime;
                }
                
                CMTime audioTime = currentTime;
                for (AVAssetTrack *audioAssetTrack in audioAssetTracks) {
                    if (audioTrack == nil) {
                        audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                    }
              
                    audioTime = [self _appendTrack:audioAssetTrack toCompositionTrack:audioTrack atTime:audioTime withBounds:maxBounds];
                }
                
                currentTime = composition.duration;
                
                currentSegment++;
            }
            asset = composition;
        }
    }];

    return asset;
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

- (BOOL)currentSegmentHasVideo {
    return _currentSegmentHasVideo;
}

- (BOOL)currentSegmentHasAudio {
    return _currentSegmentHasAudio;
}

- (CMTime)currentRecordDuration {
    return CMTimeAdd(_segmentsDuration, _currentSegmentDuration);
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *recordSegments = [NSMutableArray array];
    
    for (NSURL *recordSegment in self.recordSegments) {
        [recordSegments addObject:recordSegment.lastPathComponent];
    }
    
    return @{
             SCRecordSessionSegmentFilenamesKey: recordSegments,
             SCRecordSessionDurationKey : [NSNumber numberWithDouble:CMTimeGetSeconds(_segmentsDuration)],
             SCRecordSessionIdentifierKey : _identifier,
             SCRecordSessionDateKey : _date,             
             SCRecordSessionDirectoryKey : _recordSegmentsDirectory
             };
}

- (NSURL *)outputUrl {
    NSString *fileType = [self _suggestedFileType];
    
    if (fileType == nil) {
        return nil;
    }
    
    NSString *fileExtension = [self _suggestedFileExtension];
    if (fileExtension == nil) {
        return nil;
    }
    
    NSString *filename = [NSString stringWithFormat:@"%@SCVideo-Merged.%@", _identifier, fileExtension];
    
    return [SCRecordSession recordSegmentURLForFilename:filename andDirectory:_recordSegmentsDirectory];
}

@end
