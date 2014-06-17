//
// File : ApiDefinition.cs
//
// Author: Simon CORSIN <simoncorsin@gmail.com>
//
// Copyright (c) 2012 Ever SAS
//
// Using or modifying this source code is strictly reserved to Ever SAS.

using System;
using System.Drawing;

using MonoTouch.ObjCRuntime;
using MonoTouch.Foundation;
using MonoTouch.UIKit;
using MonoTouch.AVFoundation;
using MonoTouch.CoreGraphics;
using MonoTouch.CoreMedia;
using MonoTouch.CoreImage;
using MonoTouch.GLKit;

namespace SCorsin {

	public delegate void EndRecordSegmentDelegate(int segmentIndex, NSError errore);
	public delegate void GenericErrorDelegate(NSError error);

	[BaseType(typeof(NSObject))]
	interface SCRecordSession {

		[Export("initWithDictionaryRepresentation:")]
		IntPtr Constructor(NSDictionary dictionaryRepresentation);

		[Export("outputUrl"), NullAllowed]
		NSUrl OutputUrl { get; set; }

		[Export("fileType"), NullAllowed]
		NSString FileType { get; set; }

		[Export("shouldTrackRecordSegments")]
		bool ShouldTrackRecordSegments { get; set; }

		[Export("recordSegments")]
		NSUrl[] RecordSegments { get; }

		[Export("currentRecordDuration")]
		CMTime CurrentRecordDuration { get; }

		[Export("suggestedMaxRecordDuration")]
		CMTime SuggestedMaxRecordDuration { get; set; }

		[Export("ratioRecorded")]
		float RatioRecorded { get; }

		[Export("videoOutputSettings"), NullAllowed]
		NSDictionary VideoOutputSettings { get; set; }

		[Export("audioOutputSettings"), NullAllowed]
		NSDictionary AudioOutputSettings { get; set; }

		[Export("recordSegmentsMergePreset"), NullAllowed]
		NSString RecordSegmentsMergePreset { get; set; }

		[Export("recordSegmentBegan")]
		bool RecordSegmentBegan { get; }

		[Export("videoSize")]
		SizeF VideoSize { get; set; }

		[Export("videoAffineTransform")]
		CGAffineTransform VideoAffineTransform { get; set; }

		[Export("videoBitsPerPixel")]
		float VideoBitsPerPixel { get; set; }

		[Export("videoCodec"), NullAllowed]
		NSString VideoCodec { get; set; }

		[Export("videoScalingMode"), NullAllowed]
		NSString VideoScalingMode { get; set; }

		[Export("shouldIgnoreVideo")]
		bool ShouldIgnoreVideo { get; set; }

		[Export("videoMaxFrameRate")]
		int VideoMaxFrameRate { get; set; }

		[Export("videoTimeScale")]
		float VideoTimeScale { get; set; }

		[Export("audioSampleRate")]
		float AudioSampleRate { get; set; }

		[Export("audioChannels")]
		int AudioChannels { get; set; }

		[Export("audioBitRate")]
		int AudioBitRate { get; set; }

		[Export("audioEncodeType")]
		int AudioEncodeType { get; set; }

		[Export("shouldIgnoreAudio")]
		bool ShouldIgnoreAudio { get; set; }

		[Export("saveToCameraRoll")]
		void SaveToCameraRoll();

		[Export("beginRecordSegment:")]
		void beginRecordSegment(out NSError error);

		[Export("endRecordSegment:")]
		void EndRecordSegment([NullAllowed] EndRecordSegmentDelegate completionHandler);

		[Export("removeSegmentAtIndex:deleteFile:")]
		void RemoveSegmentAtIndex(int segmentIndex, bool deleteFile);

		[Export("addSegment:")]
		void AddSegment(NSUrl fileUrl);

		[Export("insertSegment:atIndex:")]
		void InsertSegment(NSUrl fileUrl, int segmentIndex);

		[Export("removeAllSegments")]
		void RemoveAllSegments();

		[Export("mergeRecordSegments:")]
		void MergeRecordSegments([NullAllowed] GenericErrorDelegate completionHandler);

		[Export("endSession:")]
		void EndSession([NullAllowed] GenericErrorDelegate completionHandler);

		[Export("cancelSession:")]
		void CancelSession([NullAllowed] Action completionHandler);

		[Export("assetRepresentingRecordSegments")]
		AVAsset AssetRepresentingRecordSegments { get; }

		[Export("videoShouldKeepOnlyKeyFrames")]
		bool VideoShouldKeepOnlyKeyFrames { get; set; }

		[Export("videoSizeAsSquare")]
		bool VideoSizeAsSquare { get; set; }

		[Export("dictionaryRepresentation")]
		NSDictionary DictionaryRepresentation { get; }
	}

	[Model, BaseType(typeof(NSObject)), Protocol]
	interface SCRecorderDelegate {

		[Abstract, Export("recorder:didReconfigureInputs:audioInputError:"), EventArgs("RecorderDidReconfigureInputsDelegate")]
		void DidReconfigureInputs(SCRecorder recorder, NSError videoInputError, NSError audioInputError);

		[Export("recorder:didChangeFlashMode:error:"), Abstract, EventArgs("RecorderDidChangeFlashModeDelegate")]
		void DidChangeFlashMode(SCRecorder recorder, int flashMode, NSError error);

		[Export("recorder:didChangeSessionPreset:error:"), Abstract, EventArgs("RecorderDidChangeSessionPresetDelegate")]
		void DidChangeSessionPreset(SCRecorder recorder, string sessionPreset, NSError error);

		[Export("recorderWillStartFocus:"), Abstract, EventArgs("RecorderWillStartFocusDelegate")]
		void WillStartFocus(SCRecorder recorder);

		[Export("recorderDidStartFocus:"), Abstract, EventArgs("RecorderDidStartFocusDelegate")]
		void DidStartFocus(SCRecorder recorder);

		[Export("recorderDidEndFocus:"), Abstract, EventArgs("RecorderDidEndFocusDelegate")]
		void DidEndFocus(SCRecorder recorder);

		[Export("recorder:didInitializeAudioInRecordSession:error:"), Abstract, EventArgs("RecorderDidInitializeAudioInRecordSessionDelegate")]
		void DidInitializeAudioInRecordSession(SCRecorder recorder, SCRecordSession recordSession, NSError error);

		[Export("recorder:didInitializeVideoInRecordSession:error:"), Abstract, EventArgs("RecorderDidInitializeVideoInRecordSessionDelegate")]
		void DidInitializeVideoInRecordSession(SCRecorder recorder, SCRecordSession recordSession, NSError error);

		[Export("recorder:didBeginRecordSegment:error:"), Abstract, EventArgs("RecorderDidBeginRecordSegmentDelegate")]
		void DidBeginRecordSegment(SCRecorder recorder, SCRecordSession recordSession, NSError error);

		[Export("recorder:didEndRecordSegment:segmentIndex:error:"), Abstract, EventArgs("RecorderDidEndRecordSegmentDelegate")]
		void DidEndRecordSegment(SCRecorder recorder, SCRecordSession recordSession, int segmentIndex, NSError error);

		[Export("recorder:didAppendVideoSampleBuffer:"), Abstract, EventArgs("RecorderDidAppendVideoSampleBufferDelegate")]
		void DidAppendVideoSampleBuffer(SCRecorder recorder, SCRecordSession recordSession);

		[Export("recorder:didAppendAudioSampleBuffer:"), Abstract, EventArgs("RecorderDidAppendAudioSampleBufferDelegate")]
		void DidAppendAudioSampleBuffer(SCRecorder recorder, SCRecordSession recordSession);

		[Export("recorder:didSkipAudioSampleBuffer:"), Abstract, EventArgs("RecorderDidSkip")]
		void DidSkipAudioSampleBuffer(SCRecorder recorder, SCRecordSession recordSession);

		[Export("recorder:didSkipVideoSampleBuffer:"), Abstract, EventArgs("RecorderDidSkip")]
		void DidSkipVideoSampleBuffer(SCRecorder recorder, SCRecordSession recordSession);

		[Export("recorder:didCompleteRecordSession:"), Abstract, EventArgs("RecorderDidCompleteRecordSessionDelegate")]
		void DidCompleteRecordSession(SCRecorder recorder, SCRecordSession recordSession);

	}

	public delegate void OpenSessionDelegate(NSError sessionError, NSError audioError, NSError videoError, NSError photoError);
	public delegate void CapturePhotoDelegate(NSError error, UIImage image);

	[BaseType(typeof(NSObject), Delegates = new string [] { "Delegate" }, Events = new Type [] { typeof(SCRecorderDelegate) })]
	interface SCRecorder {

		[Export("delegate")]
		NSObject WeakDelegate { get; set; }

		[Wrap("WeakDelegate")]
		SCRecorderDelegate Delegate { get; set; }

		[Export("audioEnabled")]
		bool AudioEnabled { get; set; }

		[Export("videoEnabled")]
		bool VideoEnabled { get; set; }

		[Export("photoEnabled")]
		bool PhotoEnabled { get; set; }

		[Export("isRecording")]
		bool IsRecording { get; }

		[Export("flashMode")]
		int FlashMode { get; set; }

		[Export("device")]
		AVCaptureDevicePosition Device { get; set; }

		[Export("focusMode")]
		AVCaptureFocusMode FocusMode { get; }

		[Export("photoOutputSettings"), NullAllowed]
		NSDictionary PhotoOutputSettings { get; set; }

		[Export("sessionPreset")]
		NSString SessionPreset { get; set; }

		[Export("captureSession")]
		AVCaptureSession CaptureSession { get; }

		[Export("isCaptureSessionOpened")]
		bool IsCaptureSessionOpened { get; }

		[Export("previewLayer")]
		AVCaptureVideoPreviewLayer PreviewLayer { get; }

		[Export("previewView"), NullAllowed]
		UIView PreviewView { get; set; }

		[Export("recordSession"), NullAllowed]
		SCRecordSession RecordSession { get; set; }

		[Export("videoOrientation")]
		AVCaptureVideoOrientation VideoOrientation { get; set; }

		[Export("frameRate")]
		int FrameRate { get; set; }

		[Export("focusSupported")]
		bool FocusSupported { get; }

		[Export("openSession:")]
		void OpenSession([NullAllowed] OpenSessionDelegate completionHandler);

		[Export("closeSession")]
		void CloseSession();

		[Export("startRunningSession")]
		void StartRunningSession();

		[Export("endRunningSession")]
		void EndRunningSession();

		[Export("beginSessionConfiguration")]
		void BeginSessionConfiguration();

		[Export("endSessionConfiguration")]
		void EndSessionConfiguration();

		[Export("switchCaptureDevices")]
		void SwitchCaptureDevices();

		[Export("convertToPointOfInterestFromViewCoordinates:")]
		PointF ConvertToPointOfInterestFromViewCoordinates(PointF viewCoordinates);

		[Export("autoFocusAtPoint:")]
		void AutoFocusAtPoint(PointF point);

		[Export("continuousFocusAtPoint:")]
		void ContinuousFocusAtPoint(PointF point);

		[Export("setActiveFormatThatSupportsFrameRate:width:andHeight:error:")]
		bool SetActiveFormatThatSupportsFrameRate(int frameRate, int width, int height, out NSError error);

		[Export("record")]
		void Record();

		[Export("pause")]
		void Pause();

		[Export("pause:")]
		void Pause(Action completionHandler);

		[Export("capturePhoto:")]
		void CapturePhoto([NullAllowed] CapturePhotoDelegate completionHandler);
	}

	delegate void CompletionHandler(NSError error);

    [BaseType(typeof(NSObject))]
    interface SCAudioTools {

        [Static]
        [Export("overrideCategoryMixWithOthers")]
        void OverrideCategoryMixWithOthers();

		[Static]
		[Export("mixAudio:startTime:withVideo:affineTransform:toUrl:outputFileType:withMaxDuration:withCompletionBlock:")]
		void MixAudioWithVideo(AVAsset audioAsset, CMTime audioStartTime, NSUrl inputUrl, CGAffineTransform affineTransform, NSUrl outputUrl, NSString outputFileType, CMTime maxDuration, CompletionHandler completionHandler);

    }

	[BaseType(typeof(NSObject))]
	interface SCFilter {

		[Export("initWithCIFilter:")]
		IntPtr Constructor(CIFilter filter);

		[Export("coreImageFilter")]
		CIFilter CoreImageFilter { get; }
	}

	[BaseType(typeof(NSObject))]
	interface SCFilterGroup {

		[Export("initWithFilter:")]
		IntPtr Constructor(SCFilter filter);

		[Export("addFilter:")]
		void AddFilter(SCFilter filter);

		[Export("removeFilter:")]
		void RemoveFilter(SCFilter filter);

		[Export("imageByProcessingImage:")]
		CIImage ImageByProcessingImage(CIImage image);

		[Export("filters")]
		SCFilter[] Filters { get; }

		[Export("name")]
		string Name { get; set; }

		[Export("filterGroupWithData:"), Static]
		SCFilterGroup FromData(NSData data);

		[Export("filterGroupWithData:error:"), Static]
		SCFilterGroup FromData(NSData data, out NSError error);

		[Export("filterGroupWithContentsOfUrl:"), Static]
		SCFilterGroup FromUrl(NSUrl url);
	}

	[BaseType(typeof(NSObject))]
	[Model, Protocol]
	interface SCPlayerDelegate {
		[Abstract]	
		[Export("videoPlayer:didPlay:loopsCount:"), EventArgs("PlayerDidPlay")]
		void DidPlay(SCPlayer player, double secondsElapsed, int loopCount);

		[Abstract]
		[Export("videoPlayer:didStartLoadingAtItemTime:"), EventArgs("PlayerLoading")]
		void DidStartLoading(SCPlayer player, CMTime itemItem);

		[Abstract]
		[Export("videoPlayer:didEndLoadingAtItemTime:"), EventArgs("PlayerLoading")]
		void DidEndLoading(SCPlayer player, CMTime itemItem);

		[Abstract]
		[Export("videoPlayer:didChangeItem:"), EventArgs("PlayerChangedItem")]
        void DidChangeItem(SCPlayer player, [NullAllowed] AVPlayerItem item);

	}

	[BaseType(typeof(AVPlayer), Delegates = new string [] { "Delegate" }, Events = new Type [] { typeof(SCPlayerDelegate) })]
	interface SCPlayer {

		[Export("delegate")]
		NSObject WeakDelegate { get; set; }

		[Wrap("WeakDelegate")]
		SCPlayerDelegate Delegate { get; set; }

		[Static]
		[Export("pauseCurrentPlayer")]
		void PauseCurrentPlayer();

		[Static]
		[Export("currentPlayer")]
		SCPlayer CurrentPlayer { get; }

		[Export("filterGroup"), NullAllowed]
		SCFilterGroup FilterGroup { get; set; }

		[Export("setItemByStringPath:")]
        void SetItem([NullAllowed] string stringPath);

		[Export("setItemByUrl:")]
        void SetItem([NullAllowed] NSUrl url);

		[Export("setItemByAsset:")]
        void SetItem([NullAllowed] AVAsset asset);

		[Export("setItem:")]
        void SetItem([NullAllowed] AVPlayerItem item);

        [Export("setSmoothLoopItemByStringPath:smoothLoopCount:")]
        void SetSmoothLoopItem(string stringPath, uint loopCount);

        [Export("setSmoothLoopItemByUrl:smoothLoopCount:")]
        void SetSmoothLoopItem(NSUrl assetUrl, uint loopCount);

        [Export("setSmoothLoopItemByAsset:smoothLoopCount:")]
        void SetSmoothLoopItem(AVAsset asset, uint loopCount);

		[Export("playableDuration")]
		CMTime PlayableDuration { get; }

		[Export("isPlaying")]
		bool IsPlaying { get; }

		[Export("isLoading")]
		bool IsLoading { get; }

		[Export("minimumBufferedTimeBeforePlaying")]
		CMTime MinimumBufferedTimeBeforePlaying { get; set; }

		[Export("shouldLoop")]
		bool ShouldLoop { get; set; }

		[Export("shouldPlayConcurrently")]
		bool ShouldPlayConcurrently { get; set; }

		[Export("beginSendingPlayMessages")]
		void BeginSendingPlayMessages();

		[Export("endSendingPlayMessages")]
		void EndSendingPlayMessages();

		[Export("isSendingPlayMessages")]
		bool IsSendingPlayMessages { get; }
	
		[Export("imageView")]
		SCImageView ImageView { get; }

		[Export("outputView"), NullAllowed]
		UIView OutputView { get; set; }

		[Export("useCoreImageView")]
		bool UseCoreImageView { get; set; }
	}

	[BaseType(typeof(UIView))]
	interface SCVideoPlayerView : SCPlayerDelegate {

		[Export("player")]
		SCPlayer Player { get; }

		[Export("playerLayer")]
		AVPlayerLayer PlayerLayer { get; }

		[Export("loadingView"), NullAllowed]
		UIView LoadingView { get; set; }

	}

	[BaseType(typeof(UIView))]
	interface SCRecorderFocusView {

		[Export("recorder")]
		SCRecorder Recorder { get; set; }

		[Export("outsideFocusTargetImage")]
		UIImage OutsideFocusTargetImage { get; set; }

		[Export("insideFocusTargetImage")]
		UIImage InsideFocusTargetImage { get; set; }

		[Export("focusTargetSize")]
		SizeF FocusTargetSize { get; set; }

		[Export("showFocusAnimation")]
		void ShowFocusAnimation();

		[Export("hideFocusAnimation")]
		void HideFocusAnimation();

	}

	[BaseType(typeof(NSObject))]
	interface SCAssetExportSession {

		[Export("inputAsset")]
		AVAsset InputAsset { get; set; }

		[Export("outputUrl")]
		NSUrl OutputUrl { get; set; }

		[Export("outputFileType")]
		NSString OutputFileType { get; set; }

		[Export("videoSettings")]
		NSDictionary VideoSettings { get; set; }

		[Export("audioSettings")]
		NSDictionary AudioSettings { get; set; }

		[Export("error")]
		NSError Error { get; }

		[Export("reverseVideo")]
		bool ReverseVideo { get; set; }

		[Export("initWithAsset:")]
		IntPtr Constructor(AVAsset inputAsset);

		[Export("exportAsynchronouslyWithCompletionHandler:")]
		void ExportAsynchronously(Action completionHandler);

		[Export("filterGroup"), NullAllowed]
		SCFilterGroup FilterGroup { get; set; }

		[Export("useGPUForRenderingFilters")]
		bool UseGPUForRenderingFilters { get; set; }

	}

	[BaseType(typeof(UIView))]
	interface SCFilterSwitcherView {

		[Export("filterGroups"), NullAllowed]
		SCFilterGroup[] FilterGroups { get; set; }

		[Export("player"), NullAllowed]
		SCPlayer Player { get; set; }

		[Export("selectedFilterGroup")]
		SCFilterGroup SelectedFilterGroup { get; }

		[Export("selectFilterScrollView")]
		UIScrollView SelectFilterScrollView { get; }

		[Export("disabled")]
		bool Disabled { get; set; }
	}

	[BaseType(typeof(GLKView))]
	interface SCImageView {

		[Export("image")]
		CIImage Image { get; set; }

	}
}
