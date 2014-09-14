//
//  SCVideoPlayerView.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPlayer.h"
#import "SCImageView.h"

@class SCVideoPlayerView;

@protocol SCVideoPlayerViewDelegate <NSObject>

- (void)videoPlayerViewTappedToPlay:(SCVideoPlayerView *)videoPlayerView;

- (void)videoPlayerViewTappedToPause:(SCVideoPlayerView *)videoPlayerView;

@end

@interface SCVideoPlayerView : UIView

@property (weak, nonatomic) id<SCVideoPlayerViewDelegate> delegate;

@property (strong, nonatomic) SCPlayer *player;

/**
 The underlying AVPlayerLayer used for displaying the video. This property
 will be set only if SCImageViewEnabled if false.
 */
@property (readonly, nonatomic) AVPlayerLayer *playerLayer;

/**
 The underlying SCImageView used for displaying the video. This property
 will be set only if SCImageViewEnabled is true.
 */
@property (readonly, nonatomic) SCImageView *SCImageView;

/**
 If enabled, tapping on the view will pause/unpause the player.
 */
@property (assign, nonatomic) BOOL tapToPauseEnabled;

/**
 Whether it should create and use an SCImageView for displaying the frames.
 If false (the default), the SCVideoPlayerView will use the default Apple provided
 AVPlayerLayer for rendering fhe frames.
 */
@property (assign, nonatomic) BOOL SCImageViewEnabled;

/**
 Init the SCVideoPlayerView with a provided SCPlayer.
 */
- (id)initWithPlayer:(SCPlayer *)player;

/**
 Set whether every new instances of SCVideoPlayerView should automatically create
 and hold an SCPlayer when needed. If disabled, an external SCPlayer must be set
 manually to each SCVideoPlayerView instance in order to work properly. Default is YES.
 */
+ (void)setAutoCreatePlayerWhenNeeded:(BOOL)autoCreatePlayerWhenNeeded;

/**
 Whether every new instances of SCVideoPlayerView should automatically create and hold an SCPlayer
 when needed. If disabled, an external SCPlayer must be set manually to each
 SCVideoPlayerView instance in order to work properly. Default is YES.
 */
+ (BOOL)autoCreatePlayerWhenNeeded;

@end
