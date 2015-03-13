//
//  SCEditVideoViewController.m
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 22/07/14.
//
//

#import "SCEditVideoViewController.h"

@interface SCEditVideoViewController () {
    NSMutableArray *_thumbnails;
    NSInteger _currentSelected;
}

@end

@implementation SCEditVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.videoPlayerView.tapToPauseEnabled = YES;
    self.videoPlayerView.player.loopEnabled = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSMutableArray *thumbnails = [NSMutableArray new];
    NSInteger i = 0;
    
    for (SCRecordSessionSegment *segment in self.recordSession.segments) {
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.image = segment.thumbnail;
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(touchedVideo:)];
        imageView.userInteractionEnabled = YES;
        
        [imageView addGestureRecognizer:tapGesture];
        
        [thumbnails addObject:imageView];
        
        [self.scrollView addSubview:imageView];
        
        i++;
    }
    
    _thumbnails = thumbnails;
    
    [self reloadScrollView];
    [self showVideo:0];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.videoPlayerView.player pause];
}

- (void)touchedVideo:(UITapGestureRecognizer *)gesture {
    NSInteger idx = [_thumbnails indexOfObject:gesture.view];
    
    [self showVideo:idx];
}

- (void)showVideo:(NSInteger)idx {
    if (idx < 0) {
        idx = 0;
    }
    
    if (idx < _recordSession.segments.count) {
        SCRecordSessionSegment *segment = [_recordSession.segments objectAtIndex:idx];
        [self.videoPlayerView.player setItemByAsset:segment.asset];
        [self.videoPlayerView.player play];
    }
    
    _currentSelected = idx;

    for (NSInteger i = 0; i < _thumbnails.count; i++) {
        UIImageView *imageView = [_thumbnails objectAtIndex:i];
        
        imageView.alpha = i == idx ? 1 : 0.5;
    }
}

- (void)reloadScrollView {
    CGFloat cellSize = self.scrollView.frame.size.height;
    int i = 0;
    for (UIImageView *imageView in _thumbnails) {
        imageView.frame = CGRectMake(cellSize * i, 0, cellSize, cellSize);
        i++;
    }
    self.scrollView.contentSize = CGSizeMake(_thumbnails.count * self.scrollView.frame.size.height, self.scrollView.frame.size.height);
}

- (IBAction)deletePressed:(id)sender {
    if (_currentSelected < _recordSession.segments.count) {
        [_recordSession removeSegmentAtIndex:_currentSelected deleteFile:YES];
        UIImageView *imageView = [_thumbnails objectAtIndex:_currentSelected];
        [_thumbnails removeObjectAtIndex:_currentSelected];
        [UIView animateWithDuration:0.3 animations:^{
            imageView.transform = CGAffineTransformMakeScale(0, 0);
            [self reloadScrollView];
        } completion:^(BOOL finished) {
            [imageView removeFromSuperview];
        }];
        
        [self showVideo:_currentSelected % _recordSession.segments.count];
    }
}
@end
