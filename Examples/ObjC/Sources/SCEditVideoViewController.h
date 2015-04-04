//
//  SCEditVideoViewController.h
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 22/07/14.
//
//

#import <UIKit/UIKit.h>
#import <SCRecorder/SCRecorder.h>

@interface SCEditVideoViewController : UIViewController

@property (strong, nonatomic) SCRecordSession *recordSession;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
- (IBAction)deletePressed:(id)sender;
@property (weak, nonatomic) IBOutlet SCVideoPlayerView *videoPlayerView;

@end
