//
//  SCAudioTools.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/8/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import "SCAudioTools.h"

@implementation SCAudioTools {
    
}

+ (void) overrideCategoryMixWithOthers {
    UInt32 doSetProperty = 1;
    
    AudioSessionSetProperty (kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof(doSetProperty), &doSetProperty);
}

@end
