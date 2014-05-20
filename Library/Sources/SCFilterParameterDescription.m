//
//  SCFilterParameter.m
//  CoreImageShop
//
//  Created by Simon CORSIN on 16/05/14.
//
//

#import "SCFilterParameterDescription.h"

@implementation SCFilterParameterDescription

- (id)initWithCoder:(NSCoder *)aDecoder {
    NSString *name = [aDecoder decodeObjectForKey:@"Name"];
    NSString *type = [aDecoder decodeObjectForKey:@"Type"];
    id<NSCoding> minValue = [aDecoder decodeObjectForKey:@"MinValue"];
    id<NSCoding> maxValue = [aDecoder decodeObjectForKey:@"MaxValue"];
    
    self = [self initWithName:name];
    
    if (self) {
        self.minValue = minValue;
        self.maxValue = maxValue;
        self.type = type;
    }
    
    return self;
}

- (id)initWithName:(NSString *)name {
    self = [super init];
    
    if (self) {
        _name = name;
    }
    
    return self;
}

- (NSString *)description {
    NSMutableString *desc = [NSMutableString new];
    
    [desc appendFormat:@"Name: %@\n", self.name];
    [desc appendFormat:@"Type: %@\n", self.type];
    [desc appendFormat:@"Min Value: %@\n", self.minValue];
    [desc appendFormat:@"Max Value: %@", self.maxValue];
    
    return desc;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.name forKey:@"Name"];
    [aCoder encodeObject:self.type forKey:@"Type"];
    [aCoder encodeObject:self.minValue forKey:@"MinValue"];
    [aCoder encodeObject:self.maxValue forKey:@"MaxValue"];
}

- (double)minValueAsDouble {
    return ((NSNumber *)self.minValue).doubleValue;
}

- (double)maxValueAsDouble {
    return ((NSNumber *)self.maxValue).doubleValue;
}

@end
