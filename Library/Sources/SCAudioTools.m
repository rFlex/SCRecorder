//
//  SCAudioTools.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/8/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "SCAudioTools.h"

@implementation SCAudioTools {
    
}

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
+ (void)overrideCategoryMixWithOthers {
	
    UInt32 doSetProperty = 1;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    AudioSessionSetProperty (kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof(doSetProperty), &doSetProperty);
#pragma clang diagnostic pop
}
#endif

+ (void)mixAudio:(AVAsset*)audioAsset startTime:(CMTime)startTime withVideo:(NSURL*)inputUrl affineTransform:(CGAffineTransform)affineTransform  toUrl:(NSURL*)outputUrl outputFileType:(NSString*)outputFileType withMaxDuration:(CMTime)maxDuration withCompletionBlock:(void(^)(NSError *))completionBlock {
	NSError * error = nil;
	AVMutableComposition * composition = [[AVMutableComposition alloc] init];
	
	AVMutableCompositionTrack * videoTrackComposition = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
	
	AVMutableCompositionTrack * audioTrackComposition = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
	
	AVURLAsset * fileAsset = [AVURLAsset URLAssetWithURL:inputUrl options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey]];
	
	NSArray * videoTracks = [fileAsset tracksWithMediaType:AVMediaTypeVideo];
	
	CMTime duration = ((AVAssetTrack*)[videoTracks objectAtIndex:0]).timeRange.duration;
	
	// We check if the recorded time if more than the limit
	if (CMTIME_COMPARE_INLINE(duration, >, maxDuration)) {
		duration = maxDuration;
	}
	
	for (AVAssetTrack * track in [audioAsset tracksWithMediaType:AVMediaTypeAudio]) {
		[audioTrackComposition insertTimeRange:CMTimeRangeMake(startTime, duration) ofTrack:track atTime:kCMTimeZero error:&error];
		
		if (error != nil) {
			completionBlock(error);
			return;
		}
	}
	
	for (AVAssetTrack * track in videoTracks) {
		[videoTrackComposition insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:track atTime:kCMTimeZero error:&error];
		
		if (error != nil) {
			completionBlock(error);
			return;
		}
	}
	
	videoTrackComposition.preferredTransform = affineTransform;
	
	AVAssetExportSession * exportSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
	exportSession.outputFileType = outputFileType;
	exportSession.shouldOptimizeForNetworkUse = YES;
	exportSession.outputURL = outputUrl;
    
	[exportSession exportAsynchronouslyWithCompletionHandler:^ {
		NSError * error = nil;
		if (exportSession.error != nil) {
			NSMutableDictionary * userInfo = [NSMutableDictionary dictionaryWithDictionary:exportSession.error.userInfo];
			NSString * subLocalizedDescription = [userInfo objectForKey:NSLocalizedDescriptionKey];
			[userInfo removeObjectForKey:NSLocalizedDescriptionKey];
			[userInfo setObject:@"Failed to mix audio and video" forKey:NSLocalizedDescriptionKey];
			[userInfo setObject:exportSession.outputFileType forKey:@"OutputFileType"];
			[userInfo setObject:exportSession.outputURL forKey:@"OutputUrl"];
			[userInfo setObject:subLocalizedDescription forKey:@"CauseLocalizedDescription"];
			
			[userInfo setObject:[AVAssetExportSession allExportPresets] forKey:@"AllExportSessions"];
			
			error = [NSError errorWithDomain:@"SCAudioVideoRecorder" code:500 userInfo:userInfo];
		}
				
		completionBlock(error);
	}];
}

@end
