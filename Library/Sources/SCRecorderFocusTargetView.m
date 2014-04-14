//
//  XHCameraTagetView.m
//  iyilunba
//
//  Created by 曾 宪华 on 13-11-8.
//  Copyright (c) 2013年 曾 宪华 开发团队(http://iyilunba.com ). All rights reserved.
//

#import "SCRecorderFocusTargetView.h"

#define kInsideCircleAnimationKey @"insideCircleAnimationKey"
#define kOutsideCircleAnimationKey @"outsideCircleAnimationKey"

#define kRemoveCircleAnimationKey @"removeCircleAnimationKey"

@interface SCRecorderFocusTargetView ()

@property (nonatomic, strong) UIImageView *outsideCircle;
@property (nonatomic, strong) UIImageView *insideCircle;

@end

@implementation SCRecorderFocusTargetView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    self.insideFocusTargetImageSizeRatio = 0.5;
    CGRect bounds = self.bounds;
    CGPoint center = CGPointMake(CGRectGetWidth(bounds) / 2.0, CGRectGetHeight(bounds) / 2.0);
    
    CGRect insideCircleFrame = bounds;
    insideCircleFrame.size.width = insideCircleFrame.size.height = insideCircleFrame.size.width - 25;
    UIImageView *insideCircle = [[UIImageView alloc] initWithFrame:insideCircleFrame];
    insideCircle.image = nil;
    insideCircle.center = center;
    self.insideCircle = insideCircle;
    
    CGRect outsideCircleFrame = bounds;
    outsideCircleFrame.size.width = outsideCircleFrame.size.height = outsideCircleFrame.size.width;
    UIImageView *outsideCircle = [[UIImageView alloc] initWithFrame:outsideCircleFrame];
    outsideCircle.image = nil;
    outsideCircle.center = center;
    self.outsideCircle = outsideCircle;
    
    [self addSubview:self.outsideCircle];
    [self addSubview:self.insideCircle];
}

- (void)startTargeting {
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

- (void)stopTargeting {
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

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGRect frame = self.bounds;
    self.outsideCircle.frame = frame;
    
    float width = self.bounds.size.width;
    float height = self.bounds.size.height;
    
    frame.size.width = width * self.insideFocusTargetImageSizeRatio;
    frame.size.height = height * self.insideFocusTargetImageSizeRatio;
    frame.origin.x = width / 2 - frame.size.width / 2;
    frame.origin.y = height / 2 - frame.size.height / 2;
    
    self.insideCircle.frame = frame;
}

- (UIImage*)insideFocusTargetImage
{
    return self.insideCircle.image;
}

- (void)setInsideFocusTargetImage:(UIImage *)insideFocusTargetImage
{
    self.insideCircle.image = insideFocusTargetImage;
}

- (UIImage*)outsideFocusTargetImage
{
    return self.outsideCircle.image;
}

- (void)setOutsideFocusTargetImage:(UIImage *)outsideFocusTargetImage
{
    self.outsideCircle.image = outsideFocusTargetImage;
}

@end
