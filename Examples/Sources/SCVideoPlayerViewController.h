//
//  SCVideoPlayerViewController.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCVideoPlayerView.h"
#import "SCFilterImageView.h"

@interface SCVideoPlayerViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, SCPlayerDelegate>

@property (weak, nonatomic) IBOutlet SCVideoPlayerView *videoPlayerView;
@property (weak, nonatomic) IBOutlet SCFilterImageView *filterImageView;
@property (strong, nonatomic) AVAsset *asset;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

@end
