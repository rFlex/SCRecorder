//
//  VRVideoRecorder.m
//  VideoRecorder
//
//  Created by Simon CORSIN on 8/3/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "VRVideoRecorder.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface VRVideoRecorder() {
    BOOL recording;
    BOOL shouldWriteToCameraRoll;
    BOOL initializingRecording;
    BOOL shouldComputeOffset;
    AVAssetWriter *assetWriter;
    AVAssetWriterInput *assetWriterVideoIn;
    NSURL *url;
    dispatch_queue_t dispatch_queue;
    CMTime currentTimeOffset;
    CMTime lastTakenVideoTime;
}

@end

@implementation VRVideoRecorder

@synthesize outputVideoSize;

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

- (void) startRecordingAtCameraRoll:(void (^)(NSError *))handler {
    long timeInterval =  (long)[[NSDate date] timeIntervalSince1970];
    NSURL * fileUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%ld%@", NSTemporaryDirectory(), timeInterval, @"Movie.MOV"]];
    [self startRecordingAtUrl:fileUrl withHandler:^(NSError* error) {
        shouldWriteToCameraRoll = YES;
        if (handler != nil) {
            handler(error);
        }
    }];
}

- (void) startRecordingAtUrl:(NSURL *)fileUrl withHandler:(void (^)(NSError *))handler {
    if (fileUrl == nil) {
        [NSException raise:@"Invalid argument" format:@"FileUrl must be not nil"];
    }
    if (initializingRecording) {
        [NSException raise:@"VideoRecorder not ready" format:@"The VideoRecorder is already preparing for recording"];
    }
    
    shouldWriteToCameraRoll = NO;
    initializingRecording = YES;
    currentTimeOffset = CMTimeMake(0, 1);
    
    [self reset:^ {
        NSError * assetError;
        
        AVAssetWriter * writer = [[AVAssetWriter alloc] initWithURL:fileUrl fileType:AVFileTypeQuickTimeMovie error:&assetError];
        
        if (assetError == nil) {
            dispatch_async(dispatch_queue, ^ {
                assetWriter = writer;
                url = fileUrl;
                initializingRecording = NO;
                
                NSError * error = nil;
                [self setupAssetWriterVideoInput:&error];
                if (error != nil) {
                    url = nil;
                    assetWriter = nil;
                    if (handler != nil) {
                        dispatch_async(dispatch_get_main_queue(), ^ {
                            handler(error);
                        });
                    }
                } else {
                    [self resumeRecording];
                    if (handler != nil) {
                        dispatch_async(dispatch_get_main_queue(), ^ {
                            handler(nil);
                        });
                    }
                }
            });
        } else {
            initializingRecording = NO;
            if (handler != nil) {
                handler(assetError);
            }
        }
    }];
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

- (void) stopRecording:(void (^)(NSURL *, NSError *))handler {
    [self pauseRecording];
    dispatch_async(dispatch_queue, ^ {
        if (assetWriter == nil) {
            if (handler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^ {
                    handler(nil, [self createError:@"Recording must be started before calling stopRecording"]);
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
                                handler(assetUrl, error);
                            });
                        }
                    }];
                } else {
                    if (handler != nil) {
                        dispatch_async(dispatch_get_main_queue(), ^ {
                            handler(fileUrl, nil);
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

- (void) reset:(void (^)())handler {
    dispatch_async(dispatch_queue, ^ {
        AVAssetWriter * writer = assetWriter;
        NSURL * fileUrl = url;
        
        url = nil;
        assetWriter = nil;
        
        if (writer != nil) {
            if (writer.status != AVAssetWriterStatusUnknown) {
                [writer finishWritingWithCompletionHandler:^ {
                    assetWriterVideoIn = nil;
                    if (fileUrl != nil) {
                        [self removeFile:fileUrl];
                    }
                }];                
            }
        }
        
        if (handler != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                handler();
            });
        }
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
        CFStringRef offsetDescription = CMTimeCopyDescription(nil, offset);
        
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
        
        NSLog(@"Offset: %@", offsetDescription);
        
        CFRelease(offsetDescription);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}

- (CMSampleBufferRef) adjustTimeOld:(CMSampleBufferRef) sample by:(CMTime) offset {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
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

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if ([self isRecordingStarted] && recording) {
        CMTime frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        
        if (assetWriter.status == AVAssetWriterStatusUnknown) {
            if ([assetWriter startWriting]) {
                [assetWriter startSessionAtSourceTime:frameTime];
            }
            lastTakenVideoTime = frameTime;
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
            [assetWriterVideoIn appendSampleBuffer:adjustedBuffer];
            CFRelease(adjustedBuffer);
            
            NSLog(@"Recorded frame");
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

- (BOOL) isInitializingRecording {
    return initializingRecording;
}

@end
