//
//  SCVideoPlayer.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCPlayer.h"

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface SCPlayer() {
	BOOL _loading;
}

@property (strong, nonatomic, readwrite) AVPlayerItem * oldItem;
@property (assign, nonatomic, readwrite, getter=isLoading) BOOL loading;
@property (assign, nonatomic) Float32 itemsLoopLength;
@property (strong, nonatomic, readwrite) id timeObserver;

@end

SCPlayer * currentSCVideoPlayer = nil;


////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCPlayer

@synthesize oldItem;

- (id) init {
	self = [super init];
	
	if (self) {
		self.actionAtItemEnd = AVPlayerActionAtItemEndNone;

		[self addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionNew context:nil];
		
		__unsafe_unretained SCPlayer * mySelf = self;
		self.timeObserver = [self addPeriodicTimeObserverForInterval:CMTimeMake(1, 24) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
			if ([mySelf.delegate respondsToSelector:@selector(videoPlayer:didPlay:secondsTotal:)]) {
				[mySelf.delegate videoPlayer:mySelf didPlay:CMTimeGetSeconds(time) / mySelf.itemsLoopLength secondsTotal:CMTimeGetSeconds(mySelf.currentItem.duration) / mySelf.itemsLoopLength];
			}
		}];
		_loading = NO;
		
		self.minimumBufferedTimeBeforePlaying = 2;
	}
	
	return self;
}

- (void) dispose {
	[self removeTimeObserver:self.timeObserver];
	[self setItem:nil];
	self.oldItem = nil;
}

- (void) playReachedEnd:(NSNotification*)notification {
	if (notification.object == self.currentItem) {
		if (self.shouldLoop) {
			[self seekToTime:CMTimeMake(0, 1)];
			if ([self isPlaying]) {
				[self play];
			}
		}
	}
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"currentItem"]) {
		[self initObserver];
	} else {
		if (object == self.currentItem) {
			if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
				if (!self.isLoading) {
					self.loading = YES;
				}
			} else {
				Float64 playableDuration = [self playableDuration];
				Float64 minimumTime = self.minimumBufferedTimeBeforePlaying;
				Float64 itemTime = CMTimeGetSeconds(self.currentItem.duration);
				
				if (minimumTime > itemTime) {
					minimumTime = itemTime;
				}
				
				if (playableDuration >= minimumTime) {
					if ([self isPlaying]) {
						[self play];
					}
					if (self.isLoading) {
						self.loading = NO;
					}
				}
			}
		}
	}
}

- (void) initObserver {
	if (self.oldItem != nil) {
		[self.oldItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
		[self.oldItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
		[self.oldItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
		
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.oldItem];
	}
	
	if (self.currentItem != nil) {
		[self.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
		[self.currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
		[self.currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:
		 NSKeyValueObservingOptionNew context:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playReachedEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.currentItem];
	}
	
	self.loading = NO;
		
	self.oldItem = self.currentItem;
	
	if ([self.delegate respondsToSelector:@selector(videoPlayer:didChangeItem:)]) {
		[self.delegate videoPlayer:self didChangeItem:self.currentItem];
	}
}

- (void) play {
	if (currentSCVideoPlayer != self) {
		[SCPlayer pauseCurrentPlayer];
	}
	
	[super play];
	
	currentSCVideoPlayer = self;
}

- (void) pause {
	[super pause];
	
	if (currentSCVideoPlayer == self) {
		currentSCVideoPlayer = nil;
	}
}

- (Float64) playableDuration {
	AVPlayerItem * item = self.currentItem;
	Float64 playableDuration = 0;
	
	if (item.status == AVPlayerItemStatusReadyToPlay) {
		
		if (item.loadedTimeRanges.count > 0) {
			NSValue * value = [item.loadedTimeRanges objectAtIndex:0];
			CMTimeRange timeRange = [value CMTimeRangeValue];
			
			playableDuration = CMTimeGetSeconds(timeRange.duration);
		}
	}
	
	return playableDuration;
}

- (void) setItemByStringPath:(NSString *)stringPath {
	[self setItemByUrl:[NSURL URLWithString:stringPath]];
}

- (void) setItemByUrl:(NSURL *)url {
	[self setItemByAsset:[AVURLAsset URLAssetWithURL:url options:nil]];
}

- (void) setItemByAsset:(AVAsset *)asset {
	[self setItem:[AVPlayerItem playerItemWithAsset:asset]];
}

- (void) setItem:(AVPlayerItem *)item {
	self.itemsLoopLength = 1;
	[self replaceCurrentItemWithPlayerItem:item];
}

- (void) setSmoothLoopItemByStringPath:(NSString *)stringPath smoothLoopCount:(NSUInteger)loopCount {
	[self setSmoothLoopItemByUrl:[NSURL URLWithString:stringPath] smoothLoopCount:loopCount];
}

- (void) setSmoothLoopItemByUrl:(NSURL *)url smoothLoopCount:(NSUInteger)loopCount {
	[self setSmoothLoopItemByAsset:[AVURLAsset URLAssetWithURL:url options:nil] smoothLoopCount:loopCount];
}

- (void) setSmoothLoopItemByAsset:(AVAsset *)asset smoothLoopCount:(NSUInteger)loopCount {
	
	AVMutableComposition * composition = [AVMutableComposition composition];
	
	CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
	
	for (NSUInteger i = 0; i < loopCount; i++) {
		[composition insertTimeRange:timeRange ofAsset:asset atTime:composition.duration error:nil];
	}
	
	[self setItemByAsset:composition];
	
	self.itemsLoopLength = loopCount;
}

- (BOOL) isPlaying {
	return currentSCVideoPlayer == self;
}

- (void) setLoading:(BOOL)loading {
	_loading = loading;
	
	if (loading) {
		if ([self.delegate respondsToSelector:@selector(videoPlayer:didStartLoadingAtItemTime:)]) {
			[self.delegate videoPlayer:self didStartLoadingAtItemTime:self.currentItem.currentTime];
		}
	} else {
		if ([self.delegate respondsToSelector:@selector(videoPlayer:didEndLoadingAtItemTime:)]) {
			[self.delegate videoPlayer:self didEndLoadingAtItemTime:self.currentItem.currentTime];
		}
	}
}

+ (SCPlayer*) videoPlayer {
	return [[SCPlayer alloc] init];
}

+ (void) pauseCurrentPlayer {
	if (currentSCVideoPlayer != nil) {
		[currentSCVideoPlayer pause];
	}
}

+ (SCPlayer*) currentPlayer {
	return currentSCVideoPlayer;
}

@end
