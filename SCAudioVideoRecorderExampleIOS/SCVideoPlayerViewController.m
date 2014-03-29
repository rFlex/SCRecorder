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

- (void) dealloc {
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    SCPlayer *player = self.videoPlayerView.player;
    
    if (self.videoUrl != nil) {
        [player setSmoothLoopItemByUrl:self.videoUrl smoothLoopCount:10];
    }
    
	player.shouldLoop = YES;
	[player play];
}

- (void) viewWillAppear:(BOOL)animated {
	self.navigationController.navigationBarHidden = NO;
}

- (void) viewDidDisappear:(BOOL)animated {
	self.navigationController.navigationBarHidden = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
