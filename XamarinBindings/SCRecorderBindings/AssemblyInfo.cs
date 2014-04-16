using System;
using MonoTouch.ObjCRuntime;

[assembly: LinkWith ("libSCRecorder-Universal.a", LinkTarget.Simulator | LinkTarget.ArmV7, ForceLoad = true)]
