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
    BOOL _audioInitializationFailed;
    BOOL _videoInitializationFailed;
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
        
        self.audioSampleRate = 0;
        self.audioChannels = 0;
        self.audioBitRate = kRecordSessionDefaultAudioBitrate;
        self.audioEncodeType = kRecordSessionDefaultAudioFormat;
    }
    
    return self;
}

+ (id)recordSession {
    return [[SCRecordSession alloc] init];
}

- (void)clear {
    _audioInitializationFailed = NO;
    _videoInitializationFailed = NO;
}

- (void)setOutputUrlWithTempUrl {
    long timeInterval =  (long)[[NSDate date] timeIntervalSince1970];
	self.outputUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%ld%@", NSTemporaryDirectory(), timeInterval, @"SCVideo.mp4"]];
}

+ (NSError*)createError:(NSString*)errorDescription {
    return [NSError errorWithDomain:@"SCRecordSession" code:200 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
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
    if ([self initializeWriterIfNeeded:error suggesFileType:fileType]) {
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
        

        if ([_assetWriter canApplyOutputSettings:videoSettings forMediaType:AVMediaTypeVideo]) {
            _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
            _videoInput.expectsMediaDataInRealTime = YES;
            _videoInput.transform = self.videoAffineTransform;
            *error = nil;
        } else {
            _videoInitializationFailed = YES;
            *error = [SCRecordSession createError:@"Unable to apply video output settings"];
        }
        
    }
}

- (void)initializeAudioUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer suggestedFileType:(NSString *)fileType error:(NSError *__autoreleasing *)error {
    if ([self initializeWriterIfNeeded:error suggesFileType:fileType]) {
        
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
        
        if ([_assetWriter canApplyOutputSettings:audioSettings forMediaType:AVMediaTypeAudio]) {
            _audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
            _audioInput.expectsMediaDataInRealTime = YES;
            
            *error = nil;
        } else {
            _audioInitializationFailed = YES;
            *error = [SCRecordSession createError:@"Unable to apply audio output settings"];
        }
    }
}

- (void)saveToCameraRoll {
    
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer {
    NSLog(@"Append audio sample buffer");
}

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)videoSampleBuffer {
    NSLog(@"Append video sample buffer");
}

- (BOOL)videoInitialized {
    return _videoInput != nil;
}

- (BOOL)audioInitialized {
    return _audioInput != nil;
}

@end
