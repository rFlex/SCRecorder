//
//  SCVideoViewCell.m
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 22/07/14.
//
//

#import "SCVideoViewCell.h"

@implementation SCVideoViewCell

const CGFloat k90DegreesClockwiseAngle = (CGFloat) (90 * M_PI / 180.0);

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        CGRect frame = self.frame;
        self.transform = CGAffineTransformRotate(CGAffineTransformIdentity, k90DegreesClockwiseAngle);
        
        frame.size.width = frame.size.height;
        self.frame = frame;
    }
    return self;
}

- (void)awakeFromNib {
    
}

@end
