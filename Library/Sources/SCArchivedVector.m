//
//  SCArchivedVector.m
//  SCRecorder
//
//  Created by Simon CORSIN on 21/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCArchivedVector.h"

@interface SCArchivedVector() {
}

@end

@implementation SCArchivedVector

- (id)initWithVector:(CIVector *)vector name:(NSString *)name {
    self = [self init];
    
    if (self) {
        _vector = vector;
        _name = name;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    NSUInteger length;
    
    NSString *name = [aDecoder decodeObjectForKey:@"name"];
    const double *inputValues = (double *)[aDecoder decodeBytesForKey:@"vector_data" returnedLength:&length];
    
    if (inputValues == nil) {
        return nil;
    }
    
    NSUInteger itemCount = length / sizeof(double);
    CGFloat *values = malloc(itemCount * sizeof(CGFloat));
    
    if (values == nil) {
        return nil;
    }
    
    for (int i = 0; i < itemCount; i++) {
        values[i] = (CGFloat)inputValues[i];
    }
    
    CIVector *vector = [CIVector vectorWithValues:values count:itemCount];
    
    free(values);
    
    return [self initWithVector:vector name:name];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_name forKey:@"name"];
    size_t count = _vector.count;
    size_t vectorDataSize = count * sizeof(double);
    double *vectorData = malloc(vectorDataSize);
    
    if (vectorData != nil) {
        for (int i = 0; i < count; i++) {
            CGFloat value = [_vector valueAtIndex:i];
            vectorData[i] = (double)value;
        }
        [aCoder encodeBytes:(uint8_t *)vectorData length:vectorDataSize forKey:@"vector_data"];
        free(vectorData);
    }
}

@end
