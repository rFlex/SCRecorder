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

@interface SCVideoPlayerView : UIView<SCVideoPlayerDelegate>

@property (strong, nonatomic, readonly) SCPlayer * player;
@property (strong, nonatomic, readwrite) UIView * loadingView;

@end
