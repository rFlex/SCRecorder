//
//  SCFilterSwitcherView.m
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 29/05/14.
//
//

#import "SCSwipeableFilterView.h"
#import "CIImageRendererUtils.h"
#import "SCSampleBufferHolder.h"
#import "SCFilterSelectorViewInternal.h"

@interface SCSwipeableFilterView() {
    CGFloat _filterGroupIndexRatio;
}

@end

@implementation SCSwipeableFilterView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (void)dealloc {
    
}

- (void)commonInit {
    [super commonInit];
    
    _refreshAutomaticallyWhenScrolling = YES;
    _selectFilterScrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _selectFilterScrollView.delegate = self;
    _selectFilterScrollView.pagingEnabled = YES;
    _selectFilterScrollView.showsHorizontalScrollIndicator = NO;
    _selectFilterScrollView.showsVerticalScrollIndicator = NO;
    _selectFilterScrollView.bounces = YES;
    _selectFilterScrollView.alwaysBounceHorizontal = YES;
    _selectFilterScrollView.alwaysBounceVertical = YES;
    _selectFilterScrollView.backgroundColor = [UIColor clearColor];
    
    [self addSubview:_selectFilterScrollView];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _selectFilterScrollView.frame = self.bounds;
    
    [self updateScrollViewContentSize];
}

- (void)updateScrollViewContentSize {
    _selectFilterScrollView.contentSize = CGSizeMake(self.filters.count * self.frame.size.width * 3, self.frame.size.height);
    
    if (self.selectedFilter != nil) {
        [self scrollToFilter:self.selectedFilter animated:NO];
    }
}

static CGRect CGRectTranslate(CGRect rect, CGFloat width, CGFloat maxWidth) {
    rect.origin.x += width;
    
    return rect;
}

- (void)scrollToFilter:(SCFilter *)filter animated:(BOOL)animated {
    NSInteger index = [self.filters indexOfObject:filter];
    if (index >= 0) {
        CGPoint contentOffset = CGPointMake(_selectFilterScrollView.contentSize.width / 3 + _selectFilterScrollView.frame.size.width * index, 0);
        [_selectFilterScrollView setContentOffset:contentOffset animated:animated];
        [self updateCurrentSelected:NO];
    } else {
        [NSException raise:@"InvalidFilterException" format:@"This filter is not present in the filters array"];
    }
}

- (void)updateCurrentSelected:(BOOL)shouldNotify {
    NSUInteger filterGroupsCount = self.filters.count;
    NSInteger selectedIndex = (NSInteger)((_selectFilterScrollView.contentOffset.x + _selectFilterScrollView.frame.size.width / 2) / _selectFilterScrollView.frame.size.width) % filterGroupsCount;
    SCFilter *newFilterGroup = nil;
    
    if (selectedIndex >= 0 && selectedIndex < filterGroupsCount) {
        newFilterGroup = [self.filters objectAtIndex:selectedIndex];
    } else {
        NSLog(@"Invalid contentOffset of scrollView in SCFilterSwitcherView (%f/%f with %d)", _selectFilterScrollView.contentOffset.x, _selectFilterScrollView.contentOffset.y, (int)self.filters.count);
    }
    
    if (self.selectedFilter != newFilterGroup) {
        [self setSelectedFilter:newFilterGroup];
        
        if (shouldNotify) {
            id<SCSwipeableFilterViewDelegate> del = self.delegate;
            
            if ([del respondsToSelector:@selector(swipeableFilterView:didScrollToFilter:)]) {
                [del swipeableFilterView:self didScrollToFilter:newFilterGroup];
            }
        }
    }
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    [self updateCurrentSelected:YES];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self updateCurrentSelected:YES];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self updateCurrentSelected:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat width = scrollView.frame.size.width;
    CGFloat contentOffsetX = scrollView.contentOffset.x;
    CGFloat contentSizeWidth = scrollView.contentSize.width;
    CGFloat normalWidth = self.filters.count * width;
    
    if (contentOffsetX <= 0) {
        scrollView.contentOffset = CGPointMake(contentOffsetX + normalWidth, scrollView.contentOffset.y);
    } else if (contentOffsetX + width >= contentSizeWidth) {
        scrollView.contentOffset = CGPointMake(contentOffsetX - normalWidth, scrollView.contentOffset.y);
    }
    
    CGFloat ratio = scrollView.contentOffset.x / width;
    
    _filterGroupIndexRatio = ratio;
    
    if (_refreshAutomaticallyWhenScrolling) {
        [self refresh];
    }
}

- (void)render:(CIImage *)image toContext:(CIContext *)context inRect:(CGRect)rect {
    CGRect extent = [image extent];
    
    CGFloat ratio = _filterGroupIndexRatio;
    
    NSInteger index = (NSInteger)ratio;
    NSInteger upIndex = (NSInteger)ceilf(ratio);
    CGFloat remainingRatio = ratio - ((CGFloat)index);
    
    NSArray *filterGroups = self.filters;
    
    CGFloat xOutputRect = rect.size.width * -remainingRatio;
    CGFloat xImage = extent.size.width * -remainingRatio;
    CFTimeInterval imageTime = self.CIImageTime;
    
    while (index <= upIndex) {
        NSInteger currentIndex = index % filterGroups.count;
        id obj = [filterGroups objectAtIndex:currentIndex];
        CIImage *imageToUse = image;
        
        if ([obj isKindOfClass:[SCFilter class]]) {
            imageToUse = [((SCFilter *)obj) imageByProcessingImage:imageToUse atTime:imageTime];
        }
        
        CGRect outputRect = CGRectTranslate(rect, xOutputRect, rect.size.width);
        CGRect fromRect = CGRectTranslate(extent, xImage, extent.size.width);
        
        [context drawImage:imageToUse inRect:outputRect fromRect:fromRect];
        
        xOutputRect += rect.size.width;
        xImage += extent.size.width;
        index++;
    }
}

- (void)setFilters:(NSArray *)filters {
    [super setFilters:filters];
    
    [self updateScrollViewContentSize];
}

@end
