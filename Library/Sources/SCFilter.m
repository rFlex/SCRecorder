//
//  SCFilter.m
//  CoreImageShop
//
//  Created by Simon CORSIN on 16/05/14.
//
//

#import "SCFilter.h"
#import "SCArchivedVector.h"

@interface SCFilter() {
}

@end

@implementation SCFilter

double *EnsureSize(double *data, int* currentSize, int size) {
    if (size > *currentSize) {
        free(data);
        int newSize = size * 2;
        data = malloc(sizeof(double) * newSize);
        *currentSize = newSize;
    }
    
    return data;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    
    if (self) {
        _coreImageFilter = [aDecoder decodeObjectForKey:@"CoreImageFilter"];
        self.enabled = [aDecoder decodeBoolForKey:@"Enabled"];
        
        if ([aDecoder containsValueForKey:@"vectors"]) {
            NSArray *vectors = [aDecoder decodeObjectForKey:@"vectors"];
            for (SCArchivedVector *archivedVector in vectors) {
                [_coreImageFilter setValue:archivedVector.vector forKey:archivedVector.name];
            }
        }
        
        if ([aDecoder containsValueForKey:@"vectors_data"]) {
            NSArray *vectors = [aDecoder decodeObjectForKey:@"vectors_data"];
            for (NSArray *vectorData in vectors) {
                CGFloat *vectorValue = malloc(sizeof(CGFloat) * (vectorData.count - 1));
                
                if (vectorData != nil) {
                    for (int i = 1; i < vectorData.count; i++) {
                        NSNumber *value = [vectorData objectAtIndex:i];
                        vectorValue[i - 1] = (CGFloat)value.doubleValue;
                    }
                    NSString *key = vectorData.firstObject;
                    
                    [_coreImageFilter setValue:[CIVector vectorWithValues:vectorValue count:vectorData.count - 1] forKey:key];
                    free(vectorValue);
                }
            }
        }
    }
    
    return self;
}

- (id)initWithName:(NSString *)name {
    CIFilter *filter = [CIFilter filterWithName:name];
    [filter setDefaults];
    return [self initWithCIFilter:filter];
}

- (id)initWithCIFilter:(CIFilter *)filter {
    self = [super init];
    
    if (self) {
        _coreImageFilter = filter;
        self.enabled = YES;
    }
    
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    SCFilter *filter = [SCFilter filterWithCIFilter:[self.coreImageFilter copy]];
    filter.enabled = self.enabled;
    filter.delegate = self.delegate;
    
    return filter;
}

+ (SCFilter *)filterWithCIFilter:(CIFilter *)filterDescription {
    return [[SCFilter alloc] initWithCIFilter:filterDescription];
}

+ (SCFilter *)filterWithName:(NSString *)name {
    CIFilter *coreImageFilter = [CIFilter filterWithName:name];
    [coreImageFilter setDefaults];

    return coreImageFilter != nil ? [SCFilter filterWithCIFilter:coreImageFilter] : nil;
}

- (id)parameterValueForKey:(NSString *)key {
    return [_coreImageFilter valueForKey:key];
}

- (void)setParameterValue:(id)value forKey:(NSString *)key {
    [_coreImageFilter setValue:value forKey:key];
    
    id<SCFilterDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(filter:didChangeParameter:)]) {
        [delegate filter:self didChangeParameter:key];
    }
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.coreImageFilter forKey:@"CoreImageFilter"];
    [aCoder encodeBool:self.enabled forKey:@"Enabled"];
    
    NSMutableArray *vectors = [NSMutableArray new];
    
    for (NSString *key in _coreImageFilter.inputKeys) {
        id value = [_coreImageFilter valueForKey:key];
        
        if ([value isKindOfClass:[CIVector class]]) {
            CIVector *vector = value;
            NSMutableArray *vectorData = [NSMutableArray new];
            [vectorData addObject:key];

            for (int i = 0; i < vector.count; i++) {
                CGFloat value = [vector valueAtIndex:i];
                [vectorData addObject:[NSNumber numberWithDouble:(double)value]];
//                [aCoder encodeDouble:value forKey:[NSString stringWithFormat:@"vector_%d_%d", vectorIndex, i]];
            }
            [vectors addObject:vectorData];
        }
    }
    
    [aCoder encodeObject:vectors forKey:@"vectors_data"];
    
}

- (void)resetToDefaults {
    [_coreImageFilter setDefaults];
    
    id<SCFilterDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(filterDidResetToDefaults:)]) {
        [delegate filterDidResetToDefaults:self];
    }
}

- (NSString *)name {
    return [self.coreImageFilter.attributes objectForKey:kCIAttributeFilterName];
}

- (NSString *)displayName {
    return [self.coreImageFilter.attributes objectForKey:kCIAttributeFilterDisplayName];
}


@end
