//
//  SCImageViewDisPlayViewController.h
//  SCAudioVideoRecorder
//
//  Created by 曾 宪华 on 13-11-5.
//  Copyright (c) 2013年 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCImageViewDisPlayViewController : UIViewController
@property (nonatomic, strong) UIImage *photo;
@property (weak, nonatomic) IBOutlet UIImageView *disPlayImageView;

@end
