//
//  SCVideoConfiguration.m
//  SCRecorder
//
//  Created by Simon CORSIN on 21/11/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCVideoConfiguration.h"

@implementation SCVideoConfiguration

@synthesize usesRecommendedSettings;

- (id)init {
	self = [super init];

	if (self) {
		self.bitrate = kSCVideoConfigurationDefaultBitrate;
		_size = CGSizeZero;
		_codec = kSCVideoConfigurationDefaultCodec;
		_scalingMode = kSCVideoConfigurationDefaultScalingMode;
		_affineTransform = CGAffineTransformIdentity;
		_timeScale = 1;
		_keepInputAffineTransform = YES;
		usesRecommendedSettings = NO;
	}

	return self;
}

static CGSize MakeVideoSize(CGSize videoSize, float requestedWidth) {
	float ratio = videoSize.width / requestedWidth;

	if (ratio <= 1) {
		return videoSize;
	}

	return CGSizeMake(videoSize.width / ratio, videoSize.height / ratio);
}

- (NSDictionary *__nonnull)createAssetWriterOptionsWithVideoSize:(CGSize)videoSize usingOutput:(AVCaptureVideoDataOutput *)output {
	return [self createAssetWriterOptionsWithVideoSize:videoSize usingOutput:output sizeIsSuggestion:YES];
}

- (NSDictionary *)createAssetWriterOptionsUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer usingOutput:(AVCaptureVideoDataOutput *)output {
	CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	size_t width = CVPixelBufferGetWidth(imageBuffer);
	size_t height = CVPixelBufferGetHeight(imageBuffer);

	return [self createAssetWriterOptionsWithVideoSize:CGSizeMake(width, height) usingOutput:output];
}

- (NSDictionary *)createAssetWriterOptionsWithVideoSize:(CGSize)videoSize
											usingOutput:(AVCaptureVideoDataOutput *)output
									   sizeIsSuggestion:(BOOL)suggestion {
	NSDictionary *options = self.options;
	if (options != nil) {
		return options;
	}

	CGSize outputSize = self.size;
	unsigned long bitrate = (unsigned long)self.bitrate;

	if (self.preset != nil) {
		if ([self.preset isEqualToString:SCPresetLowQuality]) {
			bitrate = 500000;
			if (suggestion)
				outputSize = MakeVideoSize(videoSize, 640);
		} else if ([self.preset isEqualToString:SCPresetMediumQuality]) {
			bitrate = 1000000;
			if (suggestion)
				outputSize = MakeVideoSize(videoSize, 1280);
		} else if ([self.preset isEqualToString:SCPresetHighestQuality]) {
			bitrate = 6000000;
			if (suggestion)
				outputSize = MakeVideoSize(videoSize, 1920);
		} else {
			NSLog(@"Unrecognized video preset %@", self.preset);
		}
	}
	if (suggestion == NO)
		outputSize = videoSize;

	if (CGSizeEqualToSize(outputSize, CGSizeZero)) {
		outputSize = videoSize;
	}

	if (self.sizeAsSquare) {
		if (videoSize.width > videoSize.height) {
			outputSize.width = videoSize.height;
		} else {
			outputSize.height = videoSize.width;
		}
	}

	NSMutableDictionary *recommendedSettings = [[output
			recommendedVideoSettingsForVideoCodecType:self.codec
							assetWriterOutputFileType:AVFileTypeQuickTimeMovie] mutableCopy];
	if (usesRecommendedSettings) {
		NSNumber *recWidth = recommendedSettings[AVVideoWidthKey];
		NSNumber *recHeight = recommendedSettings[AVVideoHeightKey];
		outputSize = CGSizeMake(recWidth.floatValue, recHeight.floatValue);

		NSMutableDictionary *recommendedCompressionSettings = recommendedSettings[AVVideoCompressionPropertiesKey];

		NSMutableDictionary *apertureSettings = NSMutableDictionary.dictionary;
		apertureSettings[AVVideoCleanApertureWidthKey] = [NSNumber numberWithInteger:outputSize.width];
		apertureSettings[AVVideoCleanApertureHeightKey] = [NSNumber numberWithInteger:outputSize.height];
		apertureSettings[AVVideoCleanApertureHorizontalOffsetKey] = @(0);
		apertureSettings[AVVideoCleanApertureVerticalOffsetKey] = @(0);

		NSMutableDictionary *colorSettings = NSMutableDictionary.dictionary;
		BOOL supportsWideColor = [recommendedCompressionSettings[AVVideoAllowWideColorKey] boolValue];

		if (!supportsWideColor) {
			//HD
			colorSettings[AVVideoColorPrimariesKey] = AVVideoColorPrimaries_ITU_R_709_2;
			colorSettings[AVVideoTransferFunctionKey] = AVVideoTransferFunction_ITU_R_709_2;
			colorSettings[AVVideoYCbCrMatrixKey] = AVVideoYCbCrMatrix_ITU_R_709_2;
		} else {
			//Wide-color
			colorSettings[AVVideoColorPrimariesKey] = AVVideoColorPrimaries_P3_D65;
			colorSettings[AVVideoTransferFunctionKey] = AVVideoTransferFunction_ITU_R_709_2;
			colorSettings[AVVideoYCbCrMatrixKey] = AVVideoYCbCrMatrix_ITU_R_709_2;
		}

		recommendedSettings[AVVideoScalingModeKey] = self.scalingMode;
		recommendedSettings[AVVideoWidthKey] = [NSNumber numberWithInteger:outputSize.width];
		recommendedSettings[AVVideoHeightKey] = [NSNumber numberWithInteger:outputSize.height];
		recommendedSettings[AVVideoColorPropertiesKey] = colorSettings;
		recommendedSettings[AVVideoCleanApertureKey] = apertureSettings;
		recommendedSettings[AVVideoCompressionPropertiesKey] = recommendedCompressionSettings;
		NSLog(@"recommmended %@", recommendedSettings);
		return recommendedSettings;
	} else {
		NSMutableDictionary *compressionSettings = NSMutableDictionary.dictionary;

		compressionSettings[AVVideoAverageBitRateKey] = @(bitrate);

		if (self.codec == AVVideoCodecTypeH264) {
			compressionSettings[AVVideoMaxKeyFrameIntervalDurationKey] = @0.0f;
			if (self.shouldKeepOnlyKeyFrames) {
				compressionSettings[AVVideoMaxKeyFrameIntervalKey] = @1;
			}
			//only for h264
			//	compressionSettings[AVVideoAverageNonDroppableFrameRateKey] = @30;
		} else if (self.codec == AVVideoCodecTypeHEVC) {
			//		compressionSettings[AVVideoQualityKey] = @1.0;
		}
		if (self.profileLevel) {
			compressionSettings[AVVideoProfileLevelKey] = self.profileLevel;
		}
		//seems to break shit
		compressionSettings[AVVideoAllowWideColorKey] 					= @(YES);
		compressionSettings[AVVideoAllowFrameReorderingKey] 			= @(NO);
		//    [compressionSettings setObject:AVVideoH264EntropyModeCABAC forKey:AVVideoH264EntropyModeKey];
		//got rid of setting the frame rates.. not sure if it helped or not
		//	compressionSettings[AVVideoExpectedSourceFrameRateKey] = @60;

		return @{
				AVVideoCodecKey                : self.codec,
				AVVideoScalingModeKey          : self.scalingMode,
				AVVideoWidthKey                : [NSNumber numberWithInteger:outputSize.width],
				AVVideoHeightKey               : [NSNumber numberWithInteger:outputSize.height],
				AVVideoCompressionPropertiesKey: compressionSettings,
				AVVideoPixelAspectRatioKey     : AVVideoPixelAspectRatioHorizontalSpacingKey,
		};
	}
}

@end
