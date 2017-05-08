//
//  ViewController.swift
//  PhotoMemo
//
//  Created by Björn Fröhling on 06/05/2017.
//  Copyright © 2017 Fröhling. All rights reserved.
//

import UIKit
import Photos
import Speech
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var helpLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func requestPermissions(_ sender: Any) {
        self.requestPhotoPermissions()
    }

    func requestPhotoPermissions() {
        PHPhotoLibrary.requestAuthorization { [unowned self] (authStatus) in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.requestRecordPermission()
                } else {
                    self.helpLabel.text = "Photo permission was declined, please enable it and press Continue"
                }
            }
        }
    }
    
    func requestRecordPermission() {
         AVAudioSession.sharedInstance().requestRecordPermission { [unowned self] (hasPermission) in
            DispatchQueue.main.async {
                if hasPermission {
                    self.requestTranscribePermission()
                } else {
                    self.helpLabel.text = "Recording permission was declined, please enable it and press Continue"
                }
            }
        }
    }
    
    func requestTranscribePermission() {
        SFSpeechRecognizer.requestAuthorization { [unowned self] (authStatus) in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.authorizationComplete()
                } else {
                    self.helpLabel.text = "Transcribe permission was declined, please enable it and press Continue"
                }
            }
        }
    }
    
    func authorizationComplete() {
        self.dismiss(animated: true)
    }
}

