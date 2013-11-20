//
//  XHBlurOverlayView.m
//  iyilunba
//
//  Created by 曾 宪华 on 13-11-19.
//  Copyright (c) 2013年 曾 宪华 开发团队(http://iyilunba.com ). All rights reserved. 本人QQ 543413507
//

#import "SCBlurOverlayView.h"

@interface SCBlurOverlayView () {
    CGRect holeRect;
}

@end

@implementation SCBlurOverlayView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _radius = 80.0f;
        // Initialization code
        self.userInteractionEnabled = NO;
        self.opaque = NO;
        CGPoint center = CGPointMake(CGRectGetMidX(frame),CGRectGetMidY(frame));
        holeRect = CGRectMake(center.x-self.radius, center.y-self.radius, self.radius*2, self.radius*2);
    }
    return self;
}

-(void) setCircleCenter:(CGPoint)circleCenter{
    _circleCenter = circleCenter;
    holeRect = CGRectMake(circleCenter.x-self.radius, circleCenter.y-self.radius,
                          self.radius*2,
                          self.radius*2);
    [self setNeedsDisplay];
}

-(void) setRadius:(CGFloat)radius{
    _radius = radius;
    CGPoint center = CGPointMake(CGRectGetMidX(holeRect),CGRectGetMidY(holeRect));
    holeRect = CGRectMake(center.x-self.radius, center.y-self.radius,
                          self.radius*2,
                          self.radius*2);
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    size_t numLocations = 2;
    CGFloat locations[2] = {0.0, 1.0};
    CGFloat components[8] = {1.0,1.0,1.0, 0.0,
        1.0, 1.0, 1.0, 1.0};
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace,
                                                                 components,
                                                                 locations,
                                                                 numLocations);
    CGPoint center = CGPointMake(CGRectGetMidX(holeRect),CGRectGetMidY(holeRect));
    CGContextDrawRadialGradient(context, gradient, center,
                                self.radius - 25.0, center, self.radius,
                                kCGGradientDrawsAfterEndLocation);
    CGColorSpaceRelease(colorSpace);
    CGGradientRelease(gradient);
}

@end
