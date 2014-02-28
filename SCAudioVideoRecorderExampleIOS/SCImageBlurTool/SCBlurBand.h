//
//  SCBlurBand.h
//  SCAudioVideoRecorder
//
//  Created by 曾 宪华 on 13-12-4.
//  Copyright (c) 2013年 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCBlurBand : UIView
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) CGFloat rotation;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) CGFloat offset;
@end
