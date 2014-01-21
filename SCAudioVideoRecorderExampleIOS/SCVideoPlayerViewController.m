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
	
    NSLog(@"Logging use of %@ too see if it's a linker problem", [SCVideoPlayerView class]);
    
	[self.videoPlayerView.player setSmoothLoopItemByUrl:self.videoUrl smoothLoopCount:10];

	self.videoPlayerView.player.shouldLoop = YES;
	[self.videoPlayerView.player play];
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
