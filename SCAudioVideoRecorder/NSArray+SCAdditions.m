//
//  NSArray+SCAdditions.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/23/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "NSArray+SCAdditions.h"

@implementation NSArray(SCAdditions)

+ (NSMutableArray*) arrayWithArrays:(NSArray*)array, ... {
	va_list args;
	va_start(args, array);
	
	NSInteger totalSize = array.count;
	
	NSMutableArray * arrays = [[NSMutableArray alloc] init];
	[arrays addObject:array];
	
	NSArray * otherArray = nil;
	
	while ((otherArray = va_arg(args, NSArray*))) {
		totalSize += otherArray.count;
		[arrays addObject:otherArray];
	}
	va_end(args);
	
	NSMutableArray * resultArray = [[NSMutableArray alloc] initWithCapacity:totalSize];
	NSInteger i = 0;
	for (NSArray * stockedArray in arrays) {
		for (id element in stockedArray) {
			[resultArray setObject:element atIndexedSubscript:i];
			i++;
		}
	}

	return resultArray;
}

@end

