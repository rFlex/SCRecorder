//
//  SCAppDelegate.m
//  SCAudioVideoRecorderExampleMac
//
//  Created by Simon CORSIN on 8/13/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <SCAudioVideoRecorderMac/SCCamera.h>
#import "NSButton+SCAdditions.h"
#import "SCAppDelegate.h"

@interface SCAppDelegate() {
    
}

@property (strong, nonatomic) SCCamera * camera;

@end

@implementation SCAppDelegate

@synthesize camera;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    self.camera = [[SCCamera alloc] init];
    self.camera.previewView = self.cameraView;
    self.camera.enableSound = NO;
    self.camera.previewVideoGravity = SCVideoGravityResizeAspectFill;
    
    self.camera.delegate = self;
    self.camera.videoEncoder.outputBitsPerPixel = 1;
    [self.camera initialize:^(NSError *audioError, NSError *videoError) {
        NSLog(@"AudioError: %@", audioError);
        NSLog(@"VideoError: %@", videoError);
    }];

	NSURL * url = [NSURL URLWithString:@"file:///Users/simoncorsin/Music/iTunes/iTunes%20Media/Music/Various%20Artists/MOS%20The%20Sound%20Of%20Dubstep%203/16%20King%20Kong.mp3"];
	AVURLAsset * asset = [AVURLAsset assetWithURL:url];
	self.camera.playbackAsset = asset;
	
    [self.outputFileButton addAction:@selector(outputFileButtonPressed:) forTarget:self];
    [self.outputVideoButton addAction:@selector(outputVideoButtonPressed:) forTarget:self];
    [self.outputAudioButton addAction:@selector(outputAudioButtonPressed:) forTarget:self];
    [self.recordButton addAction:@selector(recordButtonPressed:) forTarget:self];
    [self.recordButton setEnabled:NO];
    [self.saveButton addAction:@selector(saveButtonPressed:) forTarget:self];
}

- (void) outputFileButtonPressed:(id)sender {
    NSLog(@"Output file");
    
    NSSavePanel * panel = [NSSavePanel savePanel];
    panel.title = @"Choose the output file";
    panel.nameFieldStringValue = @"Outputfile";
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [self setOutputFile:panel.URL];
        }
    }];
    
}

- (void) setOutputFile:(NSURL*)fileUrl {
    BOOL hasFailed = YES;
    
    if (fileUrl != nil) {
        NSError * error = nil;
        [self.camera prepareRecordingAtUrl:fileUrl error:&error];
        hasFailed = error != nil;
    }
    NSString * file = nil;
    
    if (!hasFailed) {
        [self.recordButton setEnabled:YES];
        [self.saveButton setEnabled:YES];
        self.recordButton.stringValue = @"Record";
        
        file = fileUrl.absoluteString;
    } else {
        [self.recordButton setEnabled:NO];
        [self.recordButton setEnabled:NO];
    }
    self.outputLabel.stringValue = [NSString stringWithFormat:@"Output: %@", file];
    [self.outputLabel sizeToFit];
}

- (void) recordButtonPressed:(id)sender {
    if ([self.camera isRecording]) {
        [self.camera pause];
        self.recordButton.stringValue = @"Record";
    } else {
        [self.camera record];
        self.recordButton.stringValue = @"Pause";
    }
}

- (void) outputVideoButtonPressed:(id)sender {
    NSLog(@"Change output video");
}

- (void) outputAudioButtonPressed:(id)sender {
    NSLog(@"Output audio");
}

- (void) saveButtonPressed:(id) sender {
    [self.camera stop];
    [self setOutputFile:nil];
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFinishRecordingAtUrl:(NSURL *)recordedFile error:(NSError *)error {
    
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didRecordVideoFrame:(Float64)frameSecond {
    self.recordedText.stringValue = [NSString stringWithFormat:@"Recorded: %.2fsec", frameSecond];
}

@end
