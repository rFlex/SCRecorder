//
//  SCFilterSwitcherView.m
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 29/05/14.
//
//

#import "SCFilterSwitcherView.h"

@interface SCFilterSwitcherView() {
    CGFloat _filterGroupIndexRatio;
    SCImageView *_cameraImageView;
}

@end

@implementation SCFilterSwitcherView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self _commonInit];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self _commonInit];
    }
    
    return self;
}

- (void)dealloc {
    _player.outputView = nil;
    _player.SCImageView = nil;
    _player.useCoreImageView = NO;
}

- (void)_commonInit {
    _selectFilterScrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _selectFilterScrollView.delegate = self;
    _selectFilterScrollView.pagingEnabled = YES;
    _selectFilterScrollView.showsHorizontalScrollIndicator = NO;
    _selectFilterScrollView.showsVerticalScrollIndicator = NO;
    _selectFilterScrollView.backgroundColor = [UIColor clearColor];
    
    _cameraImageView = [[SCImageView alloc] initWithFrame:self.bounds];
    _cameraImageView.delegate = self;
    _cameraImageView.contentMode = self.contentMode;
 
    [self addSubview:_cameraImageView];
    [self addSubview:_selectFilterScrollView];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _cameraImageView.frame = self.bounds;
    _selectFilterScrollView.frame = self.bounds;

    [self updateScrollViewContentSize];
}

- (void)updateScrollViewContentSize {
    _selectFilterScrollView.contentSize = CGSizeMake(_filterGroups.count * self.frame.size.width * 2, self.frame.size.height);
}

static CGRect CGRectTranslate(CGRect rect, CGFloat width, CGFloat maxWidth) {
    rect.origin.x += width;

    return rect;
}

- (void)updateCurrentSelected {
    NSUInteger filterGroupsCount = _filterGroups.count;
    NSInteger selectedIndex = (NSInteger)((_selectFilterScrollView.contentOffset.x + _selectFilterScrollView.frame.size.width / 2) / _selectFilterScrollView.frame.size.width) % filterGroupsCount;
    
    if (selectedIndex >= 0 && selectedIndex < filterGroupsCount) {
        _selectedFilterGroup = [_filterGroups objectAtIndex:selectedIndex];
    } else {
        NSLog(@"Invalid contentOffset of scrollView in SCFilterSwitcherView (%f/%f with %d)", _selectFilterScrollView.contentOffset.x, _selectFilterScrollView.contentOffset.y, (int)_filterGroups.count);
        _selectedFilterGroup = nil;
    }
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    [self updateCurrentSelected];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self updateCurrentSelected];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self updateCurrentSelected];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat width = scrollView.frame.size.width;
    CGFloat contentOffsetX = scrollView.contentOffset.x;
    CGFloat contentSizeWidth = scrollView.contentSize.width;
    CGFloat normalWidth = _filterGroups.count * width;
    
    if (contentOffsetX < 0) {
        scrollView.contentOffset = CGPointMake(contentOffsetX + normalWidth, scrollView.contentOffset.y);
    } else if (contentOffsetX + width > contentSizeWidth) {
        scrollView.contentOffset = CGPointMake(contentOffsetX - normalWidth, scrollView.contentOffset.y);
    }
    
    CGFloat ratio = scrollView.contentOffset.x / width;
    
    _filterGroupIndexRatio = ratio;
    
    if (_player == nil) {
        [_cameraImageView setNeedsDisplay];
    } else {
        [_cameraImageView makeDirty];
    }
}

- (void)updatePlayer {
    _cameraImageView.hidden = _disabled;
    _selectFilterScrollView.hidden = _disabled;
    SCPlayer *player = _player;
    
    player.SCImageView = _disabled ? nil : _cameraImageView;
    player.outputView = _disabled ? self : nil;
    player.useCoreImageView = !_disabled;
}

- (void)glkView:(SCImageView *)view drawInRect:(CGRect)rect {
    CIImage *outputImage = view.image;
    if (outputImage != nil) {
//        NSLog(@"%@", NSStringFromCGAffineTransform(view.transform));
        CGRect extent = view.imageSize;
        CIContext *context = view.ciContext;
//        NSLog(@"%f/%f/%f/%f", exte);
        
        rect = [view processRect:rect withImageSize:extent.size];
        
        CGFloat ratio = _filterGroupIndexRatio;
        
        NSInteger index = (NSInteger)ratio;
        NSInteger upIndex = (NSInteger)ceilf(ratio);
        CGFloat remainingRatio = ratio - ((CGFloat)index);
        
        NSArray *filterGroups = _filterGroups;
        
        CGFloat xOutputRect = rect.size.width * -remainingRatio;
        CGFloat xImage = extent.size.width * -remainingRatio;
        
        while (index <= upIndex) {
            NSInteger currentIndex = index % filterGroups.count;
            id obj = [filterGroups objectAtIndex:currentIndex];
            CIImage *imageToUse = outputImage;
            
            if ([obj isKindOfClass:[SCFilterGroup class]]) {
                imageToUse = [((SCFilterGroup *)obj) imageByProcessingImage:imageToUse];
            }
            
            CGRect outputRect = CGRectTranslate(rect, xOutputRect, rect.size.width);
            CGRect fromRect = CGRectTranslate(extent, xImage, extent.size.width);
            
            [context drawImage:imageToUse inRect:outputRect fromRect:fromRect];
            
            xOutputRect += rect.size.width;
            xImage += extent.size.width;
            index++;
        }
    }
}

- (void)setPlayer:(SCPlayer *)player {
    SCPlayer *oldInstance = _player;
    if (player != oldInstance) {
        if (oldInstance != nil) {
            oldInstance.delegate = nil;
            oldInstance.outputView = nil;
            oldInstance.SCImageView = nil;
        }
        
        _player = player;
        
        player.delegate = self;
        
        [self updatePlayer];
    }
}

- (void)setFilterGroups:(NSArray *)filterGroups {
    _filterGroups = filterGroups;
    
    [self updateScrollViewContentSize];
}

- (void)setDisabled:(BOOL)disabled {
    if (_disabled != disabled) {
        _disabled = disabled;
        
        [self updatePlayer];
    }
}

- (CIImage *)image {
    return _cameraImageView.image;
}

- (void)setImage:(CIImage *)image {
    _cameraImageView.image = image;
    _cameraImageView.imageSize = [image extent];
    [_cameraImageView setNeedsDisplay];
}

- (SCImageView *)SCImageView {
    return _cameraImageView;
}

@end
