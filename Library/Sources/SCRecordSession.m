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

#pragma mark - Private definition

NSString * const SCRecordSessionSegmentFilenamesKey = @"RecordSegmentFilenames";
NSString * const SCRecordSessionSegmentsKey = @"Segments";
NSString * const SCRecordSessionSegmentFilenameKey = @"Filename";
NSString * const SCRecordSessionSegmentInfoKey = @"Info";

NSString * const SCRecordSessionDurationKey = @"Duration";
NSString * const SCRecordSessionIdentifierKey = @"Identifier";
NSString * const SCRecordSessionDateKey = @"Date";
NSString * const SCRecordSessionDirectoryKey = @"Directory";

NSString * const SCRecordSessionTemporaryDirectory = @"TemporaryDirectory";
NSString * const SCRecordSessionCacheDirectory = @"CacheDirectory";
NSString * const SCRecordSessionDocumentDirectory = @"DocumentDirectory";

@implementation SCRecordSession

- (id)initWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation {
    self = [self init];

    if (self) {
        NSString *directory = dictionaryRepresentation[SCRecordSessionDirectoryKey];
        if (directory != nil) {
            _segmentsDirectory = directory;
        }

        NSArray *recordSegments = [dictionaryRepresentation objectForKey:SCRecordSessionSegmentFilenamesKey];

        BOOL shouldRecomputeDuration = NO;

        // OLD WAY
        for (NSObject *recordSegment in recordSegments) {
            NSString *filename = nil;
            NSDictionary *info = nil;
            if ([recordSegment isKindOfClass:[NSDictionary class]]) {
                filename = ((NSDictionary *)recordSegment)[SCRecordSessionSegmentFilenameKey];
                info = ((NSDictionary *)recordSegment)[SCRecordSessionSegmentInfoKey];
            } else if ([recordSegment isKindOfClass:[NSString class]]) {
                // EVEN OLDER WAY
                filename = (NSString *)recordSegment;
            }

            NSURL *url = [SCRecordSessionSegment segmentURLForFilename:filename andDirectory:_segmentsDirectory];

            if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
                [_segments addObject:[SCRecordSessionSegment segmentWithURL:url info:info]];
            } else {
                NSLog(@"Skipping record segment %@: File does not exist", url);
                shouldRecomputeDuration = YES;
            }
        }

        // NEW WAY
        NSArray *segments = [dictionaryRepresentation objectForKey:SCRecordSessionSegmentsKey];
        for (NSDictionary *segmentDictRepresentation in segments) {
            SCRecordSessionSegment *segment = [[SCRecordSessionSegment alloc] initWithDictionaryRepresentation:segmentDictRepresentation directory:_segmentsDirectory];

            if (segment.fileUrlExists) {
                [_segments addObject:segment];
            } else {
                NSLog(@"Skipping record segment %@: File does not exist", segment.url);
                shouldRecomputeDuration = YES;
            }
        }


        _currentSegmentCount = (int)_segments.count;

        NSNumber *recordDuration = [dictionaryRepresentation objectForKey:SCRecordSessionDurationKey];
        if (recordDuration != nil) {
            _segmentsDuration = CMTimeMakeWithSeconds(recordDuration.doubleValue, 10000);
        } else {
            shouldRecomputeDuration = YES;
        }

        if (shouldRecomputeDuration) {
            _segmentsDuration = self.assetRepresentingSegments.duration;

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
        _segments = [[NSMutableArray alloc] init];

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
        _segmentsDirectory = SCRecordSessionTemporaryDirectory;
        _identifier = [NSString stringWithFormat:@"%@-", [SCRecordSession newIdentifier:12]];
        _audioQueue = dispatch_queue_create("me.corsin.SCRecorder.Audio", nil);
    }

    return self;
}


+ (NSString *)newIdentifier:(NSUInteger)length {
    static NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    NSMutableString *randomString = [NSMutableString stringWithCapacity:length];

    for (int i = 0; i < length; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform((u_int32_t)[letters length])]];
    }

    return randomString;
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

- (void)dispatchSyncOnSessionQueue:(void(^)(void))block {
    SCRecorder *recorder = self.recorder;

	block = [block copy];
    if (recorder == nil || [SCRecorder isSessionQueue]) {
        block();
    } else {
        dispatch_sync(recorder.sessionQueue, block);
    }
}

- (void)removeFile:(NSURL *)fileUrl {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:fileUrl.path error:&error];
}

- (void)removeSegment:(SCRecordSessionSegment *)segment {
	__weak typeof(self) wSelf = self;
    [self dispatchSyncOnSessionQueue:^{
        NSUInteger index = [wSelf.segments indexOfObject:segment];
        if (index != NSNotFound) {
            [wSelf removeSegmentAtIndex:index deleteFile:NO];
        }
    }];
}

- (void)removeSegmentAtIndex:(NSInteger)segmentIndex deleteFile:(BOOL)deleteFile {
	__weak typeof(self) wSelf = self;
    [self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        SCRecordSessionSegment *segment = [iSelf->_segments objectAtIndex:segmentIndex];
        [iSelf->_segments removeObjectAtIndex:segmentIndex];

        CMTime segmentDuration = segment.duration;

        if (CMTIME_IS_VALID(segmentDuration)) {
//            NSLog(@"Removed duration of %fs", CMTimeGetSeconds(segmentDuration));
            wSelf.segmentsDuration = CMTimeSubtract(iSelf->_segmentsDuration, segmentDuration);
        } else {
            CMTime newDuration = kCMTimeZero;
            for (SCRecordSessionSegment *segment in wSelf.segments) {
                if (CMTIME_IS_VALID(segment.duration)) {
                    newDuration = CMTimeAdd(newDuration, segment.duration);
                }
            }
            iSelf->_segmentsDuration = newDuration;
        }

        if (deleteFile) {
            [segment deleteFile];
        }
    }];
}

- (void)removeLastSegment {
	__weak typeof(self) wSelf = self;
    [self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        if (iSelf->_segments.count > 0) {
            [self removeSegmentAtIndex:iSelf->_segments.count - 1 deleteFile:YES];
        }
    }];
}

- (void)removeAllSegments:(void(^ __nullable)(void))completionHandler {
    [self removeAllSegments:YES
          withCompletion:completionHandler];
}

- (void)removeAllSegments:(BOOL)removeFiles
           withCompletion:(void(^ __nullable)(void))completionHandler;{
	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
		while (iSelf->_segments.count > 0) {
			if (removeFiles) {
				SCRecordSessionSegment *segment = [iSelf->_segments objectAtIndex:0];
				[segment deleteFile];
			}
			[iSelf->_segments removeObjectAtIndex:0];
		}

		iSelf->_segmentsDuration = kCMTimeZero;

		if (completionHandler) {
			completionHandler();
		}
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

- (NSURL *)nextFileURL:(NSError **)error {
    NSString *extension = [self _suggestedFileExtension];

    if (extension != nil) {
        NSString *filename = [NSString stringWithFormat:@"%@SCVideo.%d.%@", _identifier, _currentSegmentCount, extension];
        NSURL *file = [SCRecordSessionSegment segmentURLForFilename:filename andDirectory:self.segmentsDirectory];

        [self removeFile:file];

        _currentSegmentCount++;

        return file;

    } else {
        if (error != nil) {
            *error = [SCRecordSession createError:[NSString stringWithFormat:@"Unable to find an extension"]];
        }

        return nil;
    }
}

- (AVAssetWriter *)createWriter:(NSError **)error {
    NSError *theError = nil;
    AVAssetWriter *writer = nil;

    NSString *fileType = [self _suggestedFileType];

    if (fileType != nil) {
        NSURL *file = [self nextFileURL:&theError];

        if (file != nil) {
            writer = [[AVAssetWriter alloc] initWithURL:file fileType:fileType error:&theError];
            writer.metadata = [SCRecorderTools assetWriterMetadata];
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
            _timeOffset = kCMTimeZero;
            _sessionStartTime = kCMTimeInvalid;
            //                _sessionStartedTime = _lastTime;
            //                _currentRecordDurationWithoutCurrentSegment = _currentRecordDuration;
            _recordSegmentReady = YES;
        } else {
            theError = writer.error;
            writer = nil;
        }
    }

    if (error != nil) {
        *error = theError;
    }

    return writer;
}

- (void)deinitialize {
	__weak typeof(self) wSelf = self;
    [self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        [self endSegmentWithInfo:nil completionHandler:nil];

        iSelf->_audioConfiguration = nil;
        iSelf->_videoConfiguration = nil;
        iSelf->_audioInitializationFailed = NO;
        iSelf->_videoInitializationFailed = NO;
        iSelf->_videoInput = nil;
        iSelf->_audioInput = nil;
        iSelf->_videoPixelBufferAdaptor = nil;
    }];
}

- (void)initializeVideo:(NSDictionary *)videoSettings formatDescription:(CMFormatDescriptionRef)formatDescription error:(NSError *__autoreleasing *)error {
    NSError *theError = nil;
    @try {
        _videoConfiguration = self.recorder.videoConfiguration;
        _videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings sourceFormatHint:formatDescription];
        _videoInput.expectsMediaDataInRealTime = YES;
        _videoInput.transform = _videoConfiguration.affineTransform;

        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);

        NSDictionary *pixelBufferAttributes = @{
                (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
                (id)kCVPixelBufferWidthKey : @(dimensions.width),
                (id)kCVPixelBufferHeightKey : @(dimensions.height)
        };

        _videoPixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoInput sourcePixelBufferAttributes:pixelBufferAttributes];
    } @catch (NSException *exception) {
        theError = [SCRecordSession createError:exception.reason];
    }

    _videoInitializationFailed = theError != nil;

    if (error != nil) {
        *error = theError;
    }
}

- (void)initializeAudio:(NSDictionary *)audioSettings formatDescription:(CMFormatDescriptionRef)formatDescription error:(NSError *__autoreleasing *)error {
    NSError *theError = nil;
    @try {
        _audioConfiguration = self.recorder.audioConfiguration;
        _audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings sourceFormatHint:formatDescription];
        _audioInput.expectsMediaDataInRealTime = YES;
    } @catch (NSException *exception) {
        theError = [SCRecordSession createError:exception.reason];
    }

    _audioInitializationFailed = theError != nil;

    if (error != nil) {
        *error = theError;
    }
}

- (void)addSegment:(SCRecordSessionSegment *)segment {
	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        [iSelf->_segments addObject:segment];
        iSelf->_segmentsDuration = CMTimeAdd(iSelf->_segmentsDuration, segment.duration);
    }];
}

- (void)insertSegment:(SCRecordSessionSegment *)segment atIndex:(NSInteger)segmentIndex {
	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        [iSelf->_segments insertObject:segment atIndex:segmentIndex];
        iSelf->_segmentsDuration = CMTimeAdd(iSelf->_segmentsDuration, segment.duration);
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

- (void)beginSegment:(NSError**)error {
	__block NSError* localError;
	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        if (iSelf->_assetWriter == nil) {
            iSelf->_assetWriter = [iSelf createWriter:&localError];
            iSelf->_currentSegmentDuration = kCMTimeZero;
            iSelf->_currentSegmentHasAudio = NO;
            iSelf->_currentSegmentHasVideo = NO;
        } else {
			localError = [SCRecordSession createError:@"A record segment has already began."];
        }
    }];
	if (error) *error = localError;
}

- (void)_destroyAssetWriter {
    _currentSegmentHasAudio = NO;
    _currentSegmentHasVideo = NO;
    _assetWriter = nil;
    _lastTimeAudio = kCMTimeInvalid;
    _lastTimeVideo = kCMTimeInvalid;
    _currentSegmentDuration = kCMTimeZero;
    _sessionStartTime = kCMTimeInvalid;
    _movieFileOutput = nil;
}

- (void)appendRecordSegmentUrl:(NSURL *)url info:(NSDictionary *)info error:(NSError *)error completionHandler:(void (^)(SCRecordSessionSegment *, NSError *))completionHandler {
	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        SCRecordSessionSegment *segment = nil;

        if (error == nil) {
            segment = [SCRecordSessionSegment segmentWithURL:url info:info];
            [iSelf addSegment:segment];
        }

        [iSelf _destroyAssetWriter];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler != nil) {
                completionHandler(segment, error);
            }
        });
    }];
}

- (BOOL)endSegmentWithInfo:(NSDictionary *)info completionHandler:(void(^)(SCRecordSessionSegment *segment, NSError* error))completionHandler {
    __block BOOL success = NO;

	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
//        dispatch_sync(iSelf->_audioQueue, ^{
            if (iSelf->_recordSegmentReady) {
                iSelf->_recordSegmentReady = NO;
                success = YES;

                AVAssetWriter *writer = iSelf->_assetWriter;

                if (writer != nil) {
                    BOOL currentSegmentEmpty = (!iSelf->_currentSegmentHasVideo && !iSelf->_currentSegmentHasAudio);

                    if (currentSegmentEmpty) {
                        [writer cancelWriting];
                        [iSelf _destroyAssetWriter];

                        [iSelf removeFile:writer.outputURL];

                        if (completionHandler != nil) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completionHandler(nil, nil);
                            });
                        }
                    } else {
                        //                NSLog(@"Ending session at %fs", CMTimeGetSeconds(_currentSegmentDuration));
                        [writer endSessionAtSourceTime:CMTimeAdd(iSelf->_currentSegmentDuration, iSelf->_sessionStartTime)];

                        [writer finishWritingWithCompletionHandler: ^{
                            [iSelf appendRecordSegmentUrl:writer.outputURL info:info error:writer.error completionHandler:completionHandler];
                        }];
                    }
                } else {
                    [iSelf->_movieFileOutput stopRecording];
                }
			} else {
				if (completionHandler != nil) {
					dispatch_async(dispatch_get_main_queue(), ^{
						completionHandler(nil, [SCRecordSession createError:@"The current record segment is not ready for this operation"]);
					});
				}
			}
//        });
    }];

    return success;
}

- (void)notifyMovieFileOutputIsReady {
    _recordSegmentReady = YES;
}

- (void)beginRecordSegmentUsingMovieFileOutput:(AVCaptureMovieFileOutput *)movieFileOutput error:(NSError *__autoreleasing *)error delegate:(id<AVCaptureFileOutputRecordingDelegate>)delegate {
    NSURL *url = [self nextFileURL:error];

    if (url != nil) {
        _movieFileOutput = movieFileOutput;
        _movieFileOutput.metadata = [SCRecorderTools assetWriterMetadata];

        if (movieFileOutput.isRecording) {
            [NSException raise:@"AlreadyRecordingException" format:@"The MovieFileOutput is already recording"];
        }

        _recordSegmentReady = NO;
        [movieFileOutput startRecordingToOutputFileURL:url recordingDelegate:delegate];
    }
}

- (AVAssetExportSession *)mergeSegmentsUsingPreset:(NSString *)exportSessionPreset completionHandler:(void(^)(NSURL *outputUrl, NSError *error))completionHandler {
    __block AVAsset *asset = nil;
    __block NSError *error = nil;
    __block NSString *fileType = nil;
    __block NSURL *outputUrl = nil;

	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        fileType = [self _suggestedFileType];

        if (fileType == nil) {
            error = [SCRecordSession createError:@"No output fileType was set"];
            return;
        }

        NSString *fileExtension = [self _suggestedFileExtension];
        if (fileExtension == nil) {
            error = [SCRecordSession createError:@"Unable to figure out a file extension"];
            return;
        }

        NSString *filename = [NSString stringWithFormat:@"%@SCVideo-Merged.%@", iSelf->_identifier, fileExtension];
        outputUrl = [SCRecordSessionSegment segmentURLForFilename:filename andDirectory:iSelf->_segmentsDirectory];
        [self removeFile:outputUrl];

        if (iSelf->_segments.count == 0) {
            error = [SCRecordSession createError:@"The session does not contains any record segment"];
        } else {
            asset = [self assetRepresentingSegments];
        }
    }];

    if (error != nil) {
        if (completionHandler != nil) {
            completionHandler(nil, error);
        }

        return nil;
    } else {
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

        return exportSession;

    }
}

- (AVAssetExportSession *)mergeSegmentsUsingPreset:(NSString *)exportSessionPreset
                                             atURL:(NSURL *)url
                                 completionHandler:(void(^)(NSURL *outputUrl, NSError *error))completionHandler {
    __block AVAsset *asset = nil;
    __block NSError *error = nil;
    __block NSString *fileType = nil;
    __block NSURL *outputUrl = url;

	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        fileType = [iSelf _suggestedFileType];

        if (fileType == nil) {
            error = [SCRecordSession createError:@"No output fileType was set"];
            return;
        }

        [iSelf removeFile:outputUrl];

        if (iSelf->_segments.count == 0) {
            error = [SCRecordSession createError:@"The session does not contains any record segment"];
        } else {
            asset = [iSelf assetRepresentingSegments];
        }
    }];

    if (error != nil) {
        if (completionHandler != nil) {
            completionHandler(nil, error);
        }

        return nil;
    } else {
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

        return exportSession;

    }
}

- (void)finishEndSession:(NSError*)mergeError completionHandler:(void (^)(NSError *))completionHandler {
    if (mergeError == nil) {
        [self removeAllSegments:nil];
        if (completionHandler != nil) {
            completionHandler(nil);
        }
    } else {
        if (completionHandler != nil) {
            completionHandler(mergeError);
        }
    }
}

- (void)cancelSession:(void (^)(void))completionHandler {
	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        if (iSelf->_assetWriter == nil) {
            [iSelf removeAllSegments:nil];
			if (completionHandler != nil) {
				dispatch_async(dispatch_get_main_queue(), ^{
					completionHandler();
				});
			}
        } else {
            [iSelf endSegmentWithInfo:nil completionHandler:^(SCRecordSessionSegment *segment, NSError *error) {
                [iSelf removeAllSegments:nil];
                if (completionHandler != nil) {
					dispatch_async(dispatch_get_main_queue(), ^{
						completionHandler();
					});
                }
            }];
        }
    }];
}

- (CVPixelBufferRef)createPixelBuffer {
    CVPixelBufferRef outputPixelBuffer = nil;
    CVReturn ret = CVPixelBufferPoolCreatePixelBuffer(NULL, [_videoPixelBufferAdaptor pixelBufferPool], &outputPixelBuffer);

    if (ret != kCVReturnSuccess) {
        NSLog(@"UNABLE TO CREATE PIXEL BUFFER (CVReturnError: %d)", ret);
    }

    return outputPixelBuffer;
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer completion:(void (^)(BOOL))completion {
    [self _startSessionIfNeededAtTime:CMSampleBufferGetPresentationTimeStamp(audioSampleBuffer)];

    CMTime duration = CMSampleBufferGetDuration(audioSampleBuffer);
    /* Removed call to adjustBuffer - it was causing video/audio sync
     * super fucking annoying - not sure why its happening but removing it fixed it so im happy with that
     * GabeRoze
     * */
//    CMSampleBufferRef adjustedBuffer = [self adjustBuffer:audioSampleBuffer withTimeOffset:_timeOffset andDuration:duration];
    CMSampleBufferRef adjustedBuffer;
    CMSampleBufferCreateCopy(kCFAllocatorDefault, audioSampleBuffer, &adjustedBuffer);

    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(adjustedBuffer);
    CMTime lastTimeAudio = CMTimeAdd(presentationTime, duration);
	__weak typeof(self) wSelf = self;
    dispatch_async(_audioQueue, ^{
		typeof(self) iSelf = wSelf;
        if ([iSelf->_audioInput isReadyForMoreMediaData] && [iSelf->_audioInput appendSampleBuffer:adjustedBuffer]) {
            iSelf->_lastTimeAudio = lastTimeAudio;

            if (!iSelf->_currentSegmentHasVideo) {
                iSelf->_currentSegmentDuration = CMTimeSubtract(lastTimeAudio, iSelf->_sessionStartTime);
            }

            //            NSLog(@"Appending audio at %fs (buffer: %fs)", CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(adjustedBuffer)), CMTimeGetSeconds(actualBufferTime));
            iSelf->_currentSegmentHasAudio = YES;

            completion(YES);
        } else {
            completion(NO);
        }

        CFRelease(adjustedBuffer);
    });
}

- (void)_startSessionIfNeededAtTime:(CMTime)time
{
    if (CMTIME_IS_INVALID(_sessionStartTime)) {
        _sessionStartTime = time;
        [_assetWriter startSessionAtSourceTime:time];
    }
}

- (void)appendVideoPixelBuffer:(CVPixelBufferRef)videoPixelBuffer atTime:(CMTime)actualBufferTime duration:(CMTime)duration completion:(void (^)(BOOL))completion {
    [self _startSessionIfNeededAtTime:actualBufferTime];

    CMTime bufferTimestamp = CMTimeSubtract(actualBufferTime, _timeOffset);

    CGFloat videoTimeScale = _videoConfiguration.timeScale;
    if (videoTimeScale != 1.0) {
        CMTime computedFrameDuration = CMTimeMultiplyByFloat64(duration, videoTimeScale);
        if (_currentSegmentDuration.value > 0) {
            _timeOffset = CMTimeAdd(_timeOffset, CMTimeSubtract(duration, computedFrameDuration));
        }
        duration = computedFrameDuration;
    }

    //    CMTime timeVideo = _lastTimeVideo;
    //    CMTime actualBufferDuration = duration;
    //
    //    if (CMTIME_IS_VALID(timeVideo)) {
    //        while (CMTIME_COMPARE_INLINE(CMTimeSubtract(actualBufferTime, timeVideo), >=, CMTimeMultiply(actualBufferDuration, 2))) {
    //            NSLog(@"Missing buffer");
    //            timeVideo = CMTimeAdd(timeVideo, actualBufferDuration);
    //        }
    //    }

    if ([_videoInput isReadyForMoreMediaData]) {
        if ([_videoPixelBufferAdaptor appendPixelBuffer:videoPixelBuffer withPresentationTime:bufferTimestamp]) {
            _currentSegmentDuration = CMTimeSubtract(CMTimeAdd(bufferTimestamp, duration), _sessionStartTime);
            _lastTimeVideo = actualBufferTime;

            _currentSegmentHasVideo = YES;
            completion(YES);
        } else {
            NSLog(@"Failed to append buffer");
            completion(NO);
        }
    } else {
        completion(NO);
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

- (void)appendSegmentsToComposition:(AVMutableComposition * __nonnull)composition {
    [self appendSegmentsToComposition:composition audioMix:nil];
}

- (void)appendSegmentsToComposition:(AVMutableComposition *)composition audioMix:(AVMutableAudioMix *)audioMix {
	__weak typeof(self) wSelf = self;
    [self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        AVMutableCompositionTrack *audioTrack = nil;
        AVMutableCompositionTrack *videoTrack = nil;

        int currentSegment = 0;
        CMTime currentTime = composition.duration;
        for (SCRecordSessionSegment *recordSegment in iSelf->_segments) {
            AVAsset *asset = recordSegment.asset;

            NSArray *audioAssetTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
            NSArray *videoAssetTracks = [asset tracksWithMediaType:AVMediaTypeVideo];

            CMTime maxBounds = kCMTimeInvalid;

            CMTime videoTime = currentTime;
            for (AVAssetTrack *videoAssetTrack in videoAssetTracks) {
                if (videoTrack == nil) {
                    NSArray *videoTracks = [composition tracksWithMediaType:AVMediaTypeVideo];

                    if (videoTracks.count > 0) {
                        videoTrack = [videoTracks firstObject];
                    } else {
                        videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
                        videoTrack.preferredTransform = videoAssetTrack.preferredTransform;
                    }
                }

                videoTime = [iSelf _appendTrack:videoAssetTrack toCompositionTrack:videoTrack atTime:videoTime withBounds:maxBounds];
                maxBounds = videoTime;
            }

            CMTime audioTime = currentTime;
            for (AVAssetTrack *audioAssetTrack in audioAssetTracks) {
                if (audioTrack == nil) {
                    NSArray *audioTracks = [composition tracksWithMediaType:AVMediaTypeAudio];

                    if (audioTracks.count > 0) {
                        audioTrack = [audioTracks firstObject];
                    } else {
                        audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                    }
                }

                audioTime = [iSelf _appendTrack:audioAssetTrack toCompositionTrack:audioTrack atTime:audioTime withBounds:maxBounds];
            }

            currentTime = composition.duration;

            currentSegment++;
        }
    }];
}

- (AVPlayerItem *)playerItemRepresentingSegments {
    __block AVPlayerItem *playerItem = nil;
	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        if (iSelf->_segments.count == 1) {
            SCRecordSessionSegment *segment = iSelf->_segments.firstObject;
            playerItem = [AVPlayerItem playerItemWithAsset:segment.asset];
        } else {
            AVMutableComposition *composition = [AVMutableComposition composition];
            [iSelf appendSegmentsToComposition:composition];

            playerItem = [AVPlayerItem playerItemWithAsset:composition];
        }
    }];

    return playerItem;
}

- (AVAsset *)assetRepresentingSegments {
    __block AVAsset *asset = nil;
	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        if (iSelf->_segments.count == 1) {
            SCRecordSessionSegment *segment = iSelf->_segments.firstObject;
            asset = segment.asset;
        } else {
            AVMutableComposition *composition = [AVMutableComposition composition];
            [self appendSegmentsToComposition:composition];

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
    return _assetWriter != nil || _movieFileOutput != nil;
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

- (CMTime)currentSegmentDuration {
    return _movieFileOutput.isRecording ? _movieFileOutput.recordedDuration : _currentSegmentDuration;
}

- (CMTime)duration {
    return CMTimeAdd(_segmentsDuration, [self currentSegmentDuration]);
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *recordSegments = [NSMutableArray array];

    for (SCRecordSessionSegment *recordSegment in self.segments) {
        [recordSegments addObject:recordSegment.dictionaryRepresentation];
    }

    return @{
            SCRecordSessionSegmentsKey: recordSegments,
            SCRecordSessionDurationKey : [NSNumber numberWithDouble:CMTimeGetSeconds(_segmentsDuration)],
            SCRecordSessionIdentifierKey : _identifier,
            SCRecordSessionDateKey : _date,
            SCRecordSessionDirectoryKey : _segmentsDirectory
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

    return [SCRecordSessionSegment segmentURLForFilename:filename andDirectory:_segmentsDirectory];
}

- (void)setSegmentsDirectory:(NSString *)segmentsDirectory {
    _segmentsDirectory = [segmentsDirectory copy];

	__weak typeof(self) wSelf = self;
	[self dispatchSyncOnSessionQueue:^{
		typeof(self) iSelf = wSelf;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        for (SCRecordSessionSegment *recordSegment in iSelf.segments) {
            NSURL *newUrl = [SCRecordSessionSegment segmentURLForFilename:recordSegment.url.lastPathComponent andDirectory:iSelf->_segmentsDirectory];

            if (![newUrl isEqual:recordSegment.url]) {
                NSError *error = nil;
                if ([fileManager moveItemAtURL:recordSegment.url toURL:newUrl error:&error]) {
                    recordSegment.url = newUrl;
                } else {
                    NSLog(@"Unable to change segmentsDirectory for segment %@: %@", recordSegment.url, error.localizedDescription);
                }
            }
        }
    }];
}

- (BOOL)isUsingMovieFileOutput {
    return _movieFileOutput != nil;
}

@end
