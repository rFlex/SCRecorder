//
//  SCCamera.h
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/6/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCAudioVideoRecorder.h"

@class SCCamera;
@protocol SCCameraDelegate <SCAudioVideoRecorderDelegate>

@end

@interface SCCamera : SCAudioVideoRecorder {
    
}

- (id) initWithSessionPreset:(NSString*)sessionPreset;

- (void) initialize:(void(^)(NSError * audioError, NSError * videoError))completionHandler;

- (BOOL) isReady;

@property (strong, nonatomic, readonly) AVCaptureSession * session;
@property (weak, nonatomic) id<SCCameraDelegate> delegate;
@property (copy, nonatomic) NSString * sessionPreset;
@property (copy, nonatomic) NSString * previewVideoGravity;
@property (assign, nonatomic) BOOL enableSound;
@property (assign, nonatomic) BOOL enableVideo;
@property (weak, nonatomic) UIView * previewView;

@end
