//
//  SCAudioRecordViewController.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 18/12/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCAudioRecordViewController.h"
#import "SCPlayer.h"

@interface SCAudioRecordViewController () {
    SCRecorder *_recorder;
}

@property (strong, nonatomic) SCPlayer * player;
@property (copy, nonatomic) NSURL * fileUrl;

@end

@implementation SCAudioRecordViewController

- (void)dealloc {
    [self.player endSendingPlayMessages];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.player = [SCPlayer player];
    self.player.delegate = self;
    [self.player beginSendingPlayMessages];
    
    _recorder = [SCRecorder recorder];
    _recorder.delegate = self;
    _recorder.videoEnabled = NO;
    _recorder.photoEnabled = NO;
    
    [_recorder openSession:^(NSError *sessionError, NSError *audioError, NSError *videoError, NSError *photoError) {
        if (audioError != nil) {
            [self showError:audioError];
        }
    }];
    [self hidePlayControl:NO];
}

- (void)showError:(NSError*)error {
      [[[UIAlertView alloc] initWithTitle:@"Something went wrong" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (IBAction)recordPressed:(id)sender {
    SCRecordSession *session = _recorder.recordSession;
    
    if (session == nil) {
        session = [SCRecordSession recordSession];
        session.fileType = AVFileTypeAppleM4A;
        
        _recorder.recordSession = session;
    }
    
    if (_recorder.isRecording) {
        [_recorder pause];
    } else {
        [_recorder record];
    }
    
    self.recordButton.selected = _recorder.isRecording;
}

- (void)hidePlayControl:(BOOL)animated {
    [UIView animateWithDuration:animated ? 0.3 : 0 animations:^{
        UIView *playView = self.playView;
        CGRect frame = playView.frame;
        frame.origin.y = self.view.frame.size.height;
        playView.frame = frame;
    }];
}

- (void)showPlayControl:(BOOL)animated {
    [UIView animateWithDuration:animated ? 0.3 : 0 animations:^{
        UIView *playView = self.playView;
        CGRect frame = playView.frame;
        frame.origin.y = self.view.frame.size.height - frame.size.height;
        playView.frame = frame;
    }];
}

- (void)recorder:(SCRecorder *)recorder didAppendAudioSampleBuffer:(SCRecordSession *)recordSession {
    self.recordTimeLabel.text = [NSString stringWithFormat:@"%.2fs", CMTimeGetSeconds(recordSession.currentRecordDuration)];
}

- (IBAction)stopRecordPressed:(id)sender {
    SCRecordSession *session = _recorder.recordSession;
    
    if (session != nil) {
        _recorder.recordSession = nil;
        [session endSession:^(NSError *error) {
            if (error == nil) {
                self.fileUrl = session.outputUrl;
                [self showPlayControl:YES];
                [self.player setItemByUrl:self.fileUrl];
            } else {
                [self showError:error];
            }
        }];
    }
    [_recorder pause];
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
