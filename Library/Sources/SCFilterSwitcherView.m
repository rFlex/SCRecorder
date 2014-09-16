//
//  SCFilterSwitcherView.m
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 29/05/14.
//
//

#import "SCFilterSwitcherView.h"
#import "CIImageRendererUtils.h"
#import "SCSampleBufferHolder.h"

@interface SCFilterSwitcherView() {
    CGFloat _filterGroupIndexRatio;
    CIContext *_CIContext;
    EAGLContext *_EAGLContext;
    GLKView *_glkView;
    SCSampleBufferHolder *_sampleBufferHolder;
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
}

- (void)_commonInit {
    _selectFilterScrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _selectFilterScrollView.delegate = self;
    _selectFilterScrollView.pagingEnabled = YES;
    _selectFilterScrollView.showsHorizontalScrollIndicator = NO;
    _selectFilterScrollView.showsVerticalScrollIndicator = NO;
    _selectFilterScrollView.backgroundColor = [UIColor clearColor];
    
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    _glkView = [[GLKView alloc] initWithFrame:self.bounds context:context];
    
    NSDictionary *options = @{ kCIContextWorkingColorSpace : [NSNull null] };
    _CIContext = [CIContext contextWithEAGLContext:context options:options];
    
    _glkView.delegate = self;
    
    _sampleBufferHolder = [SCSampleBufferHolder new];
    
    [self addSubview:_glkView];
    [self addSubview:_selectFilterScrollView];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _glkView.frame = self.bounds;
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
    id newFilterGroup = nil;
    
    if (selectedIndex >= 0 && selectedIndex < filterGroupsCount) {
        newFilterGroup = [_filterGroups objectAtIndex:selectedIndex];
    } else {
        NSLog(@"Invalid contentOffset of scrollView in SCFilterSwitcherView (%f/%f with %d)", _selectFilterScrollView.contentOffset.x, _selectFilterScrollView.contentOffset.y, (int)_filterGroups.count);
    }
    
    if (newFilterGroup == [NSNull null]) {
        newFilterGroup = nil;
    }
    
    if (_selectedFilterGroup != newFilterGroup) {
        [self willChangeValueForKey:@"selectedFilterGroup"]
        ;
        _selectedFilterGroup = newFilterGroup;
        
        [self didChangeValueForKey:@"selectedFilterGroup"];
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
    
    [_glkView setNeedsDisplay];
}

- (void)setNeedsDisplay {
    [super setNeedsDisplay];
    [_glkView setNeedsDisplay];
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    CIImage *newImage = [CIImageRendererUtils generateImageFromSampleBufferHolder:_sampleBufferHolder];
    
    if (newImage != nil) {
        _CIImage = newImage;
    }
    
    CIImage *outputImage = _CIImage;
    
    if (outputImage != nil) {
        CGRect extent = [outputImage extent];
        CIContext *context = _CIContext;
        
        rect = [CIImageRendererUtils processRect:rect withImageSize:extent.size contentScale:_glkView.contentScaleFactor contentMode:self.contentMode];
        
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

- (UIImage *)currentlyDisplayedImageWithScale:(CGFloat)scale orientation:(UIImageOrientation)imageOrientation {
    CIImage *inputImage = self.CIImage;
    
    CIImage *processedImage = [self.selectedFilterGroup imageByProcessingImage:inputImage];
    
    if (processedImage == nil) {
        processedImage = inputImage;
    }
    
    if (processedImage == nil) {
        return nil;
    }
    
    CGImageRef outputImage = [_CIContext createCGImage:processedImage fromRect:inputImage.extent];
    
    UIImage *image = [UIImage imageWithCGImage:outputImage scale:scale orientation:imageOrientation];
    
    CGImageRelease(outputImage);
    
    return image;
}

- (void)setImageBySampleBuffer:(CMSampleBufferRef)sampleBuffer {
    _sampleBufferHolder.sampleBuffer = sampleBuffer;
    
    [_glkView setNeedsDisplay];
}

- (void)setFilterGroups:(NSArray *)filterGroups {
    _filterGroups = filterGroups;
    
    [self updateScrollViewContentSize];
}

- (void)setCIImage:(CIImage *)CIImage {
    _CIImage = CIImage;
    [_glkView setNeedsDisplay];
}

- (CIImage *)image {
    return self.CIImage;
}

- (void)setImage:(CIImage *)image {
    self.CIImage = image;
}

- (void)setPreferredCIImageTransform:(CGAffineTransform)preferredCIImageTransform {
    _glkView.transform = preferredCIImageTransform;
}

@end
