//
//  SCVideoPlayerViewController.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCVideoPlayerViewController.h"

@interface SCVideoPlayerViewController ()

@end

@implementation SCVideoPlayerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	[self.videoPlayerView.player setItemByStringPath:@"https://v.cdn.vine.co/r/videos/C7EDC2F6EE981816034254524416_19c10057e43.3.1_3qHAGX7s6yiU7RIV_DJ4NNlDaaJjixmQY1pWf9.CBHb3Q6bZqfSRfwu8IciIigqI.mp4"];
	[self.videoPlayerView.player play];
	self.videoPlayerView.player.shouldLoop = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
