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

- (void)_commonInit {
    _selectFilterScrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _selectFilterScrollView.delegate = self;
    _selectFilterScrollView.pagingEnabled = YES;
    
    _cameraImageView = [[SCImageView alloc] initWithFrame:self.bounds];
    _cameraImageView.delegate = self;
 
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
    
    if (rect.origin.x < 0) {
        rect.size.width += rect.origin.x;
        rect.origin.x = 0;
    }
    
    if (rect.size.width > maxWidth) {
        rect.size.width = maxWidth;
    }
    
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
    [_cameraImageView makeDirty];
}

- (void)updatePlayer {
    _cameraImageView.hidden = _disabled;
    _selectFilterScrollView.hidden = _disabled;
    _player.useCoreImageView = !_disabled;
    _player.outputView = _disabled ? self : nil;
    _player.imageView = _disabled ? nil : _cameraImageView;
}

- (void)glkView:(SCImageView *)view drawInRect:(CGRect)rect {
    CIImage *outputImage = view.image;
    if (outputImage != nil) {
        CGRect extent = view.imageSize;
        CIContext *context = view.ciContext;
        rect = [view rectByApplyingContentScale:rect];
        
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
        
        for (NSInteger i = index, count = filterGroups.count; i <= upIndex && i < count; i++) {
            id obj = [filterGroups objectAtIndex:i];
            CIImage *imageToUse = outputImage;
            
            if ([obj isKindOfClass:[SCFilterGroup class]]) {
                imageToUse = [((SCFilterGroup *)obj) imageByProcessingImage:imageToUse];
            }
            
            CGRect outputRect = CGRectTranslate(rect, xOutputRect, rect.size.width);
            CGRect fromRect = CGRectTranslate(extent, xImage, extent.size.width);
            
            [context drawImage:imageToUse inRect:outputRect fromRect:fromRect];
            
            xOutputRect += rect.size.width;
            xImage += extent.size.width;
        }
    }
}

- (void)setPlayer:(SCPlayer *)player {
    if (player != _player) {
        if (_player != nil) {
            _player.delegate = nil;
            _player.outputView = nil;
            _player.imageView = nil;
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


@end
