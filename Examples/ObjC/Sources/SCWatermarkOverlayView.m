//
//  SCWatermarkOverlayView.m
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 16/06/15.
//
//

#import "SCWatermarkOverlayView.h"

@interface SCWatermarkOverlayView() {
    UILabel *_watermarkLabel;
    UILabel *_timeLabel;
}


@end

@implementation SCWatermarkOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        _watermarkLabel = [UILabel new];
        _watermarkLabel.textColor = [UIColor whiteColor];
        _watermarkLabel.font = [UIFont boldSystemFontOfSize:40];
        _watermarkLabel.text = @"SCRecorder ©";
        
        _timeLabel = [UILabel new];
        _timeLabel.textColor = [UIColor yellowColor];
        _timeLabel.font = [UIFont boldSystemFontOfSize:40];
        
        [self addSubview:_watermarkLabel];
        [self addSubview:_timeLabel];
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
        
    static const CGFloat inset = 8;
    
    CGSize size = self.bounds.size;
    
    [_watermarkLabel sizeToFit];
    CGRect watermarkFrame = _watermarkLabel.frame;
    watermarkFrame.origin.x = size.width - watermarkFrame.size.width - inset;
    watermarkFrame.origin.y = size.height - watermarkFrame.size.height - inset;
    _watermarkLabel.frame = watermarkFrame;
    
    [_timeLabel sizeToFit];
    CGRect timeLabelFrame = _timeLabel.frame;
    timeLabelFrame.origin.y = inset;
    timeLabelFrame.origin.x = inset;
    _timeLabel.frame = timeLabelFrame;
}

- (void)updateWithVideoTime:(NSTimeInterval)time {
    NSDate *currentDate = [self.date dateByAddingTimeInterval:time];
    _timeLabel.text = [NSString stringWithFormat:@"%@", currentDate];
}

@end
