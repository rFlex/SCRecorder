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
    // The first step to creating a binding is to add your native library ("libNativeLibrary.a")
    // to the project by right-clicking (or Control-clicking) the folder containing this source
    // file and clicking "Add files..." and then simply select the native library (or libraries)
    // that you want to bind.
    //
    // When you do that, you'll notice that MonoDevelop generates a code-behind file for each
    // native library which will contain a [LinkWith] attribute. MonoDevelop auto-detects the
    // architectures that the native library supports and fills in that information for you,
    // however, it cannot auto-detect any Frameworks or other system libraries that the
    // native library may depend on, so you'll need to fill in that information yourself.
    //
    // Once you've done that, you're ready to move on to binding the API...
    //
    //
    // Here is where you'd define your API definition for the native Objective-C library.
    //
    // For example, to bind the following Objective-C class:
    //
    //     @interface Widget : NSObject {
    //     }
    //
    // The C# binding would look like this:
    //
    //     [BaseType (typeof (NSObject))]
    //     interface Widget {
    //     }
    //
    // To bind Objective-C properties, such as:
    //
    //     @property (nonatomic, readwrite, assign) CGPoint center;
    //
    // You would add a property definition in the C# interface like so:
    //
    //     [Export ("center")]
    //     PointF Center { get; set; }
    //
    // To bind an Objective-C method, such as:
    //
    //     -(void) doSomething:(NSObject *)object atIndex:(NSInteger)index;
    //
    // You would add a method definition to the C# interface like so:
    //
    //     [Export ("doSomething:atIndex:")]
    //     void DoSomething (NSObject object, int index);
    //
    // Objective-C "constructors" such as:
    //
    //     -(id)initWithElmo:(ElmoMuppet *)elmo;
    //
    // Can be bound as:
    //
    //     [Export ("initWithElmo:")]
    //     IntPtr Constructor (ElmoMuppet elmo);
    //
    // For more information, see http://docs.xamarin.com/ios/advanced_topics/binding_objective-c_types
    //

	[BaseType(typeof(NSObject))]
	interface SCDataEncoder {

		[Export("useInputFormatTypeAsOutputType")]
		bool UseInputFormatTypeAsOutputType { get; set; }

		[Export("enabled")]
		bool Enabled { get; set; }

	}

	[BaseType(typeof(SCDataEncoder))]
    interface SCVideoEncoder {

		[Export("outputVideoSize")]
		SizeF OutputVideoSize { get; set; }

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
		void DidRecordVideoFrame(SCAudioVideoRecorder audioVideoRecorder, double frameSecond);

		[Abstract]
		[Export("audioVideoRecorder:didRecordAudioSample:"), EventArgs("AudioVideoRecorderSecond")]
		void DidRecordAudioSample(SCAudioVideoRecorder audioVideoRecorder, double sampleSecond);

		[Abstract]
		[Export("audioVideoRecorder:didFinishRecordingAtUrl:error:"), EventArgs("AudioVideoRecorderRecordFinished")]
		void DidFinishRecording(SCAudioVideoRecorder audioVideoRecorder, NSUrl recordedFile, NSError error);

		[Abstract]
		[Export("audioVideoRecorder:didFailToInitializeVideoEncoder:"), EventArgs("AudioVideoRecorderInitializeFailed")]
		void DidFailInitializeVideoEncoder(SCAudioVideoRecorder audioVideoRecorder, NSError error);

		[Abstract]
		[Export("audioVideoRecorder:didFailToInitializeAudioEncoder:"), EventArgs("AudioVideoRecorderInitializeFailed")]
		void DidFailInitializeAudioEncoder(SCAudioVideoRecorder audioVideoRecorder, NSError error);
	}

    [Model, BaseType (typeof (NSObject))]
    interface SCDataEncoderDelegate {
        
        [Export ("dataEncoder:didEncodeFrame:")]
        void DidEncodeFrame (SCDataEncoder dataEncoder, double frameSecond);
        
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
        string OutputFileType { get; set; }
	
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

        [Export("session")]
        AVCaptureSession Session { get; }

        [Export("videoOrientation")]
        int VideoOrientation { get; set; }

        [Export("switchCamera")]
        void SwitchCamera();

        [Export("useFrontCamera")]
        bool UseFrontCamera { get; set; }
    }

    [BaseType(typeof(NSObject))]
    interface SCAudioTools {

        [Static]
        [Export("overrideCategoryMixWithOthers")]
        void OverrideCategoryMixWithOthers();

    }

	[Model, BaseType(typeof(NSObject))]
	interface SCPlayerDelegate {

		[Export("videoPlayer:didPlay:secondsTotal:")]
		void DidPlay(SCPlayer player, double secondsElapsed, double secondsTotal);

		[Export("videoPlayer:didStartLoadingAtItemTime:")]
		void DidStartLoading(SCPlayer player, CMTime itemItem);

		[Export("videoPlayer:didEndLoadingAtItemTime:")]
		void DidEndLoading(SCPlayer player, CMTime itemItem);

        [Export("videoPlayer:didChangeItem:")]
        void DidChangeItem(SCPlayer player, [NullAllowed] AVPlayerItem item);

	}

	[BaseType(typeof(AVPlayer))]
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
		double PlayableDuration { get; }

		[Export("isPlaying")]
		bool IsPlaying { get; }

		[Export("isLoading")]
		bool IsLoading { get; }

		[Export("minimumBufferedTimeBeforePlaying")]
		double MinimumBufferedTimeBeforePlaying { get; set; }

		[Export("shouldLoop")]
		bool ShouldLoop { get; set; }
	
	}

	[BaseType(typeof(UIView))]
	interface SCVideoPlayerView : SCPlayerDelegate {

		[Export("player")]
		SCPlayer Player { get; }

		[Export("loadingView")]
		UIView LoadingView { get; set; }

	}
}
