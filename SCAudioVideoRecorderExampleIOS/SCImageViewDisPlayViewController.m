//
//  SCImageViewDisPlayViewController.m
//  SCAudioVideoRecorder
//
//  Created by 曾 宪华 on 13-11-5.
//  Copyright (c) 2013年 rFlex. All rights reserved.
//

#import "SCImageViewDisPlayViewController.h"
#import "SCBlurOverlayView.h"

@interface SCImageViewDisPlayViewController ()
@property (strong, nonatomic) SCBlurOverlayView *blurOverlayView;
@property (assign, nonatomic) BOOL hasBlur;
@property (assign, nonatomic) CGFloat radius;
@end

@implementation SCImageViewDisPlayViewController

#pragma mark - Propertys

- (SCBlurOverlayView *)blurOverlayView {
    if (!_blurOverlayView) {
        UIImageView *disPlayImageView = self.disPlayImageView;
        _blurOverlayView = [[SCBlurOverlayView alloc] initWithFrame:disPlayImageView.bounds];
        _blurOverlayView.alpha = 0;
        [disPlayImageView addSubview:self.blurOverlayView];
    }
    return _blurOverlayView;
}

#pragma mark - Left cycle init

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)_setupGesture {
    UIImageView *disPlayImageView = self.disPlayImageView;
    disPlayImageView.userInteractionEnabled = YES;
    
    UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchGestureRecognizerHandle:)];
    [disPlayImageView addGestureRecognizer:pinchGestureRecognizer];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognizerHandle:)];
    panGestureRecognizer.minimumNumberOfTouches = 1;
    [disPlayImageView addGestureRecognizer:panGestureRecognizer];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    [self _setupGesture];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Blur", @"") style:UIBarButtonItemStyleBordered target:self action:@selector(toggleBlur)];
    
    if (self.photo)
        self.disPlayImageView.image = self.photo;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UIGestureRecognizer handle

-(void)panGestureRecognizerHandle:(UIGestureRecognizer *) sender {
    if (self.hasBlur) {
        CGPoint tapPoint = [sender locationInView:sender.view];
        if ([sender state] == UIGestureRecognizerStateBegan) {
            [self showBlurOverlay:YES];
        }
        
        if ([sender state] == UIGestureRecognizerStateBegan || [sender state] == UIGestureRecognizerStateChanged) {
            [self.blurOverlayView setCircleCenter:tapPoint];
        }
        
        if([sender state] == UIGestureRecognizerStateEnded){
            [self showBlurOverlay:NO];
        }
    }
}

-(void)pinchGestureRecognizerHandle:(UIPinchGestureRecognizer *) sender {
    if (self.hasBlur) {
        CGPoint midpoint = [sender locationInView:sender.view];
        if ([sender state] == UIGestureRecognizerStateBegan) {
            [self showBlurOverlay:YES];
        }
        
        if ([sender state] == UIGestureRecognizerStateBegan || [sender state] == UIGestureRecognizerStateChanged) {
            self.blurOverlayView.circleCenter = CGPointMake(midpoint.x, midpoint.y);
            CGFloat radius = MAX(MIN(sender.scale*self.radius, 0.6f), 0.15f);
            self.blurOverlayView.radius = radius*CGRectGetWidth(self.view.bounds);
            self.radius = radius;
            sender.scale = 1.0f;
        }
        
        if ([sender state] == UIGestureRecognizerStateEnded) {
            [self showBlurOverlay:NO];
        }
    }
}

#pragma mark - Blur

- (void)toggleBlur {
    
    if (self.hasBlur) {
        self.hasBlur = NO;
        [self showBlurOverlay:NO];
    } else {
        self.hasBlur = YES;
        [self flashBlurOverlay];
    }
}

-(void) showBlurOverlay:(BOOL)show{
    if(show){
        [UIView animateWithDuration:0.2 delay:0 options:0 animations:^{
            self.blurOverlayView.alpha = 0.6;
        } completion:^(BOOL finished) {
            
        }];
    }else{
        [UIView animateWithDuration:0.35 delay:0.2 options:0 animations:^{
            self.blurOverlayView.alpha = 0;
        } completion:^(BOOL finished) {
            
        }];
    }
}

-(void) flashBlurOverlay {
    [UIView animateWithDuration:0.2 delay:0 options:0 animations:^{
        self.blurOverlayView.alpha = 0.6;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.35 delay:0.2 options:0 animations:^{
            self.blurOverlayView.alpha = 0;
        } completion:^(BOOL finished) {
            
        }];
    }];
}

@end
