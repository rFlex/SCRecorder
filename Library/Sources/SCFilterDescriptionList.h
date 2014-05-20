//
//  SCFilterList.h
//  CoreImageShop
//
//  Created by Simon CORSIN on 16/05/14.
//
//

#import <Foundation/Foundation.h>
#import "SCFilterDescription.h"

@interface SCFilterDescriptionList : NSObject

@property (readonly, nonatomic) NSArray *filterDescriptions;

- (void)addFilterDescription:(SCFilterDescription *)filterDescription;
- (void)removeFilterDescription:(SCFilterDescription *)filterDescription;
- (NSArray *)filterDescriptionsForCategory:(NSString *)category;
- (NSArray *)allCategories;
- (SCFilterDescription *)filterDescriptionForId:(NSInteger)filterId;

@end
