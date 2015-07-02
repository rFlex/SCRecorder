//
//  SCFilterAnimation.h
//  SCRecorder
//
//  Created by Simon CORSIN on 06/05/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCFilterAnimation : NSObject<NSCoding>

@property (readonly, nonatomic) NSString *__nonnull key;

@property (readonly, nonatomic) __nullable id startValue;

@property (readonly, nonatomic) __nullable id endValue;

@property (readonly, nonatomic) CFTimeInterval startTime;

@property (readonly, nonatomic) CFTimeInterval duration;

- (__nullable id)valueAtTime:(CFTimeInterval)time;

- (BOOL)hasValueAtTime:(CFTimeInterval)time;

+ (SCFilterAnimation *__nonnull)filterAnimationForParameterKey:(NSString *__nonnull)key startValue:(__nullable id)startValue endValue:(__nullable id)endValue startTime:(CFTimeInterval)startTime duration:(CFTimeInterval)duration;

@end
