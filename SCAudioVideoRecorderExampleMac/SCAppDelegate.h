//
//  SCAppDelegate.h
//  SCAudioVideoRecorderExampleMac
//
//  Created by Simon CORSIN on 8/13/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <SCAudioVideoRecorderMac/SCCamera.h>
#import <Cocoa/Cocoa.h>
#import "SCButton.h"

@interface SCAppDelegate : NSObject <NSApplicationDelegate, SCCameraDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSView *cameraView;
@property (weak) IBOutlet NSView *mainView;
@property (weak) IBOutlet NSTextField *recordedText;
@property (weak) IBOutlet NSTextField *outputLabel;
@property (weak) IBOutlet NSTextField *videoLabel;
@property (weak) IBOutlet NSTextField *audioLabel;
@property (weak) IBOutlet SCButton *outputFileButton;
@property (weak) IBOutlet SCButton *outputVideoButton;
@property (weak) IBOutlet SCButton *outputAudioButton;
@property (weak) IBOutlet SCButton *recordButton;
@property (weak) IBOutlet SCButton *saveButton;

@end
