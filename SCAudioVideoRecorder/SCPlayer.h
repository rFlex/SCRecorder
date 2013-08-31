//
//  SCVideoPlayer.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@class SCPlayer;

@protocol SCVideoPlayerDelegate <NSObject>

@optional

- (void) videoPlayer:(SCPlayer*)videoPlayer didPlay:(Float64)secondsElapsed secondsTotal:(Float64)secondsTotal;
- (void) videoPlayer:(SCPlayer *)videoPlayer didStartLoadingAtItemTime:(CMTime)itemTime;
- (void) videoPlayer:(SCPlayer *)videoPlayer didEndLoadingAtItemTime:(CMTime)itemTime;

@end

@interface SCPlayer : AVPlayer

+ (SCPlayer*) videoPlayer;
+ (void) pauseCurrentPlayer;
+ (SCPlayer*) currentPlayer;

- (void) setItemByStringPath:(NSString*)stringPath;
- (void) setItemByUrl:(NSURL*)url;
- (void) setItemByAsset:(AVAsset*)asset;
- (void) setItem:(AVPlayerItem*)item;

- (Float64) playableDuration;
- (BOOL) isPlaying;
- (BOOL) isLoading;

@property (weak, nonatomic, readwrite) id<SCVideoPlayerDelegate> delegate;
@property (assign, nonatomic, readwrite) Float64 minimumBufferedTimeBeforePlaying;
@property (assign, nonatomic, readwrite) BOOL shouldLoop;

@end
