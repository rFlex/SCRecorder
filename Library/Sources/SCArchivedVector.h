//
//  SCArchivedVector.h
//  SCRecorder
//
//  Created by Simon CORSIN on 21/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <CoreImage/CoreImage.h>
#else
#import <QuartzCore/QuartzCore.h>
#endif

// CIVector objects archive and unarchive is buggy between iOS and OS X
// This class gives a workaround for that
@interface SCArchivedVector : NSObject<NSCoding>

@property (readonly, nonatomic) CIVector *vector;
@property (readonly, nonatomic) NSString *name;

- (id)initWithVector:(CIVector *)vector name:(NSString *)name;

@end
