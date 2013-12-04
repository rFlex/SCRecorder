//
//  SCImageBlurHeader.h
//  SCAudioVideoRecorder
//
//  Created by 曾 宪华 on 13-12-4.
//  Copyright (c) 2013年 rFlex. All rights reserved.
//

#ifndef SCAudioVideoRecorder_SCImageBlurHeader_h
#define SCAudioVideoRecorder_SCImageBlurHeader_h

static const CGFloat kSCImageToolAnimationDuration = 0.3;
static const CGFloat kSCImageToolFadeoutDuration   = 0.2;


typedef NS_ENUM(NSUInteger, SCBlurType)
{
    kSCBlurTypeNormal = 0,
    kSCBlurTypeCircle,
    kSCBlurTypeBand,
};

#endif
