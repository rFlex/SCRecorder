//
//  SCVideoPlayerViewController.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCVideoPlayerView.h"
#import "SCFilterSwitcherView.h"

@interface SCVideoPlayerViewController : UIViewController<SCPlayerDelegate>

@property (strong, nonatomic) AVAsset *asset;
@property (weak, nonatomic) IBOutlet SCFilterSwitcherView *filterSwitcherView;

@end
