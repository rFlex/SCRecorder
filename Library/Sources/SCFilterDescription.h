//
//  SCFilterDescription.h
//  CoreImageShop
//
//  Created by Simon CORSIN on 16/05/14.
//
//

#import <Foundation/Foundation.h>
#import "SCFilterParameterDescription.h"

@interface SCFilterDescription : NSObject<NSCoding>

@property (assign, nonatomic) NSInteger filterId;
@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSArray *parameters;
@property (readonly, nonatomic) NSString *category;

- (id)initWithName:(NSString *)name andCategory:(NSString *)category;
- (void)addParameter:(SCFilterParameterDescription *)parameter;

@end
