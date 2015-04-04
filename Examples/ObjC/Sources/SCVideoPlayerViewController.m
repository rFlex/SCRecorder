//
//  SCVideoPlayerViewController.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCVideoPlayerViewController.h"
#import "SCEditVideoViewController.h"

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
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleBordered target:self action:@selector(saveToCameraRoll)];
    
	_player = [SCPlayer player];
    
    if ([[NSProcessInfo processInfo] activeProcessorCount] > 1) {
        self.filterSwitcherView.refreshAutomaticallyWhenScrolling = NO;
        self.filterSwitcherView.contentMode = UIViewContentModeScaleAspectFit;
        
        self.filterSwitcherView.filters = @[
                                                 [SCFilter emptyFilter],
                                                 [SCFilter filterWithCIFilterName:@"CIPhotoEffectNoir"],
                                                 [SCFilter filterWithCIFilterName:@"CIPhotoEffectChrome"],
                                                 [SCFilter filterWithCIFilterName:@"CIPhotoEffectInstant"],
                                                 [SCFilter filterWithCIFilterName:@"CIPhotoEffectTonal"],
                                                 [SCFilter filterWithCIFilterName:@"CIPhotoEffectFade"]//,
                                                 // Adding a filter created using CoreImageShop
//                                                 [SCFilter filterWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"a_filter" withExtension:@"cisf"]]
                                                 ];
        _player.CIImageRenderer = self.filterSwitcherView;
    } else {
        SCVideoPlayerView *playerView = [[SCVideoPlayerView alloc] initWithPlayer:_player];
        playerView.frame = self.filterSwitcherView.frame;
        playerView.autoresizingMask = self.filterSwitcherView.autoresizingMask;
        [self.filterSwitcherView.superview insertSubview:playerView aboveSubview:self.filterSwitcherView];
        [self.filterSwitcherView removeFromSuperview];
    }
    
	_player.loopEnabled = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
        
    [_player setItemByAsset:_recordSession.assetRepresentingSegments];
	[_player play];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_player pause];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[SCEditVideoViewController class]]) {
        SCEditVideoViewController *editVideo = segue.destinationViewController;
        editVideo.recordSession = self.recordSession;
    }
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo: (void *) contextInfo {
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];

    if (error == nil) {
        [[[UIAlertView alloc] initWithTitle:@"Saved to camera roll" message:@"" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    } else {
        [[[UIAlertView alloc] initWithTitle:@"Failed to save" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }
}

- (void)saveToCameraRoll {
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    SCFilter *currentFilter = self.filterSwitcherView.selectedFilter;
    
    void(^completionHandler)(NSURL *url, NSError *error) = ^(NSURL *url, NSError *error) {
        if (error == nil) {
            UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        } else {
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];

            [[[UIAlertView alloc] initWithTitle:@"Failed to save" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
    };
    
    if (currentFilter == nil || currentFilter.isEmpty) {
        [self.recordSession mergeSegmentsUsingPreset:AVAssetExportPresetHighestQuality completionHandler:completionHandler];
    } else {
        SCAssetExportSession *exportSession = [[SCAssetExportSession alloc] initWithAsset:self.recordSession.assetRepresentingSegments];
        exportSession.videoConfiguration.filter = currentFilter;
        exportSession.videoConfiguration.preset = SCPresetHighestQuality;
        exportSession.audioConfiguration.preset = SCPresetHighestQuality;
        exportSession.videoConfiguration.maxFrameRate = 35;
        exportSession.outputUrl = self.recordSession.outputUrl;
        exportSession.outputFileType = AVFileTypeMPEG4;
        
        // Adding our "fancy" watermark
        UILabel *label = [UILabel new];
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont boldSystemFontOfSize:40];
        label.text = @"SCRecorder ©";
        [label sizeToFit];
        
        UIGraphicsBeginImageContext(label.frame.size);
        
        [label.layer renderInContext:UIGraphicsGetCurrentContext()];
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
        
        exportSession.videoConfiguration.watermarkImage = image;
        exportSession.videoConfiguration.watermarkFrame = CGRectMake(10, 10, label.frame.size.width, label.frame.size.height);
        exportSession.videoConfiguration.watermarkAnchorLocation = SCWatermarkAnchorLocationBottomRight;
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            completionHandler(exportSession.outputUrl, exportSession.error);
        }];
    }
}

@end
