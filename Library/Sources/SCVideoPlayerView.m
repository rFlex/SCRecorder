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
    BOOL _holdPlayer;
    UITapGestureRecognizer *_tapToPauseGesture;
}

@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCVideoPlayerView

- (id)init {
	self = [super init];
	
	if (self) {
        [self _commonInit:nil];
	}
	
	return self;
}

- (id)initWithPlayer:(SCPlayer *)thePlayer {
    self = [super init];
    
    if (self) {
        [self _commonInit:thePlayer];
    }
    
    return self;
}

- (void)dealloc {
    if (_holdPlayer) {
        [self.player pause];
        [self.player endSendingPlayMessages];
    }
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	
	if (self) {
        [self _commonInit:nil];
	}
	
	return self;
}

- (void)_commonInit:(SCPlayer *)player {
    self.SCImageViewEnabled = NO;
    
    BOOL holdPlayer = NO;
    if (player == nil && [SCVideoPlayerView autoCreatePlayerWhenNeeded]) {
        player = [SCPlayer player];
        holdPlayer = YES;
    }
    self.player = player;
    _holdPlayer = holdPlayer;
    
	self.clipsToBounds = YES;
}

- (void)tapOrPause {
    id<SCVideoPlayerViewDelegate> delegate = self.delegate;
    
    if (!self.player.isPlaying) {
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

- (void)layoutSubviews {
	[super layoutSubviews];
	
    _playerLayer.frame = self.bounds;
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

- (void)setPlayer:(SCPlayer *)player {
    if (player != _player) {
        _player.CIImageRenderer = nil;
        
        _player = player;
        
        _player.CIImageRenderer = _SCImageView;
        _playerLayer.player = player;
        
        _holdPlayer = NO;
    }
}

- (void)setSCImageViewEnabled:(BOOL)SCImageViewEnabled {
    _SCImageViewEnabled = SCImageViewEnabled;
    
    if (SCImageViewEnabled) {
        if (_playerLayer != nil) {
            [_playerLayer removeFromSuperlayer];
            _playerLayer.player = nil;
            _playerLayer = nil;
        }
        
        if (_SCImageView == nil) {
            _SCImageView = [SCImageView new];
            [self insertSubview:_SCImageView atIndex:0];
            _player.CIImageRenderer = _SCImageView;
        }
    } else {
        if (_SCImageView != nil) {
            [_SCImageView removeFromSuperview];
            _SCImageView = nil;
            _player.CIImageRenderer = nil;
        }
        if (_playerLayer == nil) {
            _playerLayer = [AVPlayerLayer new];
            [self.layer insertSublayer:_playerLayer atIndex:0];
        }
    }
    
    [self setNeedsLayout];
}

static BOOL _autoCreatePlayerWhenNeeded = YES;

+ (BOOL)autoCreatePlayerWhenNeeded {
    return _autoCreatePlayerWhenNeeded;
}

+ (void)setAutoCreatePlayerWhenNeeded:(BOOL)autoCreatePlayerWhenNeeded {
    _autoCreatePlayerWhenNeeded = autoCreatePlayerWhenNeeded;
}

@end
