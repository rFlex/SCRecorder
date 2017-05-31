//
//  SCFilterSwitcherView.m
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 29/05/14.
//
//

#import "SCSwipeableFilterView.h"
#import "SCSampleBufferHolder.h"

@interface SCSwipeableFilterView() {
}

@end

@implementation SCSwipeableFilterView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self _swipeableCommonInit];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self _swipeableCommonInit];
    }
    
    return self;
}

- (void)dealloc {
    
}

- (void)_swipeableCommonInit {
    _horizontalScroll = true;
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

- (void)setHorizontalScroll:(BOOL)horizontalScroll {
    _horizontalScroll = horizontalScroll;
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _selectFilterScrollView.frame = self.bounds;
    
    [self updateScrollViewContentSize];
}

- (void)updateScrollViewContentSize {
    if (_horizontalScroll) {
        _selectFilterScrollView.contentSize = CGSizeMake(self.filters.count * self.bounds.size.width * 3, self.bounds.size.height);
    } else {
        _selectFilterScrollView.contentSize = CGSizeMake(self.bounds.size.width, self.filters.count * self.bounds.size.height * 3);
    }
    
    if (self.selectedFilter != nil) {
        [self scrollToFilter:self.selectedFilter animated:NO];
    }
}

- (void)scrollToFilter:(SCFilter *)filter animated:(BOOL)animated {
    NSInteger index = [self.filters indexOfObject:filter];
    if (index >= 0) {
        if (_horizontalScroll) {
            CGPoint contentOffset = CGPointMake(_selectFilterScrollView.contentSize.width / 3 + _selectFilterScrollView.frame.size.width * index, 0);
            [_selectFilterScrollView setContentOffset:contentOffset animated:animated];
        } else {
            CGPoint contentOffset = CGPointMake(0, _selectFilterScrollView.contentSize.height / 3 + _selectFilterScrollView.frame.size.height * index);
            [_selectFilterScrollView setContentOffset:contentOffset animated:animated];
        }
        [self updateCurrentSelected:NO];
    } else {
        [NSException raise:@"InvalidFilterException" format:@"This filter is not present in the filters array"];
    }
}

- (void)updateCurrentSelected:(BOOL)shouldNotify {
    NSUInteger filterGroupsCount = self.filters.count;
    NSInteger selectedIndex;
    if (_horizontalScroll) {
        selectedIndex = (NSInteger)((_selectFilterScrollView.contentOffset.x + _selectFilterScrollView.frame.size.width / 2) / _selectFilterScrollView.frame.size.width) % filterGroupsCount;
    } else {
        selectedIndex = (NSInteger)((_selectFilterScrollView.contentOffset.y + _selectFilterScrollView.frame.size.height / 2) / _selectFilterScrollView.frame.size.height) % filterGroupsCount;
    }
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

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    id<SCSwipeableFilterViewDelegate> del = self.delegate;
    if ([del respondsToSelector:@selector(swipeableFilterViewDidBeginScroll:)]) {
        [del swipeableFilterViewDidBeginScroll:self];
    }
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    [self updateCurrentSelected:YES];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self updateCurrentSelected:YES];
    id<SCSwipeableFilterViewDelegate> del = self.delegate;
    if ([del respondsToSelector:@selector(swipeableFilterViewDidEndScroll:)]) {
        [del swipeableFilterViewDidEndScroll:self];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self updateCurrentSelected:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!scrollView.isDragging && !scrollView.isDecelerating) {
            id<SCSwipeableFilterViewDelegate> del = self.delegate;
            if ([del respondsToSelector:@selector(swipeableFilterViewDidEndScroll:)]) {
                [del swipeableFilterViewDidEndScroll:self];
            }
        }
    });
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self updateCurrentSelected:YES];
        id<SCSwipeableFilterViewDelegate> del = self.delegate;
        if ([del respondsToSelector:@selector(swipeableFilterViewDidEndScroll:)]) {
            [del swipeableFilterViewDidEndScroll:self];
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_horizontalScroll) {
        CGFloat width = scrollView.frame.size.width;
        CGFloat contentOffsetX = scrollView.contentOffset.x;
        CGFloat contentSizeWidth = scrollView.contentSize.width;
        CGFloat normalWidth = self.filters.count * width;
        
        if (width > 0 && contentSizeWidth > 0) {
            if (contentOffsetX <= 0) {
                scrollView.contentOffset = CGPointMake(contentOffsetX + normalWidth, scrollView.contentOffset.y);
            } else if (contentOffsetX + width >= contentSizeWidth) {
                scrollView.contentOffset = CGPointMake(contentOffsetX - normalWidth, scrollView.contentOffset.y);
            }
        }
    } else {
        CGFloat height = scrollView.frame.size.height;
        CGFloat contentOffsetY = scrollView.contentOffset.y;
        CGFloat contentSizeHeight = scrollView.contentSize.height;
        CGFloat normalHeight = self.filters.count * height;
        
        if (height > 0 && contentSizeHeight > 0) {
            if (contentOffsetY <= 0) {
                scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, contentOffsetY + normalHeight);
            } else if (contentOffsetY + height >= contentSizeHeight) {
                scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, contentOffsetY - normalHeight);
            }
        }
    }
    
    if (_refreshAutomaticallyWhenScrolling) {
        [self setNeedsDisplay];
    }
}

- (CIImage *)renderedCIImage {
    CIImage *image = [super renderedCIImage];

    CFTimeInterval imageTime = self.CIImageTime;
    if (self.preprocessingFilter != nil) {
        image = [self.preprocessingFilter imageByProcessingImage:image atTime:imageTime];
    }

    CGRect extent = [image extent];

    CGSize contentSize = _selectFilterScrollView.frame.size;

    CIImage *outputImage = [CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:0]];
    if (_horizontalScroll) {
        if (contentSize.width == 0) {
            return image;
        }
        
        CGFloat ratio = _selectFilterScrollView.contentOffset.x / contentSize.width;
        
        NSInteger index = (NSInteger)ratio;
        NSInteger upIndex = (NSInteger)ceilf(ratio);
        CGFloat remainingRatio = ratio - ((CGFloat)index);
        
        NSArray *filters = self.filters;
        
        CGFloat xImage = extent.size.width * -remainingRatio;
        
        while (index <= upIndex) {
            NSInteger currentIndex = index % filters.count;
            SCFilter *filter = [filters objectAtIndex:currentIndex];
            CIImage *filteredImage = [filter imageByProcessingImage:image atTime:imageTime];
            filteredImage = [filteredImage imageByCroppingToRect:CGRectMake(extent.origin.x + xImage, extent.origin.y, extent.size.width, extent.size.height)];
            outputImage = [filteredImage imageByCompositingOverImage:outputImage];
            xImage += extent.size.width;
            index++;
        }
        outputImage = [outputImage imageByCroppingToRect:extent];
    } else {
        if (contentSize.height == 0) {
            return image;
        }
        
        CGFloat ratio = _selectFilterScrollView.contentOffset.y / contentSize.height;
        
        NSInteger index = (NSInteger)ratio;
        NSInteger upIndex = (NSInteger)ceilf(ratio);
        CGFloat remainingRatio = ratio - ((CGFloat)index);
        
        NSArray *filters = self.filters;
        
        CGFloat xImage = extent.size.height * -remainingRatio;
        
        while (index <= upIndex) {
            NSInteger currentIndex = index % filters.count;
            SCFilter *filter = [filters objectAtIndex:currentIndex];
            CIImage *filteredImage = [filter imageByProcessingImage:image atTime:imageTime];
            filteredImage = [filteredImage imageByCroppingToRect:CGRectMake(extent.origin.x, extent.origin.y - xImage, extent.size.width, extent.size.height)];
            outputImage = [filteredImage imageByCompositingOverImage:outputImage];
            xImage += extent.size.height;
            index++;
        }
        outputImage = [outputImage imageByCroppingToRect:extent];
    }

    return outputImage;
}

- (void)setFilters:(NSArray *)filters {
    _filters = filters;
    [self updateScrollViewContentSize];
    [self updateCurrentSelected:YES];
}

- (void)setSelectedFilter:(SCFilter *)selectedFilter {
    if (_selectedFilter != selectedFilter) {
        [self willChangeValueForKey:@"selectedFilter"];
        _selectedFilter = selectedFilter;

        [self didChangeValueForKey:@"selectedFilter"];

        [self setNeedsLayout];
    }
}

@end
