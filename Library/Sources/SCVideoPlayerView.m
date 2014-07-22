//
//  SCVideoPlayerView.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCVideoPlayerView.h"


////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface SCVideoPlayerView() {
	UIView * _loadingView;
    SCPlayer *_player;
    BOOL _holdPlayer;
    UITapGestureRecognizer *_tapToPauseGesture;
}

@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCVideoPlayerView

- (id) init {
	self = [super init];
	
	if (self) {
		_loadingView = nil;
		[self commonInit];
	}
	
	return self;
}

- (id)initWithPlayer:(SCPlayer *)thePlayer {
    self = [super init];
    
    if (self) {
        _player = thePlayer;
        [self commonInit];
    }
    
    return self;
}

- (void)dealloc {
    self.player.outputView = nil;
    
    if (_holdPlayer) {
        [self.player pause];
        [self.player endSendingPlayMessages];
    }
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	
	if (self) {
		[self commonInit];
	}
	
	return self;
}

- (void)commonInit {
    if (_player == nil) {
        _player = [SCPlayer player];
        _holdPlayer = YES;
    }
    
    self.player.outputView = self;
	self.player.delegate = self;
		
	self.clipsToBounds = YES;
}

- (void) videoPlayer:(SCPlayer *)videoPlayer didStartLoadingAtItemTime:(CMTime)itemTime {
	self.loadingView.hidden = NO;
}

- (void) videoPlayer:(SCPlayer *)videoPlayer didEndLoadingAtItemTime:(CMTime)itemTime {
	self.loadingView.hidden = YES;
}

- (void)videoPlayer:(SCPlayer *)videoPlayer didPlay:(Float64)secondsElapsed loopsCount:(NSInteger)loopsCount {
    
}

- (void)videoPlayer:(SCPlayer *)videoPlayer didChangeItem:(AVPlayerItem *)item {
    
}

- (void)tapOrPause {
    id<SCVideoPlayerViewDelegate> delegate = self.delegate;
    
    if (self.player.rate == 0) {
        [self.player play];
        
        if ([delegate respondsToSelector:@selector(videoPlayerViewTappedToPlay:)]) {
            [delegate videoPlayerViewTappedToPlay:self];
        }
    } else {
        [self.player pause];
        
        if ([delegate respondsToSelector:@selector(videoPlayerViewTappedToPause:)]) {
            [delegate videoPlayerViewTappedToPause:self];
        }
    }
}

- (void) layoutSubviews {
	[super layoutSubviews];
	
    [self.player resizePlayerLayerToFitOutputView];
	self.loadingView.frame = self.bounds;
}

- (void) setLoadingView:(UIView *)loadingView {
	if (_loadingView != nil) {
		[_loadingView removeFromSuperview];
	}
	
	_loadingView = loadingView;
	
	if (_loadingView != nil) {
		[self addSubview:_loadingView];
	}
}

- (SCPlayer *)player {
    return _player;
}

- (BOOL)tapToPauseEnabled {
    return _tapToPauseGesture != nil;
}

- (void)setTapToPauseEnabled:(BOOL)tapToPauseEnabled {
    if (tapToPauseEnabled) {
        if (_tapToPauseGesture == nil) {
            _tapToPauseGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOrPause)];
            [self addGestureRecognizer:_tapToPauseGesture];
        }
    } else {
        if (_tapToPauseGesture != nil) {
            [_tapToPauseGesture.view removeGestureRecognizer:_tapToPauseGesture];
            _tapToPauseGesture = nil;
        }
    }
}

@end
