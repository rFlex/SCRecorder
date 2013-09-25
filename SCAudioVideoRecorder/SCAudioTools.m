//
//  SCAudioTools.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/8/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "SCAudioTools.h"

@implementation SCAudioTools {
    
}

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
+ (void) overrideCategoryMixWithOthers {
	
    UInt32 doSetProperty = 1;
    
    AudioSessionSetProperty (kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof(doSetProperty), &doSetProperty);
}
#endif

@end
