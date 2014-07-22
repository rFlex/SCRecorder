//
//  SCVideoPlayerView.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPlayer.h"

@class SCVideoPlayerView;

@protocol SCVideoPlayerViewDelegate <NSObject>

- (void)videoPlayerViewTappedToPlay:(SCVideoPlayerView *)videoPlayerView;

- (void)videoPlayerViewTappedToPause:(SCVideoPlayerView *)videoPlayerView;

@end

@interface SCVideoPlayerView : UIView<SCPlayerDelegate>

@property (readonly, nonatomic) SCPlayer * player;
@property (weak, nonatomic) id<SCVideoPlayerViewDelegate> delegate;
@property (assign, nonatomic) BOOL tapToPauseEnabled;

- (id)initWithPlayer:(SCPlayer *)player;

@end
