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
    SCRecordSession *_recordSession;
}

@property (strong, nonatomic) SCPlayer *player;

@end

@implementation SCAudioRecordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.player = [SCPlayer player];
    self.player.delegate = self;
    [self.player beginSendingPlayMessages];
    
    _recorder = [SCRecorder recorder];
    _recorder.delegate = self;
    _recorder.photoConfiguration.enabled = NO;
    _recorder.videoConfiguration.enabled = NO;
    
    NSError *error;
    if (![_recorder prepare:&error]) {
        [self showError:error];
    }
    
    [self hidePlayControl:NO];
    [self createSession];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [_recorder startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [_recorder stopRunning];
}

- (void)dealloc {
    [self.player endSendingPlayMessages];
}

- (void)showError:(NSError*)error {
      [[[UIAlertView alloc] initWithTitle:@"Something went wrong" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (void)createSession {
    SCRecordSession *session = [SCRecordSession recordSession];
    session.fileType = AVFileTypeAppleM4A;
    [self updateRecordTimeLabel:kCMTimeZero];
    
    _recorder.session = session;
}

- (void)updateRecordTimeLabel:(CMTime)time {
    self.recordTimeLabel.text = [NSString stringWithFormat:@"%.2fs", CMTimeGetSeconds(time)];
}

- (IBAction)recordPressed:(id)sender {
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
    [self updateRecordTimeLabel:recordSession.currentRecordDuration];
}

- (void)deleteRecordSession {
    [self.player setItemByAsset:nil];
    [_recordSession removeAllSegments];
    _recordSession = nil;
}

- (IBAction)stopRecordPressed:(id)sender {
    [_recorder pause:^{
        [self deleteRecordSession];
        [self showPlayControl:YES];
        _recordSession = _recorder.session;
        
        AVAsset *asset = _recordSession.assetRepresentingSegments;
        self.playSlider.maximumValue = CMTimeGetSeconds(asset.duration);
        [self.player setItemByAsset:asset];
        
        [self createSession];
    }];}

- (IBAction)playButtonPressed:(id)sender {
    if (self.player.isPlaying) {
        [self.player pause];
    } else {
        [self.player play];
    }
    
    [self _updatePlayButton];
}

- (void)_updatePlayButton {
    self.playButton.selected = self.player.isPlaying;
}

- (void)player:(SCPlayer *)player didReachEndForItem:(AVPlayerItem *)item {
    [player pause];
    [player seekToTime:kCMTimeZero];
    [self _updatePlayButton];
}

- (void)player:(SCPlayer *)player didPlay:(CMTime)currentTime loopsCount:(NSInteger)loopsCount {
    self.playSlider.value = CMTimeGetSeconds(currentTime);
    self.playLabel.text = [NSString stringWithFormat:@"%.2fs", CMTimeGetSeconds(currentTime)];
}

- (IBAction)playSliderValueChanged:(id)sender {
    [self.player seekToTime:CMTimeMakeWithSeconds(self.playSlider.value, 1000)];
}

- (IBAction)deletePressed:(id)sender {
    [self hidePlayControl:YES];
    [self deleteRecordSession];
}

@end
