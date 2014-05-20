//
//  SCFilterList.m
//  CoreImageShop
//
//  Created by Simon CORSIN on 16/05/14.
//
//

#import "SCFilterDescriptionList.h"

@interface SCFilterDescriptionList() {
    NSMutableArray *_filterDescriptions;
    NSMutableDictionary *_filterDescriptionsByCategories;
}

@end

@implementation SCFilterDescriptionList

- (id)init {
    self = [super init];
    
    if (self) {
        _filterDescriptions = [NSMutableArray new];
        _filterDescriptionsByCategories = [NSMutableDictionary new];
    }
    
    return self;
}

- (void)addFilterDescription:(SCFilterDescription *)filterDescription {
    NSAssert(filterDescription != nil, @"filterDescription may not be nil");
    
    filterDescription.filterId = _filterDescriptions.count;
    [_filterDescriptions addObject:filterDescription];
    
    NSString *category = filterDescription.category;
    if (category != nil) {
        NSMutableArray *categoryArray = [_filterDescriptionsByCategories objectForKey:category];
        
        if (categoryArray == nil) {
            categoryArray = [NSMutableArray new];
            [_filterDescriptionsByCategories setObject:categoryArray forKey:category];
        }
        
        [categoryArray addObject:filterDescription];
    }
}

- (void)removeFilterDescription:(SCFilterDescription *)filterDescription {
    NSAssert(filterDescription != nil, @"filterDescription may not be nil");

    [_filterDescriptions removeObject:filterDescription];
    NSString *category = filterDescription.category;

    if (category != nil) {
        NSMutableArray *categoryArray = [_filterDescriptionsByCategories objectForKey:category];
        [categoryArray removeObject:filterDescription];
    }
    
}

- (SCFilterDescription *)filterDescriptionForId:(NSInteger)filterId {
    return [_filterDescriptions objectAtIndex:filterId];
}

- (NSString *)description {
    NSMutableString *desc = [NSMutableString new];
    
    for (NSString *category in _filterDescriptionsByCategories.allKeys) {
        [desc appendFormat:@"Category: %@\n", category];
        for (SCFilterDescription *filter in [self filterDescriptionsForCategory:category]) {
            NSString *filterDescription = filter.description;
            
            [desc appendFormat:@"\t%@\n", [filterDescription stringByReplacingOccurrencesOfString:@"\t" withString:@"\t\t"]];
        }
    }
    
    return desc;
}

- (NSArray *)filterDescriptionsForCategory:(NSString *)category {
    return [_filterDescriptionsByCategories objectForKey:category];
}

- (NSArray *)allCategories {
    return _filterDescriptionsByCategories.allKeys;
}

- (NSArray *)filterDescriptions {
    return _filterDescriptions;
}

@end
