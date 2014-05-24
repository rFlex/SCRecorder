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
@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSString *displayName;
@property (readonly, nonatomic) CIFilter *coreImageFilter;

@property (assign, nonatomic) BOOL enabled;

+ (SCFilter *)filterWithCIFilter:(CIFilter *)filterDescription;

+ (SCFilter *)filterWithName:(NSString *)name;

- (id)initWithCIFilter:(CIFilter *)filter;

- (id)initWithName:(NSString *)name;

- (id)parameterValueForKey:(NSString *)key;

- (void)setParameterValue:(id)value forKey:(NSString *)key;

- (void)resetToDefaults;

@end
