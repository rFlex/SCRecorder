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

@end
