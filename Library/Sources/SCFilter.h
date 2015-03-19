//
//  SCFilter.h
//  CoreImageShop
//
//  Created by Simon CORSIN on 16/05/14.
//
//

#import <Foundation/Foundation.h>

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <CoreImage/CoreImage.h>
#else
#import <QuartzCore/QuartzCore.h>
#endif

@class SCFilter;
@protocol SCFilterDelegate <NSObject>

- (void)filter:(SCFilter *)filter didChangeParameter:(NSString *)parameterKey;
- (void)filterDidResetToDefaults:(SCFilter *)filter;

@end

@interface SCFilter : NSObject<NSCoding>

@property (weak, nonatomic) id<SCFilterDelegate> delegate;

@property (readonly, nonatomic) CIFilter *CIFilter;

@property (strong, nonatomic) NSString *name;

@property (assign, nonatomic) BOOL enabled;

@property (readonly, nonatomic) BOOL isEmpty;

@property (readonly, nonatomic) NSArray *subFilters;

- (id)initWithCIFilter:(CIFilter *)filter;

- (id)parameterValueForKey:(NSString *)key;

- (void)setParameterValue:(id)value forKey:(NSString *)key;

- (void)resetToDefaults;

- (void)addSubFilter:(SCFilter *)subFilter;

- (void)removeSubFilter:(SCFilter *)subFilter;

/**
 Write this filter to a specific file.
 This filter can then be restored from this file
 */
- (void)writeToFile:(NSURL *)fileUrl error:(NSError **)error;

- (CIImage *)imageByProcessingImage:(CIImage *)image;

+ (SCFilter *)emptyFilter;

+ (SCFilter *)filterWithCIFilter:(CIFilter *)filterDescription;

+ (SCFilter *)filterWithCIFilterName:(NSString *)name;

+ (SCFilter *)filterWithAffineTransform:(CGAffineTransform)affineTransform;

/**
 Create a filterGroup with a serialized filterGroup data
 */
+ (SCFilter *)filterWithData:(NSData *)data;

/**
 Create a filterGroup with a serialized filterGroup data
 */
+ (SCFilter *)filterWithData:(NSData *)data error:(NSError **)error;

/**
 Create a filterGroup with an URL containing a serialized filterGroup data.
 */
+ (SCFilter *)filterWithContentsOfURL:(NSURL *)url;

@end
