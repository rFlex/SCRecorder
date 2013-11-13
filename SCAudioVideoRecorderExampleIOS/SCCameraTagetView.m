//
//  XHCameraTagetView.m
//  iyilunba
//
//  Created by 曾 宪华 on 13-11-8.
//  Copyright (c) 2013年 曾 宪华 开发团队(http://iyilunba.com ). All rights reserved.
//

#import "SCCameraTagetView.h"

#define kInsideCircleAnimationKey @"insideCircleAnimationKey"
#define kOutsideCircleAnimationKey @"outsideCircleAnimationKey"

#define kRemoveCircleAnimationKey @"removeCircleAnimationKey"

@interface SCCameraTagetView ()

@property (nonatomic, strong) UIImageView *outsideCircle;
@property (nonatomic, strong) UIImageView *insideCircle;


@end

@implementation SCCameraTagetView

- (void)startTageting {
    // 判断是否已经add了这个animation
    if ([self.insideCircle.layer.animationKeys containsObject:kInsideCircleAnimationKey] && [self.outsideCircle.layer.animationKeys containsObject:kOutsideCircleAnimationKey]) {
        return;
    }
    
    if ([self.insideCircle.layer.animationKeys containsObject:kRemoveCircleAnimationKey] && [self.outsideCircle.layer.animationKeys containsObject:kRemoveCircleAnimationKey]) {
        [self.insideCircle.layer removeAnimationForKey:kRemoveCircleAnimationKey];
        [self.outsideCircle.layer removeAnimationForKey:kRemoveCircleAnimationKey];
    }
    
    // insideCircle 微微的闪烁
    CABasicAnimation *insideCircleAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    insideCircleAnimation.beginTime = CACurrentMediaTime() + 0.1;
    insideCircleAnimation.duration = 0.5;
    insideCircleAnimation.fromValue = [NSNumber numberWithFloat:1.0f];
    insideCircleAnimation.toValue = [NSNumber numberWithFloat:0.5f];
    insideCircleAnimation.repeatCount = HUGE_VAL;
    insideCircleAnimation.autoreverses = YES;
    insideCircleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    
    
    // outsideCircle 匀速的缩放
    CABasicAnimation *outsideCircleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    outsideCircleAnimation.beginTime = CACurrentMediaTime() + 0.1;
    outsideCircleAnimation.fromValue = [NSNumber numberWithFloat:1.0f];
    outsideCircleAnimation.toValue = [NSNumber numberWithFloat:0.85f];
    outsideCircleAnimation.repeatCount = HUGE_VAL;
    outsideCircleAnimation.autoreverses = YES;
    outsideCircleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    
    [self.insideCircle.layer addAnimation:insideCircleAnimation forKey:kInsideCircleAnimationKey];
    [self.outsideCircle.layer addAnimation:outsideCircleAnimation forKey:kOutsideCircleAnimationKey];
}

- (void)stopTageting {
    if (!([self.insideCircle.layer.animationKeys containsObject:kInsideCircleAnimationKey] && [self.outsideCircle.layer.animationKeys containsObject:kOutsideCircleAnimationKey])) {
        return;
    }
    
    [self.insideCircle.layer removeAnimationForKey:kInsideCircleAnimationKey];
    [self.outsideCircle.layer removeAnimationForKey:kOutsideCircleAnimationKey];
    
    CABasicAnimation *scaleAniamtion = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAniamtion.fromValue = [NSNumber numberWithFloat:1.0f];
    scaleAniamtion.toValue = [NSNumber numberWithFloat:.0f];
    
    CABasicAnimation *fadeAnim=[CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeAnim.fromValue=[NSNumber numberWithDouble:1.0];
    fadeAnim.toValue=[NSNumber numberWithDouble:0.0];
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.beginTime = CACurrentMediaTime() + 0.3;
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    group.duration = 0.3;
    group.repeatCount = 1;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    group.animations = [NSArray arrayWithObjects:scaleAniamtion, fadeAnim, nil];
    
    [self.insideCircle.layer addAnimation:group forKey:kRemoveCircleAnimationKey];
    [self.outsideCircle.layer addAnimation:group forKey:kRemoveCircleAnimationKey];
}

- (void)stup {
    // insideCircle
    CGRect bounds = self.bounds;
    CGPoint center = CGPointMake(CGRectGetWidth(bounds) / 2.0, CGRectGetHeight(bounds) / 2.0);
    
    CGRect insideCircleFrame = bounds;
    insideCircleFrame.size.width = insideCircleFrame.size.height = insideCircleFrame.size.width - 25;
    _insideCircle = [[UIImageView alloc] initWithFrame:insideCircleFrame];
    _insideCircle.image = [UIImage imageNamed:@"capture_flip"];
    _insideCircle.center = center;
    
    CGRect outsideCircleFrame = bounds;
    outsideCircleFrame.size.width = outsideCircleFrame.size.height = outsideCircleFrame.size.width;
    _outsideCircle = [[UIImageView alloc] initWithFrame:outsideCircleFrame];
    _outsideCircle.image = [UIImage imageNamed:@"capture_flip"];
    _outsideCircle.center = center;
    
    [self addSubview:self.outsideCircle];
    [self addSubview:self.insideCircle];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self stup];
    }
    return self;
}

- (void)dealloc {
    self.insideCircle = nil;
    self.outsideCircle = nil;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
