//
//  SCImageViewDisPlayViewController.m
//  SCAudioVideoRecorder
//
//  Created by 曾 宪华 on 13-11-5.
//  Copyright (c) 2013年 rFlex. All rights reserved.
//

#import "SCImageViewDisPlayViewController.h"
#import "SCImageBlurTool.h"

@interface SCImageViewDisPlayViewController ()
@property (nonatomic, strong) SCImageBlurTool *imageBlurTool;
@end

@implementation SCImageViewDisPlayViewController

#pragma mark - Left cycle init

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.title = NSLocalizedString(@"PhotoEditor", @"");
        
    if (self.photo)
        self.disPlayImageView.image = self.photo;
    
    _imageBlurTool = [[SCImageBlurTool alloc] initWithImageEditor:self];
    [self.imageBlurTool setup];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
