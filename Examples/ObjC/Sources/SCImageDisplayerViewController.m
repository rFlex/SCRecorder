//
//  SCImageViewDisPlayViewController.m
//  SCAudioVideoRecorder
//
//  Created by 曾 宪华 on 13-11-5.
//  Copyright (c) 2013年 rFlex. All rights reserved.
//

#import "SCImageDisplayerViewController.h"

@interface SCImageDisplayerViewController () {
}
@end

@implementation SCImageDisplayerViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = NO;
    
    [self.filterSwitcherView setImageByUIImage:self.photo];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    [self.filterSwitcherView setNeedsDisplay];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStylePlain target:self action:@selector(saveToCameraRoll)];
    
    self.filterSwitcherView.contentMode = UIViewContentModeScaleAspectFit;
    
    self.filterSwitcherView.filters = @[
                                             [SCFilter emptyFilter],
                                             [SCFilter filterWithCIFilterName:@"CIPhotoEffectNoir"],
                                             [SCFilter filterWithCIFilterName:@"CIPhotoEffectChrome"],
                                             [SCFilter filterWithCIFilterName:@"CIPhotoEffectInstant"],
                                             [SCFilter filterWithCIFilterName:@"CIPhotoEffectTonal"],
                                             [SCFilter filterWithCIFilterName:@"CIPhotoEffectFade"]
                                             ];
}

- (void)saveToCameraRoll {
    UIImage *image = [self.filterSwitcherView renderedUIImage];
    
    [image saveToCameraRollWithCompletion:^(NSError * _Nullable error) {
        if (error == nil) {
            [[[UIAlertView alloc] initWithTitle:@"Done!" message:@"" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Failed :(" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
    }];
}

@end
