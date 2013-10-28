//
//  VRVideoRecorder.m
//  VideoRecorder
//
//  Created by Simon CORSIN on 8/3/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <AssetsLibrary/AssetsLibrary.h>
#endif
#import "SCAudioVideoRecorderInternal.h"

#import "NSArray+SCAdditions.h"

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface SCAudioVideoRecorder() {
	BOOL recording;
	BOOL shouldWriteToCameraRoll;
	BOOL audioEncoderReady;
	BOOL videoEncoderReady;
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
	UIBackgroundTaskIdentifier _backgroundIdentifier;
#endif
}

@property (strong, nonatomic) AVCaptureVideoDataOutput * videoOutput;
@property (strong, nonatomic) AVCaptureAudioDataOutput * audioOutput;
@property (strong, nonatomic) SCVideoEncoder * videoEncoder;
@property (strong, nonatomic) SCAudioEncoder * audioEncoder;
@property (strong, nonatomic) NSURL * outputFileUrl;
@property (strong, nonatomic) AVPlayer * playbackPlayer;
@property (assign, nonatomic) Float32 currentRecordingTime;

@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCAudioVideoRecorder

@synthesize delegate;
@synthesize videoOutput;
@synthesize audioOutput;
@synthesize outputFileUrl;
@synthesize audioEncoder;
@synthesize videoEncoder;
@synthesize dispatchDelegateMessagesOnMainQueue;
@synthesize outputFileType;
@synthesize playbackAsset;
@synthesize playbackPlayer;
@synthesize limitRecordingDuration;
@synthesize recordingDurationLimitSeconds;

- (id) init {
	self = [super init];
	
	if (self) {
		self.outputFileType = AVFileTypeMPEG4;
		
		self.dispatch_queue = dispatch_queue_create("SCVideoRecorder", nil);
		
		audioEncoderReady = NO;
		videoEncoderReady = NO;
		self.audioEncoder = [[SCAudioEncoder alloc] initWithAudioVideoRecorder:self];
		self.videoEncoder = [[SCVideoEncoder alloc] initWithAudioVideoRecorder:self];
		self.audioEncoder.delegate = self;
		self.videoEncoder.delegate = self;
		recording = NO;
		
		self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
		[self.videoOutput setSampleBufferDelegate:self.videoEncoder queue:self.dispatch_queue];
		
		self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
		[self.audioOutput setSampleBufferDelegate:self.audioEncoder queue:self.dispatch_queue];
		
		self.lastFrameTimeBeforePause = CMTimeMake(0, 1);
		self.dispatchDelegateMessagesOnMainQueue = YES;
		self.enableSound = YES;
		self.enableVideo = YES;
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
		_backgroundIdentifier = UIBackgroundTaskInvalid;
#endif
	}
	return self;
}

- (void) dealloc {
}

// Hack to force ARC to not release an object in a code block
- (void) pleaseDontReleaseObject:(id)object {
	
}

//
// Video Recorder methods
//

- (void) prepareRecordingAtCameraRoll:(NSError **)error {
	[self prepareRecordingOnTempDir:error];
	shouldWriteToCameraRoll = YES;
}

- (NSURL*) prepareRecordingOnTempDir:(NSError **)error {
	long timeInterval =  (long)[[NSDate date] timeIntervalSince1970];
	NSURL * fileUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%ld%@", NSTemporaryDirectory(), timeInterval, @"SCVideo.mp4"]];
    
	NSError * recordError = nil;
	[self prepareRecordingAtUrl:fileUrl error:&recordError];
    
	if (recordError != nil) {
		if (error != nil) {
			*error = recordError;
		}
		[self removeFile:fileUrl];
		fileUrl = nil;
        
	}
    
	return fileUrl;
}


- (void) prepareRecordingAtUrl:(NSURL *)fileUrl error:(NSError **)error {
	if (fileUrl == nil) {
		[NSException raise:@"Invalid argument" format:@"FileUrl must be not nil"];
	}
	   
	dispatch_sync(self.dispatch_queue, ^{
		[self resetInternal];
		[self startBackgroundTask];
		
		shouldWriteToCameraRoll = NO;
		self.currentTimeOffset = CMTimeMake(0, 1);
		
		NSError * assetError;
		
		AVAssetWriter * writer = [[AVAssetWriter alloc] initWithURL:fileUrl fileType:self.outputFileType error:&assetError];
		
		if (assetError == nil) {
			self.assetWriter = writer;
			self.outputFileUrl = fileUrl;
			
			if (error != nil) {
				*error = nil;
			}
		} else {
			if (error != nil) {
				*error = assetError;
			}
		}
	});
	if (self.playbackAsset != nil) {
		self.playbackPlayer = [AVPlayer playerWithPlayerItem:[AVPlayerItem playerItemWithAsset:self.playbackAsset]];
	}
}

- (void) removeFile:(NSURL *)fileURL {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *filePath = [fileURL path];
	if ([fileManager fileExistsAtPath:filePath]) {
		NSError *error;
		[fileManager removeItemAtPath:filePath error:&error];
	}
}

- (void) finalizeAudioMixForUrl:(NSURL*)fileUrl  withCompletionBlock:(void(^)())completionBlock {
	if (self.playbackAsset != nil) {
		// Move the file to a tmp one
		NSURL * oldUrl = [[fileUrl URLByDeletingPathExtension] URLByAppendingPathExtension:@"old.mov"];
		[[NSFileManager defaultManager] moveItemAtURL:fileUrl toURL:oldUrl error:nil];
		
		AVMutableComposition * composition = [[AVMutableComposition alloc] init];
		
		AVMutableCompositionTrack * audioTrackComposition = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
		
		AVMutableCompositionTrack * videoTrackComposition = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
		
		AVURLAsset * fileAsset = [AVURLAsset URLAssetWithURL:oldUrl options:nil];
		
		// We create an array of tracks containing the audio tracks and the video tracks
		NSArray * audioTracks = [NSArray arrayWithArrays:[self.playbackAsset tracksWithMediaType:AVMediaTypeAudio], [fileAsset tracksWithMediaType:AVMediaTypeAudio], nil];

		NSArray * videoTracks = [fileAsset tracksWithMediaType:AVMediaTypeVideo];
		
		CMTime duration = ((AVAssetTrack*)[videoTracks objectAtIndex:0]).timeRange.duration;
		
		if (self.limitRecordingDuration) {
			// We check if the recorded time if more than the limit
			if (CMTimeGetSeconds(duration) > self.recordingDurationLimitSeconds) {
				duration = CMTimeMakeWithSeconds(self.recordingDurationLimitSeconds, 1);
			}
		}
		
		for (AVAssetTrack * track in audioTracks) {
			[audioTrackComposition insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:track atTime:kCMTimeZero error:nil];
		}
		
		for (AVAssetTrack * track in videoTracks) {
			[videoTrackComposition insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:track atTime:kCMTimeZero error:nil];
		}
		videoTrackComposition.preferredTransform = self.videoEncoder.outputAffineTransform;
		
		AVAssetExportSession * exportSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
		exportSession.outputFileType = self.outputFileType;
		exportSession.shouldOptimizeForNetworkUse = YES;
		exportSession.outputURL = fileUrl;
		
		
		[exportSession exportAsynchronouslyWithCompletionHandler:^ {
			[self pleaseDontReleaseObject:exportSession];
			
			[self removeFile:oldUrl];
			completionBlock();
		}];
	} else {
		completionBlock();
	}
}

- (void) assetWriterFinished:(NSURL*)fileUrl {
	self.assetWriter = nil;
	self.outputFileUrl = nil;
	[self.audioEncoder reset];
	[self.videoEncoder reset];
	
	[self finalizeAudioMixForUrl:fileUrl withCompletionBlock:^ {
		if (shouldWriteToCameraRoll) {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE			
			ALAssetsLibrary * library = [[ALAssetsLibrary alloc] init];
			[library writeVideoAtPathToSavedPhotosAlbum:fileUrl completionBlock:^(NSURL *assetUrl, NSError * error) {
				[self pleaseDontReleaseObject:library];
				
				if (error != nil) {
					NSLog(@"Error: %@", error);
				}
				
				[self removeFile:fileUrl];
				
				[self notifyRecordFinishedAtUrl:assetUrl withError:error];
			}];
#endif
		} else {
			[self notifyRecordFinishedAtUrl:fileUrl withError:nil];
		}
	}];
}

- (void) finishWriter:(NSURL*)fileUrl {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    [self.assetWriter finishWritingWithCompletionHandler:^ {
        [self assetWriterFinished:fileUrl];
    }];
#else
    [self.assetWriter finishWriting];
    [self assetWriterFinished:fileUrl];
#endif
}

- (void) notifyRecordFinishedAtUrl:(NSURL*)url withError:(NSError*)error {
	[self dispatchBlockOnAskedQueue:^{
		if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didFinishRecordingAtUrl:error:)]) {
			[self.delegate audioVideoRecorder:self didFinishRecordingAtUrl:url error:error];
		}
	}];
}

- (void) startBackgroundTask {
	[self stopBackgroundTask];
	
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
	_backgroundIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
		[self stopBackgroundTask];
	}];
#endif
}

- (void) stopBackgroundTask {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
	if (_backgroundIdentifier != UIBackgroundTaskInvalid) {
		[[UIApplication sharedApplication] endBackgroundTask:_backgroundIdentifier];
		_backgroundIdentifier = UIBackgroundTaskInvalid;
	}
#endif
}

- (void) stop {
	[self pause];
	[self stopBackgroundTask];
	
	if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:willFinishRecordingAtTime:)]) {
		[self.delegate audioVideoRecorder:self willFinishRecordingAtTime:self.currentRecordingTime];
	}
    
	dispatch_async(self.dispatch_queue, ^ {
		if (self.assetWriter == nil) {
			[self notifyRecordFinishedAtUrl:nil withError:[SCAudioVideoRecorder createError:@"Recording must be started before calling stopRecording"]];
		} else {
			NSURL * fileUrl = self.outputFileUrl;
			NSError * error = self.assetWriter.error;
			
			switch (self.assetWriter.status) {
				case AVAssetWriterStatusWriting:
					[self finishWriter:fileUrl];
					break;
				case AVAssetWriterStatusCompleted:
					[self assetWriterFinished:fileUrl];
					break;
				case AVAssetWriterStatusFailed:
					[self resetInternal];
					[self notifyRecordFinishedAtUrl:nil withError:error];
					break;
				case AVAssetWriterStatusCancelled:
					[self resetInternal];
					[self notifyRecordFinishedAtUrl:nil withError:[SCAudioVideoRecorder createError:@"Writer cancelled"]];
					break;
				case AVAssetWriterStatusUnknown:
					[self resetInternal];
					[self notifyRecordFinishedAtUrl:nil withError:[SCAudioVideoRecorder createError:@"Writer status unknown"]];
					break;
			}
		}
    });
    
}

- (void) pause {
	[self.playbackPlayer pause];
	dispatch_async(self.dispatch_queue, ^ {
		recording = NO;
		// As I don't know any way to get the current time in CMTime, setting this will always
		// let the last frame to last 1/24th of a second
		self.lastFrameTimeBeforePause = CMTimeMake(1, 24);
    });
}

- (void) record {
	if (![self isPrepared]) {
		[NSException raise:@"Recording not previously started" format:@"Recording should be started using startRecording before trying to resume it"];
	}
	
	[self.playbackPlayer play];
	dispatch_async(self.dispatch_queue, ^ {
		self.shouldComputeOffset = YES;
		recording = YES;
    });
}

- (void) cancel {
	dispatch_sync(self.dispatch_queue, ^ {
		[self resetInternal];
    });
}

- (void) resetInternal {
	[self stopBackgroundTask];
	AVAssetWriter * writer = self.assetWriter;
	NSURL * fileUrl = self.outputFileUrl;
	
	audioEncoderReady = NO;
	videoEncoderReady = NO;
	
	self.outputFileUrl = nil;
	self.assetWriter = nil;
	self.playbackPlayer = nil;

	recording = NO;
    
	[self.audioEncoder reset];
	[self.videoEncoder reset];
    
	if (writer != nil) {
		if (writer.status != AVAssetWriterStatusUnknown) {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
			[writer finishWritingWithCompletionHandler:^ {
				[self pleaseDontReleaseObject:writer];
				if (fileUrl != nil) {
					[self removeFile:fileUrl];
				}
			}];
#else
			[writer finishWriting];
			if (fileUrl != nil) {
				[self removeFile:fileUrl];
			}
#endif
		}
	}
}

//
// DataEncoder Delegate implementation
//

- (void) dataEncoder:(SCDataEncoder *)dataEncoder didEncodeFrame:(Float64)frameSecond {
    [self dispatchBlockOnAskedQueue:^ {
		self.currentRecordingTime = frameSecond;
		
        if (dataEncoder == self.audioEncoder) {
            if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didRecordAudioSample:)]) {
                [self.delegate audioVideoRecorder:self didRecordAudioSample:frameSecond];
            }
        } else if (dataEncoder == self.videoEncoder) {
            if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didRecordVideoFrame:)]) {
                [self.delegate audioVideoRecorder:self didRecordVideoFrame:frameSecond];
            }
        }
		if (self.limitRecordingDuration) {
			if (frameSecond >= self.recordingDurationLimitSeconds) {
				[self stop];
			}
		}
    }];
}

- (void) dataEncoder:(SCDataEncoder *)dataEncoder didFailToInitializeEncoder:(NSError *)error {
    [self dispatchBlockOnAskedQueue: ^ {
        if (dataEncoder == self.audioEncoder) {
            if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didFailToInitializeAudioEncoder:)]) {
                [self.delegate audioVideoRecorder:self didFailToInitializeAudioEncoder:error];
            }
        } else if (dataEncoder == self.videoEncoder) {
            if ([self.delegate respondsToSelector:@selector(audioVideoRecorder:didFailToInitializeVideoEncoder:)]) {
                [self.delegate audioVideoRecorder:self didFailToInitializeVideoEncoder:error];
            }
        }
    }];
}

//
// Misc methods
//

- (void) dispatchBlockOnAskedQueue:(void(^)())block {
	if (self.dispatchDelegateMessagesOnMainQueue) {
		dispatch_async(dispatch_get_main_queue(), block);
	} else {
		block();
	}
}

+ (NSError*) createError:(NSString*)name {
	return [NSError errorWithDomain:@"SCAudioVideoRecorder" code:500 userInfo:[NSDictionary dictionaryWithObject:name forKey:NSLocalizedDescriptionKey]];
}

- (void) prepareWriterAtSourceTime:(CMTime)sourceTime fromEncoder:(SCDataEncoder*)encoder {
    // Set an encoder as ready if it's the caller or if it's not enabled
    audioEncoderReady |= (encoder == self.audioEncoder) | !self.audioEncoder.enabled;
    videoEncoderReady |= (encoder == self.videoEncoder) | !self.videoEncoder.enabled;
    
    // We only start the writing when both encoder are ready
    if (audioEncoderReady && videoEncoderReady) {
        if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
            if ([self.assetWriter startWriting]) {
                [self.assetWriter startSessionAtSourceTime:sourceTime];
            }
            self.startedTime = sourceTime;
        }
    }
}

//
// Getters
//

- (BOOL) isPrepared {
    return self.assetWriter != nil;
}

- (BOOL) isRecording {
    return recording;
}

- (void) setEnableSound:(BOOL)enableSound {
    self.audioEncoder.enabled = enableSound;
}

- (BOOL) enableSound {
    return self.audioEncoder.enabled;
}

- (void) setEnableVideo:(BOOL)enableVideo {
    self.videoEncoder.enabled = enableVideo;
}

- (BOOL) enableVideo {
    return self.videoEncoder.enabled;
}

@end
