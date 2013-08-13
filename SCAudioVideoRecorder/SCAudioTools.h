//
//  SCAudioTools.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/8/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCAudioTools : NSObject {
    
}

//
// IOS SPECIFIC
//

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
+ (void) overrideCategoryMixWithOthers;
#endif

@end
