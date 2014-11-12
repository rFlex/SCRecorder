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
    NSMutableDictionary *_unwrappedValues;
}

@end

@implementation SCFilter

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    
    if (self) {
        _unwrappedValues = [NSMutableDictionary new];
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
        
        if ([aDecoder containsValueForKey:@"UnwrappedValues"]) {
            NSDictionary *unwrappedValues = [aDecoder decodeObjectForKey:@"UnwrappedValues"];
            
            for (NSString *key in unwrappedValues) {
                [self setParameterValue:[unwrappedValues objectForKey:key] forKey:key];
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
        _unwrappedValues = [NSMutableDictionary new];
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

- (id)_unwrappedValue:(id)value forKey:(NSString *)key {
    id unwrappedValue = [_unwrappedValues objectForKey:key];
    
    return unwrappedValue == nil ? value : unwrappedValue;
}

- (id)_wrappedValue:(id)value forKey:(NSString *)key {
    if (value == nil) {
        [_unwrappedValues removeObjectForKey:key];
    } else {
        if ([key isEqualToString:@"inputCubeData"]) {
            if ([value isKindOfClass:[NSData class]]) {
                NSData *data = value;
                
                CGDataProviderRef source = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
                if (source == nil) {
                    NSLog(@"Unable to get source provider for key %@", key);
                    return nil;
                }
                
                CGImageRef image = nil;
                
                if ([SCFilter data:data hasMagic:MagicPNG]) {
                    image = CGImageCreateWithPNGDataProvider(source, nil, NO, kCGRenderingIntentDefault);
                } else if ([SCFilter data:data hasMagic:MagicJPG]) {
                    image = CGImageCreateWithJPEGDataProvider(source, nil, NO, kCGRenderingIntentDefault);
                } else {
                    NSLog(@"Input data for key %@ must be either representing a PNG or a JPG file", key);
                    CGDataProviderRelease(source);
                    return nil;
                }
                
                if (image == nil) {
                    NSLog(@"Unable to create image for key %@ from input data", key);
                    CGDataProviderRelease(source);
                    return nil;
                }
                
                CGDataProviderRelease(source);
                
                NSInteger dimension = [[_coreImageFilter valueForKey:@"inputCubeDimension"] integerValue];
                
                [_unwrappedValues setObject:data forKey:key];
                
                value = [SCFilter colorCubeDataWithCGImage:image dimension:dimension];
                CGImageRelease(image);
            } else {
                NSLog(@"Value for key %@ must be of type NSData (got type: %@)", key, [value class]);
                return nil;
            }
        }
    }
    
    return value;
}

- (void)_didChangeParameter:(NSString *)key {
    if ([key isEqualToString:@"inputCubeDimension"]) {
        NSData *inputCubeData = [_unwrappedValues objectForKey:@"inputCubeData"];
        if (inputCubeData != nil) {
            [self setParameterValue:inputCubeData forKey:@"inputCubeData"];
        }
    }
}

- (id)parameterValueForKey:(NSString *)key {
    return [self _unwrappedValue:[_coreImageFilter valueForKey:key] forKey:key];
}

- (void)setParameterValue:(id)value forKey:(NSString *)key {
    value = [self _wrappedValue:value forKey:key];
    
    [_coreImageFilter setValue:value forKey:key];
    
    [self _didChangeParameter:key];
    
    id<SCFilterDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(filter:didChangeParameter:)]) {
        [delegate filter:self didChangeParameter:key];
    }
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    CIFilter *copiedFilter = self.coreImageFilter.copy;
    
    for (NSString *key in _unwrappedValues) {
        [copiedFilter setValue:nil forKey:key];
    }
    
    [aCoder encodeObject:copiedFilter forKey:@"CoreImageFilter"];
    [aCoder encodeBool:self.enabled forKey:@"Enabled"];
    
    [aCoder encodeObject:_unwrappedValues forKey:@"UnwrappedValues"];
    
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
            }
            [vectors addObject:vectorData];
        }
    }
    
    [aCoder encodeObject:vectors forKey:@"vectors_data"];
    
}

- (void)resetToDefaults {
    [_coreImageFilter setDefaults];
    [_unwrappedValues removeAllObjects];
    
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


static UInt32 MagicPNG = 0x474e5089;
static UInt32 MagicJPG = 0xe0ffd8ff;

+ (BOOL)data:(NSData *)data hasMagic:(UInt32)magic {
    if (data.length > sizeof(magic)) {
        const UInt32 *bytes = data.bytes;
        UInt32 actualMagic = *bytes;
        
        return actualMagic == magic;
    }
    
    return NO;
}

/////
// These two functions were taken from https://github.com/NghiaTranUIT/FeSlideFilter
//
+ (NSData *)colorCubeDataWithCGImage:(CGImageRef )image dimension:(NSInteger)n {
    if (n == 0) {
        return nil;
    }
    
    NSInteger width = CGImageGetWidth(image);
    NSInteger height = CGImageGetHeight(image);
    NSInteger rowNum = height / n;
    NSInteger columnNum = width / n;
    
    if ((width % n != 0) || (height % n != 0) || (rowNum * columnNum != n)) {
        return nil;
    }
    
    UInt8 *bitmap = [self createRGBABitmapFromImage:image];
    
    if (bitmap == nil) {
        return nil;
    }
    
    const int colorChannels = 4;
    
    NSInteger size = n * n * n * sizeof(float) * colorChannels;
    float *data = malloc(size);
    
    if (data == nil) {
        free(bitmap);
        return nil;
    }
    
    UInt8 *bitmapPtr = bitmap;

    int z = 0;
    for (int row = 0; row <  rowNum; row++) {
        for (int y = 0; y < n; y++) {
            int tmp = z;
            for (int col = 0; col < columnNum; col++) {
                for (int x = 0; x < n; x++) {
                    UInt8 r = *bitmapPtr++;
                    UInt8 g = *bitmapPtr++;
                    UInt8 b = *bitmapPtr++;
                    UInt8 a = *bitmapPtr++;
                    
                    NSInteger dataOffset = (z * n * n + y * n + x) * 4;
                    
                    data[dataOffset] = r / 255.0;
                    data[dataOffset + 1] = g / 255.0;
                    data[dataOffset + 2] = b / 255.0;
                    data[dataOffset + 3] = a / 255.0;
                }
                z++;
            }
            z = tmp;
        }
        z += columnNum;
    }
    
    free(bitmap);
    
    return [NSData dataWithBytesNoCopy:data length:size freeWhenDone:YES];
}

+ (unsigned char *)createRGBABitmapFromImage:(CGImageRef)image {
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    
    NSInteger bytesPerRow = (width * 4);
    NSInteger bitmapSize = (bytesPerRow * height);
    
    unsigned char *bitmap = malloc(bitmapSize);
    if (bitmap == nil) {
        return nil;
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == nil) {
        free(bitmap);
        return nil;
    }
    
    CGContextRef context = CGBitmapContextCreate (bitmap,
                                     width,
                                     height,
                                     8,
                                     bytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaPremultipliedLast);
    
    CGColorSpaceRelease(colorSpace);
    
    if (context == nil) {
        free(bitmap);
        return nil;
    }
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    
    CGContextRelease(context);
    
    return bitmap;
}

@end
