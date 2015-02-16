SCRecorder
===============

<img src="filters.gif" width="256" height="454" />
<img src="screenshot_2.png" width="256" height="454" />
![](screenshot_2.png)

A Vine/Instagram like audio/video recorder and filter framework in Objective-C.

In short, here is a short list of the cool things you can do:
- Record multiple video segments
- Remove any record segment that you don't want
- Display the result into a convenient video player
- Save the record session for later somewhere using a serializable NSDictionary (works in NSUserDefaults)
- Add a video filter using Core Image
- Add a watermark
- Merge and export the video using fine tunings that you choose


Examples for iOS are provided.

Want something easy to create your filters in this project? Checkout https://github.com/rFlex/CoreImageShop

Framework needed:
- CoreVideo
- AudioToolbox
- GLKit

Podfile
----------------

If you are using cocoapods, you can use this project with the following Podfile

```ruby
	platform :ios, '7.0'
	pod 'SCRecorder'
```

Getting started
----------------

[SCRecorder](Library/Sources/SCRecorder.h) is the main class that connect the inputs and outputs together. It will handle all the underlying AVFoundation stuffs.

```objective-c
// Create the recorder
SCRecorder *recorder = [SCRecorder recorder]; // You can also use +[SCRecorder sharedRecorder]
	
// Set the sessionPreset used by the AVCaptureSession
recorder.sessionPreset = AVCaptureSessionPresetHigh;
	
// Listen to some messages from the recorder!
recorder.delegate = self;
	
// Initialize the audio and video inputs using the parameters set in the SCRecorder
[recorder openSession: ^(NSError *sessionError, NSError *audioError, NSError *videoError, NSError *photoError) {
	// Start the flow of inputs
	[recorder startRunningSession];
}];
```

Configuring the recorder
--------------------

You can configure the video, audio and photo output settings in their configuration instance ([SCVideoConfiguration](Library/Sources/SCVideoConfiguration.h), [SCAudioConfiguration](Library/Sources/SCAudioConfiguration.h), [SCPhotoConfiguration](Library/Sources/SCPhotoConfiguration.h)),  that you can access just like this:
```objective-c

// Get the video configuration object
SCVideoConfiguration *video = recorder.videoConfiguration;

// Whether the video should be enabled or not
video.enabled = YES;
// The bitrate of the video video
video.bitrate = 2000000; // 2Mbit/s
// Size of the video output
video.size = CGSizeMake(1280, 720);
// Scaling if the output aspect ratio is different than the output one
video.scalingMode = AVVideoScalingModeResizeAspectFill;
// The timescale ratio to use. Higher than 1 makes the time go slower, between 0 and 1 makes the time go faster
video.timeScale = 1;
// Whether the output video size should be infered so it creates a square video
video.sizeAsSquare = NO;
// The filter to apply to each output video buffer (this do not affect the presentation layer)
video.filterGroup = [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectInstant"]];

// Get the audio configuration object
SCAudioConfiguration *audio = recorder.audioConfiguration;

// Whether the audio should be enabled or not
audio.enabled = YES;
// the bitrate of the audio output
audio.bitrate = 128000; // 128kbit/s
// Number of audio output channels
audio.channelsCount = 1; // Mono output
// The sample rate of the audio output
audio.sampleRate = 0; // Use same input 
// The format of the audio output
audio.format = kAudioFormatMPEG4AAC; // AAC

// Get the photo configuration object
SCPhotoConfiguration *photo = recorder.photoConfiguration;
photo.enabled = NO;
```

You can configure the input device settings (framerate of the video, whether the flash should be enabled etc...) directly on the SCRecorder.
```objective-c

recorder.sessionPreset = AVCaptureSessionPresetHigh;
recorder.device = AVCaptureDevicePositionFront;

```
	
Begin the recording
--------------------

The second class we are gonna see is [SCRecordSession](Library/Sources/SCRecordSession.h), which is the class that process the inputs and append them into an output file. A record session can contain multiple record segments. A record segment is just a continuous video and/or audio file, represented as a NSURL. It starts when you hold the record button and end when you release it, if you implemented the record button the same way as instagram and vine did. A call of [SCRecorder record] starts a new record segment if needed.

```objective-c
// Creating the recordSession
SCRecordSession *recordSession = [SCRecordSession recordSession];

recorder.recordSession = recordSession;
	
[recorder record];
```	

Finishing the record and editing
---------------------

When you are done recording, you need to pause the SCRecorder. Each call of -[SCRecorder pause] causes the current record segment to be completed and appended as a NSURL that is available through the -[SCRecordSession recordSegments] array. You can then read the record segments using -[SCRecordSession assetRepresentingRecordSegments]. You can also read each individual file by using one of the NSURL entry inside the recordSegments array.

```objective-c
// When done with the current record segment
[recorder pause:^{ 
	SCRecordSession *recordSession = recorder.recordSession;

	// Removing segments
	[recordSession removeSegmentAtIndex:0 deleteFile:YES]; // Remove first segment
	[recordSession removeLastSegment]; // Remove lastsegment

	// Read the record segment
	SCPlayer *player = ...; // Get instance of SCPlayer
	[player setItemByAsset:recordSession.assetRepresentingRecordSegments];
	[player play];
	
	// Play the video with a black and white filter
	SCImageView *SCImageView = ...; // Get instance of SCImageView
	player.CIImageRenderer = SCImageView;
	SCImageView.filterGroup = [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectNoir"]];
}];
```

Merging all the record segments into one file
---------------------

Once you are done editing your record session, you can merge the record segments into one file that you can upload to your server and store locally. You can either go the easy way with few customization using -[SCRecordSession mergeRecordSegmentsUsingPreset: completionHandler:], or you can use the asset returned by -[SCRecordSession assetRepresentingRecordSegments] and export yourself using the native AVAssetExportSession, the more customizable with filter support SCAssetExportSession, or an exporter that you implemented yourself.

```objective-c

SCRecordSession *recordSession = ...;

// Easy way
recordSession mergeRecordSegmentsUsingPreset:AVAssetExportSessionPresetHighest completionHandler:^(NSURL *outputUrl, NSError *error) {
	if (error == nil) {
		// File recorded to outputUrl
	}
}];

// With more customization
AVAsset *asset = [recordSession assetRepresentingRecordSegments];

SCAssetExportSession assetExportSession = [[SCAssetExportSession alloc] initWithAsset:asset];
assetExportSession.outputUrl = recordSession.outputUrl;
assetExportSession.outputFileType = AVFileTypeMPEG4;
assetExportSession.videoConfiguration.filterGroup = [SCFilterGroup filterGroupWithFilter:[SCFilter filterWithName:@"CIPhotoEffectInstant"]];
assetExportSession.videoConfiguration.preset = SCPresetHighestQuality;
assetExportSession.keepVideoSize = YES;
[assetExportSession exportAsynchronouslyWithCompletionHandler: ^{
	if (assetExportSession.error == nil) {
		// We have our video and/or audio file
	} else {
		// Something bad happened
	}
}];

```

Creating/manipulating filters
---------------------

SCRecorder comes with a filter API built on top of Core Image. [SCFilter](Library/Sources/SCFilter.h) is the class that wraps a CIFilter. It can have a delegate to know when a filter parameter has changed and is compliant to NSCoding. Even though CIFilter is also NSCoding compliant, SCFilter was needed because it fixed some incompatibility issue while trying to deserialise a CIFilter on iOS that was serialised on OS X. [SCFilterGroup](Library/Sources/SCFilterGroup.h) is a class that contains a list of SCFilter. SCFilterGroup can be saved directly into a file and restored from this file.

```objective-c

// Manually creating a filter chain
SCFilter *blackAndWhite = [SCFilter filterWithName:@"CIColorControls"];
[blackAndWhite setParameterValue:@0 forKey:@"inputSaturation"];

SCFilter *exposure = [SCFilter filterWithName:@"CIExposureAdjust"];
[exposure setParameterValue:@0.7 forKey:@"inputEV"];

SCFilterGroup *filterGroup = [SCFilterGroup filterGroupWithFilters:@[blackAndWhite, exposure]];

// Saving to a file
NSError *error = nil;
[filterGroup writeToFile:[NSURL fileUrlWithPath:@"some-url.cisf"] error:&error];
if (error == nil) {

}

// Restoring the filter group
SCFilterGroup *restoredFilterGroup = [SCFilterGroup filterGroupWithContentsOfUrl:[NSURL fileUrlWithPath:@"some-url.cisf"]];
```

If you want to create your own filters easily, you can also check out [CoreImageShop](https://github.com/rFlex/CoreImageShop) which is a Mac application that will generate serialized SCFilterGroup directly useable by the filter classes in this project.

Using the filters
---------------------

SCFilterGroup can be either used in a view to render a filtered image in real time, or in a processing object to render the filter to a file. You can use an SCFilterGroup in one of the following classes:

- [SCVideoConfiguration](Library/Sources/SCVideoConfiguration.h) (processing)
- [SCImageView](Library/Sources/SCImageView.h) (live rendering)
- [SCSwipeableFilterView](Library/Sources/SCSwipeableFilterView.h) (live rendering)


Some details about the other provided classes
---------------------

#### [SCRecorderFocusView](Library/Sources/SCRecorderFocusView.h)

Simple view that can have an SCRecorder instance. It will handle the tap to focus. SCRecorder delegate can call -[SCRecorderFocusView showFocusAnimation] and -[SCRecorder hideFocusAnimation] to show and hide the animation when needed.

#### [CIImageRenderer](Library/Sources/CIImageRenderer.h) (protocol)

Every class that conforms to this protocol can render a CIImage.

#### [SCImageView<CIImageRenderer>](Library/Sources/SCImageView.h)

A simple CIImageRenderer view that can have a SCFilterGroup. It renders the input CIImage using the SCFilterGroup, if there is any.

#### [SCSwipeableFilterView<CIImageRenderer>](Library/Sources/SCSwipeableFilterView.h)

A CIImageRenderer view that has a scroll and a list of SCFilterGroup. It let the user scrolls between the filters so he can chose one. The selected filter can be retrieved using -[SCSwipeableFilterView selectedFilterGroup]. This basically works the same as the Snapchat composition page.

#### [SCAssetExportSession](Library/Sources/SCAssetExportSession.h)

Exporter that has basically the same API as the Apple AVAssetExportSession but adds more control on the output quality. Output configuration works like the SCRecorder, with a SCVideoConfiguration and SCAudioConfiguration instance to configure the relevant output.

#### [SCPlayer](Library/Sources/SCPlayer.h)

Player based on the Apple AVPlayer. It adds some convenience methods and the possibility to have a CIImageRenderer that will be used to render the video image buffers. You can combine this class with a CIImageRenderer to render a live filter on a video.

#### [SCVideoPlayerView](Library/Sources/SCVideoPlayerView.h)

A view that render an SCPlayer easily. It supports tap to play/pause. By default, it holds an SCPlayer instance itself and share the same lifecycle as this SCPlayer. You can disable this feature by calling +[SCVideoPlayerView setAutoCreatePlayerWhenNeeded:NO].
