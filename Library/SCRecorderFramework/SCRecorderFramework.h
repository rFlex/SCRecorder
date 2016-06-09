//
//  SCRecorderFramework.h
//  SCRecorderFramework
//
//  Created by Simon CORSIN on 28/03/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for SCRecorderFramework.
FOUNDATION_EXPORT double SCRecorderFrameworkVersionNumber;

//! Project version string for SCRecorderFramework.
FOUNDATION_EXPORT const unsigned char SCRecorderFrameworkVersionString[];

// Recorder.

#import <SCRecorder/SCRecorder.h>
#import <SCRecorder/SCRecordSession.h>
#import <SCRecorder/SCVideoConfiguration.h>
#import <SCRecorder/SCAudioConfiguration.h>
#import <SCRecorder/SCMediaTypeConfiguration.h>
#import <SCRecorder/SCPhotoConfiguration.h>
#import <SCRecorder/SCRecordSession.h>
#import <SCRecorder/SCRecordSessionSegment.h>
#import <SCRecorder/SCRecordDelegate.h>

// ToolsView.

#import <SCRecorder/SCRecorderFocusTargetView.h>
#import <SCRecorder/SCRecorderToolsView.h>


// FilterDisplayers.

#import <SCRecorder/SCSwipeableFilterView.h>
#import <SCRecorder/SCImageView.h>

// Players.

#import <SCRecorder/SCPlayer.h>
#import <SCRecorder/SCVideoPlayerView.h>

// Tools.

#import <SCRecorder/SCSampleBufferHolder.h>
#import <SCRecorder/SCAssetExportSession.h>
#import <SCRecorder/SCAudioTools.h>
#import <SCRecorder/SCRecorderTools.h>
#import <SCRecorder/SCProcessingQueue.h>
#import <SCRecorder/SCIOPixelBuffers.h>

// Filters.
#import <SCRecorder/SCFilter.h>
