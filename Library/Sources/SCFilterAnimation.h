//
//  SCFilterAnimation.h
//  SCRecorder
//
//  Created by Simon CORSIN on 06/05/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCFilterAnimation : NSObject<NSCoding>

@property (readonly, nonatomic) NSString *key;

@property (readonly, nonatomic) id startValue;

@property (readonly, nonatomic) id endValue;

@property (readonly, nonatomic) CFTimeInterval startTime;

@property (readonly, nonatomic) CFTimeInterval duration;

- (id)valueAtTime:(CFTimeInterval)time;

- (BOOL)hasValueAtTime:(CFTimeInterval)time;

+ (SCFilterAnimation *)filterAnimationForParameterKey:(NSString *)key startValue:(id)startValue endValue:(id)endValue startTime:(CFTimeInterval)startTime duration:(CFTimeInterval)duration;

@end
