//
//  SCFilter.m
//  CoreImageShop
//
//  Created by Simon CORSIN on 16/05/14.
//
//

#import "SCFilter.h"

@interface SCFilter() {
    NSMutableDictionary *_unwrappedValues;
    NSMutableArray *_subFilters;
}

@end

@implementation SCFilter

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    
    if (self) {
        _unwrappedValues = [NSMutableDictionary new];
        _CIFilter = [aDecoder decodeObjectForKey:@"CoreImageFilter"];
        self.enabled = [aDecoder decodeBoolForKey:@"Enabled"];
        
        if ([aDecoder containsValueForKey:@"VectorsData"]) {
            NSArray *vectors = [aDecoder decodeObjectForKey:@"VectorsData"];
            for (NSArray *vectorData in vectors) {
                CGFloat *vectorValue = malloc(sizeof(CGFloat) * (vectorData.count - 1));
                
                if (vectorData != nil) {
                    for (int i = 1; i < vectorData.count; i++) {
                        NSNumber *value = [vectorData objectAtIndex:i];
                        vectorValue[i - 1] = (CGFloat)value.doubleValue;
                    }
                    NSString *key = vectorData.firstObject;
                    
                    [_CIFilter setValue:[CIVector vectorWithValues:vectorValue count:vectorData.count - 1] forKey:key];
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
        
        if ([aDecoder containsValueForKey:@"SubFilters"]) {
            _subFilters = [[aDecoder decodeObjectForKey:@"SubFilters"] mutableCopy];
        } else {
            _subFilters = [NSMutableArray new];
        }
        
        if ([aDecoder containsValueForKey:@"Name"]) {
            _name = [aDecoder decodeObjectForKey:@"Name"];
        } else {
            _name = [_CIFilter.attributes objectForKey:kCIAttributeFilterName];
        }
    }
    
    return self;
}

- (id)initWithCIFilter:(CIFilter *)filter {
    self = [super init];
    
    if (self) {
        _CIFilter = filter;
        _unwrappedValues = [NSMutableDictionary new];
        _name = [filter.attributes objectForKey:kCIAttributeFilterName];
        _subFilters = [NSMutableArray new];

        self.enabled = YES;
    }
    
    return self;
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
                
                NSInteger dimension = [[_CIFilter valueForKey:@"inputCubeDimension"] integerValue];
                
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
    return [self _unwrappedValue:[_CIFilter valueForKey:key] forKey:key];
}

- (void)setParameterValue:(id)value forKey:(NSString *)key {
    value = [self _wrappedValue:value forKey:key];
    
    [_CIFilter setValue:value forKey:key];
    
    [self _didChangeParameter:key];
    
    id<SCFilterDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(filter:didChangeParameter:)]) {
        [delegate filter:self didChangeParameter:key];
    }
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    CIFilter *copiedFilter = _CIFilter.copy;
    
    for (NSString *key in _unwrappedValues) {
        [copiedFilter setValue:nil forKey:key];
    }
    
    if (copiedFilter != nil) {
        [aCoder encodeObject:copiedFilter forKey:@"CoreImageFilter"];
    }
    
    [aCoder encodeBool:self.enabled forKey:@"Enabled"];
    
    [aCoder encodeObject:_unwrappedValues forKey:@"UnwrappedValues"];
    
    NSMutableArray *vectors = [NSMutableArray new];
    
    for (NSString *key in _CIFilter.inputKeys) {
        id value = [_CIFilter valueForKey:key];
        
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
    
    [aCoder encodeObject:vectors forKey:@"VectorsData"];
    
    [aCoder encodeObject:_subFilters forKey:@"SubFilters"];
    [aCoder encodeObject:_name forKey:@"Name"];
}

- (void)resetToDefaults {
    [_CIFilter setDefaults];
    [_unwrappedValues removeAllObjects];
    
    for (SCFilter *subFilter in _subFilters) {
        [subFilter resetToDefaults];
    }
    
    id<SCFilterDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(filterDidResetToDefaults:)]) {
        [delegate filterDidResetToDefaults:self];
    }
}

- (void)addSubFilter:(SCFilter *)subFilter {
    [_subFilters addObject:subFilter];
}

- (void)removeSubFilter:(SCFilter *)subFilter {
    [_subFilters removeObject:subFilter];
}

- (void)insertSubFilter:(SCFilter *)subFilter atIndex:(NSInteger)index {
    [_subFilters insertObject:subFilter atIndex:index];
}

- (void)removeSubFilterAtIndex:(NSInteger)index {
    [_subFilters removeObjectAtIndex:index];
}

- (NSArray *)subFilters {
    return _subFilters;
}

- (CIImage *)imageByProcessingImage:(CIImage *)image {
    if (!self.enabled) {
        return image;
    }
    
    for (SCFilter *filter in _subFilters) {
        image = [filter imageByProcessingImage:image];
    }
    
    CIFilter *ciFilter = _CIFilter;
    
    if (ciFilter == nil) {
        return image;
    }
    
    [ciFilter setValue:image forKey:kCIInputImageKey];
    return [ciFilter valueForKey:kCIOutputImageKey];
}

- (void)writeToFile:(NSURL *)fileUrl error:(NSError *__autoreleasing *)error {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    [data writeToURL:fileUrl options:NSDataWritingAtomic error:error];
}

- (BOOL)isEmpty {
    BOOL isEmpty = YES;
    
    if (_CIFilter != nil) {
        return NO;
    }
    
    for (SCFilter *filter in _subFilters) {
        isEmpty &= filter.isEmpty;
    }
    
    return isEmpty;
}

+ (SCFilter *)emptyFilter {
    return [SCFilter filterWithCIFilter:nil];
}

+ (SCFilter *)filterWithAffineTransform:(CGAffineTransform)affineTransform {
    CIFilter *filter = [CIFilter filterWithName:@"CIAffineTransform"];
    [filter setValue:[NSValue valueWithBytes:&affineTransform objCType:@encode(CGAffineTransform)] forKey:@"inputTransform"];
    
    return [SCFilter filterWithCIFilter:filter];
}

+ (SCFilter *)filterWithCIFilter:(CIFilter *)filterDescription {
    return [[SCFilter alloc] initWithCIFilter:filterDescription];
}

+ (SCFilter *)filterWithCIFilterName:(NSString *)name {
    CIFilter *coreImageFilter = [CIFilter filterWithName:name];
    [coreImageFilter setDefaults];
    
    return coreImageFilter != nil ? [SCFilter filterWithCIFilter:coreImageFilter] : nil;
}

+ (SCFilter *)filterWithData:(NSData *)data error:(NSError *__autoreleasing *)error {
    id obj = nil;
    @try {
        obj = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    } @catch (NSException *exception) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"SCFilterGroup" code:200 userInfo:@{
                                                                                   NSLocalizedDescriptionKey : exception.reason
                                                                                   }];
            return nil;
        }
    }
    
    if (![obj isKindOfClass:[SCFilter class]]) {
        obj = nil;
        if (error != nil) {
            *error = [NSError errorWithDomain:@"FilterDomain" code:200 userInfo:@{
                                                                      NSLocalizedDescriptionKey : @"Invalid serialized class type"
                                                                      }];
        }
    }
    
    return obj;
}

+ (SCFilter *)filterWithData:(NSData *)data {
    return [SCFilter filterWithData:data error:nil];
}

+ (SCFilter *)filterWithContentsOfURL:(NSURL *)url {
    NSData *data = [NSData dataWithContentsOfURL:url];
    
    if (data != nil) {
        return [SCFilter filterWithData:data];
    }
    
    return nil;
}

+ (SCFilter *)filterWithFilters:(NSArray *)filters {
    SCFilter *filter = [SCFilter emptyFilter];
    
    for (SCFilter *subFilter in filters) {
        [filter addSubFilter:subFilter];
    }
    
    return filter;
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
    
    CGContextRef context = CGBitmapContextCreate(bitmap,
                                     width,
                                     height,
                                     8,
                                     bytesPerRow,
                                     colorSpace,
                                     (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
   
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
