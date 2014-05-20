//
//  SCFilterDescription.m
//  CoreImageShop
//
//  Created by Simon CORSIN on 16/05/14.
//
//

#import "SCFilterDescription.h"

@interface SCFilterDescription() {
    NSMutableArray *_parameters;
}

@end

@implementation SCFilterDescription

- (id)initWithCoder:(NSCoder *)aDecoder {
    NSString *name = [aDecoder decodeObjectForKey:@"Name"];
    NSString *category = [aDecoder decodeObjectForKey:@"Category"];
    NSArray *parameters = [aDecoder decodeObjectForKey:@"Parameters"];

    self = [self initWithName:name andCategory:category];
    
    if (self) {
        _parameters = [parameters mutableCopy];
    }
    
    return self;
}

- (id)initWithName:(NSString *)name andCategory:(NSString *)category {
    self = [super init];
    
    if (self) {
        _parameters = [NSMutableArray new];
        _name = name;
        _category = category;
    }
    
    return self;
}

- (void)addParameter:(SCFilterParameterDescription *)parameter {
    NSAssert(parameter != nil, @"parameter may not be nil");
    
    [_parameters addObject:parameter];
}

- (NSString *)description {
    NSMutableString *desc = [NSMutableString new];
    
    [desc appendFormat:@"Filter: %@\n", self.name];
    for (SCFilterParameterDescription *parameter in _parameters) {
        NSString *parameterDesc = parameter.description;
        [desc appendFormat:@"\t%@\n\n", [parameterDesc stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
    }
    
    return desc;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.name forKey:@"Name"];
    [aCoder encodeObject:self.category forKey:@"Category"];
    [aCoder encodeObject:self.parameters forKey:@"Parameters"];
}

- (NSArray *)parameters {
    return _parameters;
}

@end
