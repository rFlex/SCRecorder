//
//  SCVideoPlayerViewController.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCVideoPlayerViewController.h"
#import "SCEditVideoViewController.h"
#import "SCWatermarkOverlayView.h"

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
    [self.filterSwitcherView removeObserver:self forKeyPath:@"selectedFilter"];
    self.filterSwitcherView = nil;
    [_player pause];
    _player = nil;
}

- (SCFilter *)createAnimatedFilter {
    SCFilter *animatedFilter = [SCFilter emptyFilter];
    animatedFilter.name = @"Animated Filter";
    
    SCFilter *gaussian = [SCFilter filterWithCIFilterName:@"CIGaussianBlur"];
    SCFilter *blackAndWhite = [SCFilter filterWithCIFilterName:@"CIColorControls"];
    
    [animatedFilter addSubFilter:gaussian];
    [animatedFilter addSubFilter:blackAndWhite];
    
    double duration = 0.5;
    double currentTime = 0;
    BOOL isAscending = YES;
    
    Float64 assetDuration = CMTimeGetSeconds(_recordSession.assetRepresentingSegments.duration);
    
    while (currentTime < assetDuration) {
        if (isAscending) {
            [blackAndWhite addAnimationForParameterKey:kCIInputSaturationKey startValue:@1 endValue:@0 startTime:currentTime duration:duration];
            [gaussian addAnimationForParameterKey:kCIInputRadiusKey startValue:@0 endValue:@10 startTime:currentTime duration:duration];
        } else {
            [blackAndWhite addAnimationForParameterKey:kCIInputSaturationKey startValue:@0 endValue:@1 startTime:currentTime duration:duration];
            [gaussian addAnimationForParameterKey:kCIInputRadiusKey startValue:@10 endValue:@0 startTime:currentTime duration:duration];
        }
        
        currentTime += duration;
        isAscending = !isAscending;
    }
    
    return animatedFilter;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.exportView.clipsToBounds = YES;
    self.exportView.layer.cornerRadius = 20;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleBordered target:self action:@selector(saveToCameraRoll)];
    
	_player = [SCPlayer player];
    
    if ([[NSProcessInfo processInfo] activeProcessorCount] > 1) {
        self.filterSwitcherView.refreshAutomaticallyWhenScrolling = NO;
        self.filterSwitcherView.contentMode = UIViewContentModeScaleAspectFill;
        
        SCFilter *emptyFilter = [SCFilter emptyFilter];
        emptyFilter.name = @"#nofilter";
        
        self.filterSwitcherView.filters = @[
                                                 emptyFilter,
                                                 [SCFilter filterWithCIFilterName:@"CIPhotoEffectNoir"],
                                                 [SCFilter filterWithCIFilterName:@"CIPhotoEffectChrome"],
                                                 [SCFilter filterWithCIFilterName:@"CIPhotoEffectInstant"],
                                                 [SCFilter filterWithCIFilterName:@"CIPhotoEffectTonal"],
                                                 [SCFilter filterWithCIFilterName:@"CIPhotoEffectFade"],
                                                 // Adding a filter created using CoreImageShop
                                                 [SCFilter filterWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"a_filter" withExtension:@"cisf"]],
                                                 [self createAnimatedFilter]
                                                 ];
        _player.CIImageRenderer = self.filterSwitcherView;
        [self.filterSwitcherView addObserver:self forKeyPath:@"selectedFilter" options:NSKeyValueObservingOptionNew context:nil];
    } else {
        SCVideoPlayerView *playerView = [[SCVideoPlayerView alloc] initWithPlayer:_player];
        playerView.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.filterSwitcherView) {
        self.filterNameLabel.hidden = NO;
        self.filterNameLabel.text = self.filterSwitcherView.selectedFilter.name;
        self.filterNameLabel.alpha = 0;
        [UIView animateWithDuration:0.3 animations:^{
            self.filterNameLabel.alpha = 1;
        } completion:^(BOOL finished) {
            if (finished) {
                [UIView animateWithDuration:0.3 delay:1 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                    self.filterNameLabel.alpha = 0;
                } completion:^(BOOL finished) {
                    
                }];
            }
        }];
    }
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

- (void)assetExportSessionDidProgress:(SCAssetExportSession *)assetExportSession {
    dispatch_async(dispatch_get_main_queue(), ^{
        float progress = assetExportSession.progress;
        
        CGRect frame =  self.progressView.frame;
        frame.size.width = self.progressView.superview.frame.size.width * progress;
        self.progressView.frame = frame;
    });
}

- (void)saveToCameraRoll {
    SCFilter *currentFilter = [self.filterSwitcherView.selectedFilter copy];
    [_player pause];
    
    void(^completionHandler)(NSURL *url, NSError *error) = ^(NSURL *url, NSError *error) {
        if (error == nil) {
            [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
            UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Failed to save" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
    };
    
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];

    SCAssetExportSession *exportSession = [[SCAssetExportSession alloc] initWithAsset:self.recordSession.assetRepresentingSegments];
    exportSession.videoConfiguration.filter = currentFilter;
    exportSession.videoConfiguration.preset = SCPresetHighestQuality;
    exportSession.audioConfiguration.preset = SCPresetHighestQuality;
    exportSession.videoConfiguration.maxFrameRate = 35;
    exportSession.outputUrl = self.recordSession.outputUrl;
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.delegate = self;
    
    self.exportView.hidden = NO;
    self.exportView.alpha = 0;
    CGRect frame =  self.progressView.frame;
    frame.size.width = 0;
    self.progressView.frame = frame;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.exportView.alpha = 1;
    }];

    SCWatermarkOverlayView *overlay = [SCWatermarkOverlayView new];
    overlay.date = self.recordSession.date;
    exportSession.videoConfiguration.overlay = overlay;
        
    CFTimeInterval time = CACurrentMediaTime();
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        [_player play];

        NSLog(@"Completed compression in %fs", CACurrentMediaTime() - time);
        
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        
        [UIView animateWithDuration:0.3 animations:^{
            self.exportView.alpha = 0;
        }];
        
        completionHandler(exportSession.outputUrl, exportSession.error);
    }];
}

@end
