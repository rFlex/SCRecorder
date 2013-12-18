//
//  SCAudioRecordViewController.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 18/12/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCAudioRecordViewController.h"
#import "SCCamera.h"
#import "SCPlayer.h"

@interface SCAudioRecordViewController ()

@property (strong, nonatomic) SCPlayer * player;
@property (strong, nonatomic) SCCamera * camera;
@property (copy, nonatomic) NSURL * fileUrl;

@end

@implementation SCAudioRecordViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.player = [SCPlayer player];
    self.player.delegate = self;
    
    self.camera = [SCCamera camera];
    self.camera.delegate = self;
    self.camera.outputFileType = AVFileTypeAppleM4A;
    self.camera.enableVideo = NO;
    
    [self.camera initialize:^(NSError *audioError, NSError *videoError) {
        if (audioError != nil) {
            [self showError:audioError];
        } else {
            [self.camera startRunningSession];
        }
    }];
    [self hidePlayControl:NO];
}

- (void)showError:(NSError*)error {
      [[[UIAlertView alloc] initWithTitle:@"Something went wrong" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)recordPressed:(id)sender {
    if (![self.camera isPrepared]) {
        NSError * error = nil;
        [self.camera prepareRecordingOnTempDir:&error];
        
        if (error == nil) {
            [self.camera record];
        } else {
            [self showError:error];
        }
    } else {
        if ([self.camera isRecording]) {
            [self.camera pause];
        } else {
            [self.camera record];
        }
    }
    
    self.recordButton.selected = [self.camera isRecording];
}

- (void)hidePlayControl:(BOOL)animated {
    [UIView animateWithDuration:animated ? 0.3 : 0 animations:^{
        CGRect frame = self.playView.frame;
        frame.origin.y = self.view.frame.size.height;
        self.playView.frame = frame;
    }];
}

- (void)showPlayControl:(BOOL)animated {
    [UIView animateWithDuration:animated ? 0.3 : 0 animations:^{
        CGRect frame = self.playView.frame;
        frame.origin.y = self.view.frame.size.height - frame.size.height;
        self.playView.frame = frame;
    }];
}

- (void)audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didRecordAudioSample:(CMTime)sampleTime {
    self.recordTimeLabel.text = [NSString stringWithFormat:@"%.2fs", CMTimeGetSeconds(sampleTime)];
}

- (void)audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFinishRecordingAtUrl:(NSURL *)recordedFile error:(NSError *)error {
    if (error == nil) {
        self.fileUrl = recordedFile;
        [self showPlayControl:YES];
        [self.player setItemByUrl:self.fileUrl];
    } else {
        [self showError:error];
    }
}


- (IBAction)stopRecordPressed:(id)sender {
    [self.camera stop];
}

- (IBAction)playButtonPressed:(id)sender {
    if (self.player.isPlaying) {
        [self.player pause];
    } else {
        [self.player play];
    }
    self.playButton.selected = self.player.isPlaying;
}

- (void)videoPlayer:(SCPlayer *)videoPlayer didChangeItem:(AVPlayerItem *)item {

}

- (void)videoPlayer:(SCPlayer *)videoPlayer didEndLoadingAtItemTime:(CMTime)itemTime {
    float seconds = CMTimeGetSeconds(self.player.currentItem.duration);
    self.playSlider.maximumValue = seconds;
}

- (void)videoPlayer:(SCPlayer *)videoPlayer didPlay:(CMTime)secondsElapsed timeTotal:(CMTime)timeTotal {
    self.playSlider.value = CMTimeGetSeconds(secondsElapsed);
}

- (IBAction)playSliderValueChanged:(id)sender {
    [self.player seekToTime:CMTimeMakeWithSeconds(self.playSlider.value, 1000)];
}

- (IBAction)deletePressed:(id)sender {
    self.fileUrl = nil;
    [self hidePlayControl:YES];
}
@end
