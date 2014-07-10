//
//  SCVideoPlayerViewController.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCVideoPlayerViewController.h"

@interface SCVideoPlayerViewController () {
    SCPlayer *_player;
}

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

- (void)dealloc {
    self.filterSwitcherView = nil;
    [_player pause];
    _player = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.filterSwitcherView.filterGroups = @[
                                             [NSNull null],
//                                             [SCFilterGroup filterGroupWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"blitch" withExtension:@"cisf"]],
                                             [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectNoir"]],
                                             [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectChrome"]],
                                             [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectInstant"]],
                                             [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectTonal"]],
                                             [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectFade"]]                                    
                                             ];
    
    
    // On iPhone 4 and below, this property should be set to YES
    self.filterSwitcherView.disabled = NO;;
    
	_player = [SCPlayer player];
    self.filterSwitcherView.player = _player;

    if (self.asset != nil) {
        [_player setItemByAsset:self.asset];
    }
    
	_player.shouldLoop = YES;
	[_player play];
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
}

@end
