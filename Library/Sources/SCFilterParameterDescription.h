//
//  SCFilterParameter.h
//  CoreImageShop
//
//  Created by Simon CORSIN on 16/05/14.
//
//

#import <Foundation/Foundation.h>

@interface SCFilterParameterDescription : NSObject<NSCoding>

@property (readonly, nonatomic) NSString *name;
@property (copy, nonatomic) NSString *type;
@property (strong, nonatomic) id<NSCoding> minValue;
@property (strong, nonatomic) id<NSCoding> maxValue;

@property (readonly, nonatomic) double minValueAsDouble;
@property (readonly, nonatomic) double maxValueAsDouble;

- (id)initWithName:(NSString *)name;

@end
