//
//  SCSessionTableViewCell.h
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 14/08/14.
//
//

#import <UIKit/UIKit.h>
#import <SCVideoPlayerView.h>

@interface SCSessionTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet SCVideoPlayerView *videoPlayerView;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *segmentsCountLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;

@end
