//
//  SCVideoPlayerViewController.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCVideoPlayerViewController.h"

@interface SCVideoPlayerViewController () {
    NSArray *_filterGroups;
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
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _filterGroups = @[
                      [NSNull null],
                      [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectNoir"]]
                      ];
    
    NSMutableArray *outputArray = [NSMutableArray new];
    for (int i = 0; i < 2; i++) {
        for (id obj in _filterGroups) {
            [outputArray addObject:obj];
        }
    }
    
    self.filterImageView.filterGroups = outputArray;
    
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * self.filterImageView.filterGroups.count, self.scrollView.frame.size.height);
	
    SCPlayer *player = self.videoPlayerView.player;
    player.delegate = self;
    player.outputView = nil;
    player.useCoreImageView = YES;
    
    if (self.asset != nil) {
        [player setItemByAsset:self.asset];
//        [player setSmoothLoopItemByAsset:self.asset smoothLoopCount:10];
    }
    
	player.shouldLoop = YES;
	[player play];
    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat width = scrollView.frame.size.width;
    CGFloat contentOffsetX = scrollView.contentOffset.x;
    CGFloat contentSizeWidth = scrollView.contentSize.width;
    CGFloat normalWidth = _filterGroups.count * width;
    
    
    if (contentOffsetX < 0) {
        scrollView.contentOffset = CGPointMake(contentOffsetX + normalWidth, scrollView.contentOffset.y);
    } else if (contentOffsetX + width > contentSizeWidth) {
        scrollView.contentOffset = CGPointMake(contentOffsetX - normalWidth, scrollView.contentOffset.y);
    }
    
    CGFloat ratio = scrollView.contentOffset.x / width;
    
    self.filterImageView.filterGroupIndexRatio = ratio;
}

- (SCImageView *)outputImageViewForPlayer:(SCPlayer *)player {
    return self.filterImageView;
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

@end
