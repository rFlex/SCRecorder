//
//  SCAudioRecordViewController.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 18/12/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SCRecorder/SCRecorder.h>

@interface SCAudioRecordViewController : UIViewController<SCRecorderDelegate, SCPlayerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *stopRecordingButton;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (weak, nonatomic) IBOutlet UILabel *recordTimeLabel;

@property (weak, nonatomic) IBOutlet UIView *playView;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UISlider *playSlider;
@property (weak, nonatomic) IBOutlet UIButton *deleteButton;
@property (weak, nonatomic) IBOutlet UILabel *playLabel;

- (IBAction)recordPressed:(id)sender;
- (IBAction)stopRecordPressed:(id)sender;
- (IBAction)playButtonPressed:(id)sender;
- (IBAction)playSliderValueChanged:(id)sender;
- (IBAction)deletePressed:(id)sender;

@end
