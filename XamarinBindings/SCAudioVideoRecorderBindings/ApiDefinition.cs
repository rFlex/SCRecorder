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

namespace SCorsin {

	[BaseType(typeof(NSObject))]
	interface SCDataEncoder {

		[Export("enabled")]
		bool Enabled { get; set; }

	}

	[BaseType(typeof(SCDataEncoder))]
    interface SCVideoEncoder {

		[Export("outputVideoSize")]
		SizeF OutputVideoSize { get; set; }

		[Export("outputBitsPerPixel")]
		float OutputBitsPerPixel { get; set; }

	}

	[BaseType(typeof(SCDataEncoder))]
    interface SCAudioEncoder {

		[Export("outputSampleRate")]
		double OutputSampleRate { get; set; }

		[Export("outputChannels")]
		int OutputChannels { get; set; }

		[Export("outputBitRate")]
		int OutputBitRate { get; set; }

		[Export("outputEncodeType")]
		int OutputEncodeType { get; set; }

	}

	[BaseType(typeof(NSObject))]
	[Model]
    interface SCAudioVideoRecorderDelegate {
		[Abstract]
		[Export("audioVideoRecorder:didRecordVideoFrame:"), EventArgs("AudioVideoRecorderSecond")]
		void DidRecordVideoFrame(SCAudioVideoRecorder audioVideoRecorder, CMTime frameTime);

		[Abstract]
		[Export("audioVideoRecorder:didRecordAudioSample:"), EventArgs("AudioVideoRecorderSecond")]
		void DidRecordAudioSample(SCAudioVideoRecorder audioVideoRecorder, CMTime sampleTime);

		[Abstract]
		[Export("audioVideoRecorder:willFinishRecordingAtTime:"), EventArgs("AudioVideoRecorderRecordWillFinish")]
		void WillFinishRecording(SCAudioVideoRecorder audioVideoRecorder, CMTime recordedTime);

		[Abstract]
		[Export("audioVideoRecorder:didFinishRecordingAtUrl:error:"), EventArgs("AudioVideoRecorderRecordFinished")]
		void DidFinishRecording(SCAudioVideoRecorder audioVideoRecorder, NSUrl recordedFile, NSError error);

		[Abstract]
		[Export("audioVideoRecorder:didFailToInitializeVideoEncoder:"), EventArgs("AudioVideoRecorderInitializeFailed")]
		void DidFailInitializeVideoEncoder(SCAudioVideoRecorder audioVideoRecorder, NSError error);

		[Abstract]
		[Export("audioVideoRecorder:didFailToInitializeAudioEncoder:"), EventArgs("AudioVideoRecorderInitializeFailed")]
		void DidFailInitializeAudioEncoder(SCAudioVideoRecorder audioVideoRecorder, NSError error);

		[Abstract]
		[Export("audioVideoRecorder:capturedPhoto:error:"), EventArgs("AudioVideoRecorderTookPhoto")]
		void DidCapturePhoto(SCAudioVideoRecorder audioVideoRecorder, NSDictionary photoDict, NSError error);

		[Abstract]
		[Export("cameraWillStartFocus:")]
		void WillStartFocus(SCCamera camera);

		[Abstract]
		[Export("cameraDidStartFocus:")]
		void DidStartFocus(SCCamera camera);

		[Abstract]
		[Export("cameraDidStopFocus:")]
		void DidStopFocus(SCCamera camera);

		[Abstract]
		[Export("camera:didFailFocus:"), EventArgs("CameraFailedFocus")]
		void DidFailFocus(SCCamera camera, NSError error);
	}

    [Model, BaseType (typeof (NSObject))]
    interface SCDataEncoderDelegate {
        
        [Export ("dataEncoder:didEncodeFrame:")]
        void DidEncodeFrame (SCDataEncoder dataEncoder, CMTime frameTime);
        
        [Export ("dataEncoder:didFailToInitializeEncoder:")]
        void DidFailToInitializeEncoder (SCDataEncoder dataEncoder, NSError error);
    }

    [BaseType(typeof(SCDataEncoderDelegate), Delegates = new string [] { "Delegate" }, Events = new Type [] { typeof(SCAudioVideoRecorderDelegate) })]
    interface SCAudioVideoRecorder {

		[Export("delegate")]
		NSObject WeakDelegate { get; set; }

		[Wrap("WeakDelegate")]
		SCAudioVideoRecorderDelegate Delegate { get; set; }

		[Export("prepareRecordingAtCameraRoll:")]
		void PrepareRecordingAtCameraRoll(out NSError error);

		[Export("prepareRecordingOnTempDir:")]
		NSUrl PrepareRecordingOnTempDir(out NSError error);

		[Export("prepareRecordingAtUrl:error:")]
		void PrepareRecordingAtUrl(NSUrl url, out NSError error);

		[Export("record")]
		void Record();

		[Export("pause")]
		void Pause();

		[Export("cancel")]
		void Cancel();

		[Export("stop")]
		void Stop();

		[Export("isPrepared")]
		bool IsPrepared { get; }

		[Export("isRecording")]
		bool IsRecording { get; }

        [Export("enableSound")]
        bool EnableSound { get; set; }
        
        [Export("enableVideo")]
        bool EnableVideo { get; set; }

		[Export("playPlaybackAssetWhenRecording")]
		bool PlayPlaybackAssetWhenRecording { get; set; }

        [Export("playbackAsset")]
        AVAsset PlaybackAsset { get; set; }

		[Export("videoOutput")]
		AVCaptureVideoDataOutput VideoOutput { get; }

		[Export("audioOutput")]
		AVCaptureAudioDataOutput AudioOutput { get; }

		[Export("videoEncoder")]
		SCVideoEncoder VideoEncoder { get; }

		[Export("audioEncoder")]
		SCAudioEncoder AudioEncoder { get; }

		[Export("outputFileUrl")]
		NSUrl OutputFileUrl { get; }

        [Export("outputFileType")]
		NSString OutputFileType { get; set; }

		[Export("recordingDurationLimit")]
		CMTime RecordingDurationLimit { get; set; }	

		[Export("playbackStartTime")]
		CMTime PlaybackStartTime { get; set; }

		[Export("recordingRate")]
		float RecordingRate { get; set; }
    }

    delegate void InitializerDelegate(NSError audioError, NSError videoError);

//    enum VideoGravity {
//        Resize,
//        ResizeAspectFill,
//        ResizeAspect
//    };
   
    [BaseType(typeof(SCAudioVideoRecorder))]
    interface SCCamera {

        [Export("initWithSessionPreset:")]
        IntPtr Constructor(string sessionPresset);

        [Export("initialize:")]
        void Initialize([NullAllowed] InitializerDelegate initializerDelegate);

        [Export("isReady")]
        bool IsReady { get; }

        [Export("previewVideoGravity")]
        int PreviewVideoGravity { get; set; }

        [Export("sessionPreset")]
        string SessionPreset { get; set; }

        [Export("previewView"), NullAllowed]
        UIView PreviewView { get; set; }

		[Export("startRunningSession")]
		void StartRunningSession();

		[Export("stopRunningSession")]
		void StopRunningSession();

		[Export("setActiveFormatThatSupportsFrameRate:width:andHeight:error:")]
		bool SetActiveFormatThatSupportsFrameRate(int frameRate, int width, int height, out NSError error);

		[Export("flashMode")]
		AVCaptureFlashMode FlashMode { get; set; }

		[Export("convertToPointOfInterestFromViewCoordinates:")]
		PointF ConvertToPointOfInterestFromViewCoordinates(PointF point);

		[Export("autoFocusAtPoint:")]
		void AutoFocusAtPoint(PointF point);

		[Export("continuousFocusAtPoint:")]
		void ContinuousFocusAtPoint(PointF point);

		[Export("isFocusSupported")]
		bool IsFocusSupported { get; }

        [Export("session")]
        AVCaptureSession Session { get; }

        [Export("videoOrientation")]
        int VideoOrientation { get; set; }

        [Export("switchCamera")]
        void SwitchCamera();

		[Export("cameraDevice")]
		AVCaptureDevicePosition CameraDevice { get; set; }

		[Export("isFrameRateSupported:")]
		bool IsFrameRateSupported(int frameRate);

		[Export("frameRate")]
		int FrameRate { get; set; }

		[Export("currentDevice")]
		AVCaptureDevice CurrentDevice { get; }
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
	[Model]
	interface SCPlayerDelegate {
		[Abstract]	
		[Export("videoPlayer:didPlay:"), EventArgs("PlayerDidPlay")]
		void DidPlay(SCPlayer player, double secondsElapsed);

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

		[Export("dispose")]
		void Close();

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

		[Export("cleanUp")]
		void CleanUp();
	
	}

	[BaseType(typeof(UIView))]
	interface SCVideoPlayerView : SCPlayerDelegate {

		[Export("player")]
		SCPlayer Player { get; }

		[Export("playerLayer")]
		AVPlayerLayer PlayerLayer { get; }

		[Export("loadingView")]
		UIView LoadingView { get; set; }

	}

	[BaseType(typeof(UIView))]
	interface SCCameraFocusView {

		[Export("camera")]
		SCCamera Camera { get; set; }

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
}
