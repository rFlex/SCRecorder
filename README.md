SCAudioVideoRecorder
===============

A Vine like audio/video recorder in Objective-C.

These classes allow the recording of a video with pause/resume function. They are straightfoward to use, only a few lines is needed to start recording.
They are compatible both for OS X and iOS.
Examples for both OS X and IOS are provided.


Straightfoward recording using SCCamera
---------------------------------------

Initializing the camera:

	// Create the camera
        SCCamera * camera = [SCCamera camera];

	// Set the target UIView (or NSView for OS X) which will receive the video preview
	camera.previewView = self.cameraView;

	// Start the session and the flow of inputs
	[camera initialize:^(NSError *audioError, NSError *videoError) {

	}];

Interacting with the camera:

	// Prepare the camera to record on the camera roll
	NSError * error;
	[camera prepareRecordingAtCameraRoll:&error];

	// Prepare the camera to record on a temp file
	// The returned url is the generated temp file
	NSURL * outputUrl = [camera prepareRecordingOnTempDir:&error];

	// Prepare the camera to record on the specified url
	[camera prepareRecordingAtUrl:[NSURL URLWithString:@"file://output.mp4"] error:&error];

	// Ask the camera to record (the camera must be prepared before)
	[camera record];

	// Ask the camera to pause
	[camera pause];

	// Ask the camera to finish the recording. After calling this,
	// the camera wont be able to record on the file again and it will
	// loose its "prepared" state. Therefore "prepareRecording" must be called
	// before trying to record again.
	[camera stop];

	// Handle the recorded file
	camera.delegate = self;
	- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFinishRecordingAtUrl:(NSURL *)recordedFile error:(NSError *)error {
	  	 if (error == nil) {
	     NSLog(@"Succesfully recorded file at %@", recordedFile);
	  } else {
	    NSLog(@"Failed to record file: %@", error);
	  }
	}


Manually handling AVCaptureSession with SCAudioVideoRecorder
------------------------------------------------------------

The SCCamera seen just before inherits from SCAudioVideoRecorder. The whole "interacting with the camera" part is thus valable for the SCAudioVideoRecorder as well. The SCCamera just adds an automatic handling of the AVCaptureSession. If you want to manually handle the CaptureSession yourself, here is how you can do:


	AVCaptureSession * session = [[AVCaptureSession alloc] init];
	SCAudioVideoRecorder * avr = [[SCAudioVideoRecorder alloc] init];
	
        // Adding the support for the audio
	[session addOutput:avr.audioOutput];

	// Adding the support for the video
	[session addOutput:avr.videoOutput];
