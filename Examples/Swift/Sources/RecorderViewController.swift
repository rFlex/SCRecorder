//
//  RecorderViewController.swift
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 28/03/15.
//
//

import UIKit
import SCRecorder

class RecorderViewController: UIViewController {
    
    var recorder: SCRecorder!
    var photo: UIImage?
    var recordSession: SCRecordSession?
    
    @IBOutlet weak var bottomBar: UIView!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var previewView: UIView!
    @IBAction func switchCameraMode(sender: AnyObject) {
    }
    
    @IBAction func switchFlashButton(sender: AnyObject) {
    }
    @IBOutlet weak var flashModeButton: UIButton!
    @IBAction func switchGhostMode(sender: AnyObject) {
    }
    @IBOutlet weak var ghostModeButton: UIButton!
    @IBOutlet weak var switchCameraModeButton: UIButton!
    @IBAction func reverseCamera(sender: AnyObject) {
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    

}
