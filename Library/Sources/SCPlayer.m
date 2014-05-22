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
    BOOL _shouldLoop;
}

@property (strong, nonatomic, readwrite) AVPlayerItem * oldItem;
@property (assign, nonatomic, readwrite, getter=isLoading) BOOL loading;
@property (assign, nonatomic) Float64 itemsLoopLength;
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
        self.shouldLoop = NO;

		[self addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionNew context:nil];
		
		_loading = NO;
		
		self.minimumBufferedTimeBeforePlaying = CMTimeMake(2, 1);
	}
	
	return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"currentItem"];
    [self removeOldObservers];
    [self endSendingPlayMessages];
}

- (void)beginSendingPlayMessages {
    [self endSendingPlayMessages];
    __block SCPlayer * mySelf = self;
    
    self.timeObserver = [self addPeriodicTimeObserverForInterval:CMTimeMake(1, 24) queue:nil usingBlock:^(CMTime time) {
        id<SCVideoPlayerDelegate> delegate = mySelf.delegate;
        if ([delegate respondsToSelector:@selector(videoPlayer:didPlay:loopsCount:)]) {
            Float64 ratio = 1.0 / mySelf.itemsLoopLength;
            Float64 seconds = CMTimeGetSeconds(CMTimeMultiplyByFloat64(time, ratio));
            
            NSInteger loopCount = CMTimeGetSeconds(time) / (CMTimeGetSeconds(mySelf.currentItem.duration) / (Float64)mySelf.itemsLoopLength);
            
            [delegate videoPlayer:mySelf didPlay:seconds loopsCount:loopCount];
        }
    }];
}

- (void)endSendingPlayMessages {
    if (self.timeObserver != nil) {
        [self removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
}

- (void) playReachedEnd:(NSNotification*)notification {
	if (notification.object == self.currentItem) {
		if (self.shouldLoop) {
			[self seekToTime:CMTimeMake(0, 1)];
			if ([self isPlaying]) {
				[self play];
			}
		}
        id<SCVideoPlayerDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(player:didReachEndForItem:)]) {
            [delegate player:self didReachEndForItem:self.currentItem];
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
				CMTime playableDuration = [self playableDuration];
				CMTime minimumTime = self.minimumBufferedTimeBeforePlaying;
				CMTime itemTime = self.currentItem.duration;
				
				if (CMTIME_COMPARE_INLINE(minimumTime, >, itemTime)) {
					minimumTime = itemTime;
				}
                
				if (CMTIME_COMPARE_INLINE(playableDuration, >=, minimumTime)) {
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

- (void)removeOldObservers {
    if (self.oldItem != nil) {
		[self.oldItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
		[self.oldItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
		
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.oldItem];
        self.oldItem = nil;
	}
}

- (void) initObserver {
	[self removeOldObservers];
	
	if (self.currentItem != nil) {
		[self.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
		[self.currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:
		 NSKeyValueObservingOptionNew context:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playReachedEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.currentItem];
        self.oldItem = self.currentItem;
	}
		
    id<SCVideoPlayerDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(videoPlayer:didChangeItem:)]) {
		[delegate videoPlayer:self didChangeItem:self.currentItem];
	}
    self.loading = YES;
}

- (void) play {
	if (currentSCVideoPlayer != self && currentSCVideoPlayer.shouldPlayConcurrently == NO) {
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

- (CMTime) playableDuration {
	AVPlayerItem * item = self.currentItem;
	CMTime playableDuration = kCMTimeZero;
	
	if (item.status != AVPlayerItemStatusFailed) {
		
		if (item.loadedTimeRanges.count > 0) {
			NSValue * value = [item.loadedTimeRanges objectAtIndex:0];
			CMTimeRange timeRange = [value CMTimeRangeValue];
			
			playableDuration = timeRange.duration;
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
	
    id<SCVideoPlayerDelegate> delegate = self.delegate;
	if (loading) {
		if ([delegate respondsToSelector:@selector(videoPlayer:didStartLoadingAtItemTime:)]) {
			[delegate videoPlayer:self didStartLoadingAtItemTime:self.currentItem.currentTime];
		}
	} else {
		if ([delegate respondsToSelector:@selector(videoPlayer:didEndLoadingAtItemTime:)]) {
			[delegate videoPlayer:self didEndLoadingAtItemTime:self.currentItem.currentTime];
		}
	}
}

- (BOOL)shouldLoop {
    return _shouldLoop;
}

- (void)setShouldLoop:(BOOL)shouldLoop {
    _shouldLoop = shouldLoop;
    
    self.actionAtItemEnd = shouldLoop ? AVPlayerActionAtItemEndNone : AVPlayerActionAtItemEndPause;
}

- (CMTime)itemDuration {
    Float64 ratio = 1.0 / self.itemsLoopLength;

    return CMTimeMultiply(self.currentItem.duration, ratio);
}

- (BOOL)isSendingPlayMessages {
    return self.timeObserver != nil;
}

+ (SCPlayer*) player {
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
