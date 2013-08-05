//
//  VRVideoRecorder.m
//  VideoRecorder
//
//  Created by Simon CORSIN on 8/3/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCVideoRecorder.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface SCVideoRecorder() {
    BOOL recording;
    BOOL shouldWriteToCameraRoll;
    BOOL shouldComputeOffset;
    AVAssetWriter *assetWriter;
    AVAssetWriterInput *assetWriterVideoIn;
    NSURL *url;
    dispatch_queue_t dispatch_queue;
    CMTime startedTime;
    CMTime currentTimeOffset;
    CMTime lastTakenVideoTime;
}

@end

@implementation SCVideoRecorder

@synthesize outputVideoSize;
@synthesize delegate;

- (id) init {
    self = [super init];
    
    if (self) {
        dispatch_queue = dispatch_queue_create("VRVideoRecorder", nil);
        [self setSampleBufferDelegate:self queue:dispatch_queue];
    }
    return self;
}

- (id) initWithOutputVideoSize:(CGSize)newOutputVideoSize {
    self = [self init];
    
    if (self) {
        self.outputVideoSize = newOutputVideoSize;
    }
    
    return self;
}

- (void) startRecordingAtCameraRoll:(NSError **)error {
    [self startRecordingOnTempDir:error];
    shouldWriteToCameraRoll = YES;
}

- (NSURL*) startRecordingOnTempDir:(NSError **)error {
    long timeInterval =  (long)[[NSDate date] timeIntervalSince1970];
    NSURL * fileUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%ld%@", NSTemporaryDirectory(), timeInterval, @"SCVideo.MOV"]];
    
    NSError * recordError = nil;
    [self startRecordingAtUrl:fileUrl error:&recordError];
    
    if (recordError != nil) {
        if (error != nil) {
            *error = recordError;
        }
        [self removeFile:fileUrl];
        fileUrl = nil;

    }
    
    return fileUrl;
}

- (void) startRecordingAtUrl:(NSURL *)fileUrl error:(NSError**)error {
    if (fileUrl == nil) {
        [NSException raise:@"Invalid argument" format:@"FileUrl must be not nil"];
    }
    
    [self progressChanged:0];
    dispatch_sync(dispatch_queue, ^ {
        [self resetInternal];
        shouldWriteToCameraRoll = NO;
        currentTimeOffset = CMTimeMake(0, 1);
        
        NSError * assetError;
        
        AVAssetWriter * writer = [[AVAssetWriter alloc] initWithURL:fileUrl fileType:AVFileTypeQuickTimeMovie error:&assetError];
        
        if (assetError == nil) {
            assetWriter = writer;
            url = fileUrl;
            
            NSError * assetWriterVideoError = nil;
            [self setupAssetWriterVideoInput:&assetWriterVideoError];
            if (assetWriterVideoError == nil) {
                [self resumeRecording];
                if (error != nil) {
                    *error = nil;
                }
            } else {
                [self resetInternal];
                if (error != nil) {
                    *error = assetWriterVideoError;
                }
            }
        } else {
            if (error != nil) {
                *error = assetError;
            }
        }
    });
}
- (NSError*) createError:(NSString*)name {
    return [NSError errorWithDomain:@"SCVideoRecorder" code:500 userInfo:[NSDictionary dictionaryWithObject:name forKey:NSLocalizedDescriptionKey]];
}

- (void) removeFile:(NSURL *)fileURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [fileURL path];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *error;
        [fileManager removeItemAtPath:filePath error:&error];
    }
}

- (void) stopRecording:(void (^)(NSError *))handler {
    [self pauseRecording];
    
    dispatch_async(dispatch_queue, ^ {
        if (assetWriter == nil) {
            if (handler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^ {
                    handler([self createError:@"Recording must be started before calling stopRecording"]);
                });
            }
        } else {
            NSURL * fileUrl = url;

            NSLog(@"Trying to finish the writing");
            [assetWriter finishWritingWithCompletionHandler:^ {
                assetWriter = nil;
                assetWriterVideoIn = nil;
                url = nil;

                NSLog(@"Finished writing");
                if (shouldWriteToCameraRoll) {
                    ALAssetsLibrary * library = [[ALAssetsLibrary alloc] init];
                    [library writeVideoAtPathToSavedPhotosAlbum:fileUrl completionBlock:^(NSURL *assetUrl, NSError * error) {
                        [self removeFile:fileUrl];
                        if (handler != nil) {
                            dispatch_async(dispatch_get_main_queue(), ^ {
                                [self progressChanged:0];
                                handler(error);
                            });
                        }
                    }];
                } else {
                    if (handler != nil) {
                        dispatch_async(dispatch_get_main_queue(), ^ {
                            [self progressChanged:0];
                            handler(nil);
                        });
                    }
                }
 
            }];
        }
    });
    
}

- (void) pauseRecording {
    recording = NO;
}

- (void) resumeRecording {
    if (![self isRecordingStarted]) {
        [NSException raise:@"Recording not previously started" format:@"Recording should be started using startRecording before trying to resume it"];
    }
    dispatch_async(dispatch_queue, ^ {
        shouldComputeOffset = YES;
        recording = YES;
    });
}

- (void) resetInternal {
    AVAssetWriter * writer = assetWriter;
    NSURL * fileUrl = url;
    
    url = nil;
    assetWriter = nil;
    assetWriterVideoIn = nil;
    
    if (writer != nil) {
        if (writer.status != AVAssetWriterStatusUnknown) {
            [writer finishWritingWithCompletionHandler:^ {
                if (fileUrl != nil) {
                    [self removeFile:fileUrl];
                }
            }];
        }
    }
}

- (void) reset {
    dispatch_sync(dispatch_queue, ^ {
        [self resetInternal];
        [self progressChanged:0];
    });
}

- (void) setupAssetWriterVideoInput:(NSError**)error {
	float bitsPerPixel;
	int numPixels = self.outputVideoSize.width * self.outputVideoSize.height;
	int bitsPerSecond;
	
    bitsPerPixel = 11.4; // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
	
	bitsPerSecond = numPixels * bitsPerPixel;
	
	NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  AVVideoCodecH264, AVVideoCodecKey,
											  [NSNumber numberWithInteger:self.outputVideoSize.width], AVVideoWidthKey,
											  [NSNumber numberWithInteger:self.outputVideoSize.height], AVVideoHeightKey,
											  [NSDictionary dictionaryWithObjectsAndKeys:
											   [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
											   [NSNumber numberWithInteger:30], AVVideoMaxKeyFrameIntervalKey,
											   nil], AVVideoCompressionPropertiesKey,
											  nil];
	if ([assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
		assetWriterVideoIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
		assetWriterVideoIn.expectsMediaDataInRealTime = YES;
//		assetWriterVideoIn.transform = [self transformFromCurrentVideoOrientationToOrientation:self.referenceOrientation];
		if ([assetWriter canAddInput:assetWriterVideoIn])
			[assetWriter addInput:assetWriterVideoIn];
		else {
            *error = [self createError:@"Couln't add asset writer video input"];
		}
	}
	else {
        *error = [self createError:@"Couldn't apply video output settings"];
	}
}

- (CMSampleBufferRef) adjustTime:(CMSampleBufferRef)sample by:(CMTime)offset {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
        
        [self printTime:offset withMessage:@"Offset: "];
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}

- (void) printTime:(CMTime)time withMessage:(NSString*)message {
    CFStringRef timeDescription = CMTimeCopyDescription(nil, time);
    NSLog(@"%@ %@", message, timeDescription);
    
    CFRelease(timeDescription);
}

- (void) progressChanged:(Float64)totalSecond {
    if ([self.delegate respondsToSelector:@selector(videoRecorder:didRecordFrame:)]) {
        [self.delegate videoRecorder:self didRecordFrame:totalSecond];
    }
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if ([self isRecordingStarted] && recording) {
        CMTime frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        
        if (assetWriter.status == AVAssetWriterStatusUnknown) {
            if ([assetWriter startWriting]) {
                [assetWriter startSessionAtSourceTime:frameTime];
            }
            lastTakenVideoTime = frameTime;
            startedTime = frameTime;
        }
        if ([assetWriterVideoIn isReadyForMoreMediaData]) {
            if (shouldComputeOffset) {
                shouldComputeOffset = NO;
                
                if (CMTIME_IS_VALID(lastTakenVideoTime)) {
                    CMTime offset = CMTimeSubtract(frameTime, lastTakenVideoTime);
                    
                    currentTimeOffset = CMTimeAdd(currentTimeOffset, offset);
                }
            }
            
            CMSampleBufferRef adjustedBuffer = [self adjustTime:sampleBuffer by:currentTimeOffset];
            
            CMTime currentTime = CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(adjustedBuffer), startedTime);
            [assetWriterVideoIn appendSampleBuffer:adjustedBuffer];
            CFRelease(adjustedBuffer);
            
            dispatch_async(dispatch_get_main_queue(), ^ {
                [self progressChanged:CMTimeGetSeconds(currentTime)];
            });
        } else {
            NSLog(@"Not ready for more media");
        }
        lastTakenVideoTime = frameTime;
    }
}

- (BOOL) isRecordingStarted {
    return assetWriter != nil;
}

- (BOOL) isRecording {
    return recording;
}

- (NSURL*) getOutputFileUrl {
    return url;
}

@end
