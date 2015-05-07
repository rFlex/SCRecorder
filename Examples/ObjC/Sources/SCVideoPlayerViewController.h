//
//  SCVideoPlayerViewController.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/30/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCRecorder.h"

@interface SCVideoPlayerViewController : UIViewController<SCPlayerDelegate, SCAssetExportSessionDelegate>

@property (strong, nonatomic) SCRecordSession *recordSession;
@property (weak, nonatomic) IBOutlet SCSwipeableFilterView *filterSwitcherView;
@property (weak, nonatomic) IBOutlet UILabel *filterNameLabel;
@property (weak, nonatomic) IBOutlet UIView *exportView;
@property (weak, nonatomic) IBOutlet UIView *progressView;

@end
