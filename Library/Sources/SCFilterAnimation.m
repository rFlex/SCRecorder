//
//  SCFilterAnimation.m
//  SCRecorder
//
//  Created by Simon CORSIN on 06/05/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import "SCFilterAnimation.h"

@interface SCFilterAnimation() {
    
}

@end

@implementation SCFilterAnimation

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_key forKey:@"Key"];
    [aCoder encodeObject:_startValue forKey:@"StartValue"];
    [aCoder encodeObject:_endValue forKey:@"EndValue"];
    [aCoder encodeDouble:_startTime forKey:@"StartTime"];
    [aCoder encodeDouble:_duration forKey:@"Duration"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    NSString *key = [aDecoder decodeObjectForKey:@"Key"];
    id startValue = [aDecoder decodeObjectForKey:@"StartValue"];
    id endValue = [aDecoder decodeObjectForKey:@"EndValue"];
    CFTimeInterval startTime = [aDecoder decodeDoubleForKey:@"StartTime"];
    CFTimeInterval duration = [aDecoder decodeDoubleForKey:@"Duration"];
    
    return [self initWithKey:key startValue:startValue endValue:endValue startTime:startTime duration:duration];
}

- (id)initWithKey:(NSString *)key startValue:(id)startValue endValue:(id)endValue startTime:(CFTimeInterval)startTime duration:(CFTimeInterval)duration {
    self = [self init];
    
    if (self) {
        _key = key;
        _startValue = startValue;
        _endValue = endValue;
        _startTime = startTime;
        _duration = duration;
        
        if ([startValue isKindOfClass:[NSNumber class]]) {
            
        } else {
            [NSException raise:@"InvalidArgumentException" format:@"Only values as NSNumber's are currently supported"];
        }
    }
    
    return self;
}

- (id)valueAtTime:(CFTimeInterval)time {
    double ratio = (time - _startTime) / _duration;
    double newValue = ([_endValue doubleValue] - [_startValue doubleValue]) * ratio + [_startValue doubleValue];
    
    return [NSNumber numberWithDouble:newValue];
}

- (BOOL)hasValueAtTime:(CFTimeInterval)time {
    return !(time < _startTime || time > _startTime + _duration);
}

+ (SCFilterAnimation *)filterAnimationForParameterKey:(NSString *)key startValue:(id)startValue endValue:(id)endValue startTime:(CFTimeInterval)startTime duration:(CFTimeInterval)duration {
    return [[SCFilterAnimation alloc] initWithKey:key startValue:startValue endValue:endValue startTime:startTime duration:duration];
}

@end
