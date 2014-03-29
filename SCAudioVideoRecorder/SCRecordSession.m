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
    int _currentSegmentCount;
    CMTime _timeOffset;
    CMTime _lastTime;
}
@end

@implementation SCRecordSession

- (id)init {
    self = [super init];
    
    if (self) {
        [self clear];
    }
    
    return self;
}

+ (id)recordSession {
    return [[SCRecordSession alloc] init];
}

- (void)clear {
    self.videoSize = CGSizeZero;
    self.videoCodec = kRecordSessionDefaultVideoCodec;
    self.videoScalingMode = kRecordSessionDefaultVideoScalingMode;
    self.videoBitsPerPixel = kRecordSessionDefaultOutputBitPerPixel;
    self.videoAffineTransform = CGAffineTransformIdentity;
    
    self.audioSampleRate = 0;
    self.audioChannels = 0;
    self.audioBitRate = kRecordSessionDefaultAudioBitrate;
    self.audioEncodeType = kRecordSessionDefaultAudioFormat;
    
    _recordSegments = [[NSMutableArray alloc] init];
    
    _shouldRecomputeTimeOffset = YES;
    _assetWriter = nil;
    _videoInput = nil;
    _audioInput = nil;
    _audioInitializationFailed = NO;
    _videoInitializationFailed = NO;
    _currentSegmentCount = 0;
    _timeOffset = kCMTimeZero;
    _lastTime = kCMTimeZero;
}

- (void)setOutputUrlWithTempUrl {
    long timeInterval =  (long)[[NSDate date] timeIntervalSince1970];
	self.outputUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%ld%@", NSTemporaryDirectory(), timeInterval, @"SCVideo.mp4"]];
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
    NSString *extension = [self.outputUrl.path pathExtension];
    NSString *newExtension = [NSString stringWithFormat:@"%d.%@", _currentSegmentCount, extension];
    NSURL *file = [NSURL fileURLWithPath:[self.outputUrl.path.stringByDeletingPathExtension stringByAppendingPathExtension:newExtension]];
    
    [self removeFile:file];
    
    NSError *theError = nil;
    
    AVAssetWriter * writer = [[AVAssetWriter alloc] initWithURL:file fileType:self.fileType error:&theError];
    
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
        }
        
        _currentSegmentCount++;
    }
    
    if (error != nil) {
        *error = theError;
    }
    
    return writer;
}

- (BOOL)initializeWriterIfNeeded:(NSError**)error suggesFileType:(NSString*)fileType {
    if (_assetWriter == nil) {
        
        if (self.outputUrl == nil) {
            *error = [SCRecordSession createError:@"Cannot initialize if outputUrl is null"];
            return NO;
        }
        
        if (self.fileType != nil) {
            fileType = self.fileType;
        }

        _assetWriter = [[AVAssetWriter alloc] initWithURL:self.outputUrl fileType:fileType error:error];
        
        return *error == nil;
    } else {
        *error = nil;
        return YES;
    }
}

+ (NSInteger) getBitsPerSecondForOutputVideoSize:(CGSize)size andBitsPerPixel:(Float32)bitsPerPixel {
    int numPixels = size.width * size.height;
    
    return (NSInteger)((Float32)numPixels * bitsPerPixel);
}

- (void)initializeVideoUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer suggestedFileType:(NSString *)fileType error:(NSError *__autoreleasing *)error {
    if (self.fileType == nil) {
        self.fileType = fileType;
    }
    
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
    if (self.fileType == nil) {
        self.fileType = fileType;
    }
    
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
    
    [_assetWriter addInput:_audioInput];
    
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
    [self makeTimeOffsetDirty];
    
    AVAssetWriter *writer = _assetWriter;
    [writer finishWritingWithCompletionHandler:^{
        NSInteger segmentNumber = -1;
        if (writer.error == nil) {
            segmentNumber = _recordSegments.count;
            [_recordSegments addObject:writer.outputURL];
        }
        
        if (completionHandler != nil) {
            completionHandler(segmentNumber, writer.error);
        }
    }];
    
    _assetWriter = nil;
}

- (void)endSession:(void (^)(NSError *))completionHandler {
    [self endRecordSegment:^(NSInteger segmentNumber, NSError *error) {
        if (completionHandler != nil) {
            completionHandler(error);
        }
    }];
}

- (void)appendBuffer:(CMSampleBufferRef)buffer to:(AVAssetWriterInput*)input {
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
    }
    
    if ([input isReadyForMoreMediaData]) {
        [input appendSampleBuffer:adjustedBuffer];
        NSLog(@"%f", CMTimeGetSeconds(_lastTime));
    }
    
    CFRelease(adjustedBuffer);
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer {
    [self appendBuffer:audioSampleBuffer to:_audioInput];
}

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)videoSampleBuffer {
    [self appendBuffer:videoSampleBuffer to:_videoInput];
}

- (AVAsset *)assetRepresentingRecordSegments {
    return nil;
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

@end
