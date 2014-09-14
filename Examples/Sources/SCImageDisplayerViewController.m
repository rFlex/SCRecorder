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

- (CGAffineTransform)getImageTransform:(UIImage *)image {
    if (image.imageOrientation == UIImageOrientationUp) {
        return CGAffineTransformIdentity;
    }
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (image.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, image.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, 0);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, image.size.height);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }
    
    switch (image.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }
    
    return transform;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = NO;
    
//    self.filterSwitcherView.transform = [self getImageTransform:self.photo];
    
    self.filterSwitcherView.CIImage = [CIImage imageWithCGImage:self.photo.CGImage];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStylePlain target:self action:@selector(saveToCameraRoll)];
    
    self.filterSwitcherView.contentMode = UIViewContentModeScaleAspectFit;
    
    self.filterSwitcherView.filterGroups = @[
                                             [NSNull null],
                                             [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectNoir"]],
                                             [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectChrome"]],
                                             [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectInstant"]],
                                             [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectTonal"]],
                                             [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectFade"]]
                                             ];

	// Do any additional setup after loading the view.
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error == nil) {
        [[[UIAlertView alloc] initWithTitle:@"Done!" message:@"" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    } else {
        [[[UIAlertView alloc] initWithTitle:@"Failed :(" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }
    
}

- (void)saveToCameraRoll {
    UIImage *image = [self.filterSwitcherView currentlyDisplayedImageWithScale:self.photo.scale orientation:self.photo.imageOrientation];
    
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

@end
