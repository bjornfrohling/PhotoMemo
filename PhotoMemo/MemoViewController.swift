//
//  MemoViewController.swift
//  PhotoMemo
//
//  Created by Björn Fröhling on 06/05/2017.
//  Copyright © 2017 Fröhling. All rights reserved.
//

import UIKit
import AVFoundation
import Speech
import Photos

class MemoViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegateFlowLayout {

    var memos = [URL]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        
        loadMemos()
    }

    override func viewDidAppear(_ animated: Bool) {
        self.checkPermissions()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func checkPermissions() {
        let photosAuthorized = PHPhotoLibrary.authorizationStatus() == .authorized
        let recordingAuthorized = AVAudioSession.sharedInstance().recordPermission() == .granted
        let transcribeAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        
        let authorized = photosAuthorized && recordingAuthorized && transcribeAuthorized
        
        if authorized == false {
            if let vc = storyboard?.instantiateViewController(withIdentifier: "FirstRun") {
                navigationController?.present(vc, animated: true)
            }
        }
    }
    
    func userDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    func loadMemos() {
        memos.removeAll()
        //attempt to load all the memories in our documents directory
        guard let files = try? FileManager.default.contentsOfDirectory(at: userDirectory(), includingPropertiesForKeys: nil, options: []) else { return }
        
        //loop over every file found
        for file in files {
            let filename = file.lastPathComponent
            
            //check it ends with ".thumb" so we dont count each memo more than once
            if filename.hasSuffix(".thumb") {
                
                //get the root name of the memo (i.e., without its path extension)
                let noExtension = filename.replacingOccurrences(of: ".thumb", with: "")
                
                //create a full path from the memo
                let memoPath = userDirectory().appendingPathComponent(noExtension)
                
                //add it to our array
                memos.append(memoPath)
            }
        }
        print("loadMemos \(memos)")
        
        //reload our list of memories
        collectionView?.reloadSections(IndexSet(integer: 1))
    }
    
    func addTapped() {
        let pc = UIImagePickerController()
        pc.delegate = self
        pc.modalPresentationStyle = .formSheet
        navigationController?.present(pc, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true)
        
        if let selectedImg = info[UIImagePickerControllerOriginalImage] as? UIImage {
            saveMemo(image: selectedImg)
            loadMemos()
        }
    }
    
    func saveMemo(image: UIImage) {
        //create a unique name for this memo
        let memoName = "memo-\(Date().timeIntervalSince1970)"
        
        //use the unique name to create filenames for the full size image and the thunbnail
        let imageName = memoName + ".jpg"
        let thumbnailName = memoName + ".thumb"
        
        do {
            //create a URL where we can write the JPEG to
            let imagePath = userDirectory().appendingPathComponent(imageName)
            
            //convert the UIImage into a JPEG data object
            if let jpegData = UIImageJPEGRepresentation(image, 80) {
                
                //write that data to the URL we created
                try jpegData.write(to: imagePath, options: [.atomicWrite])
            }
            //create thumbnail here
            if let thumbnail = resize(image: image, to: 200) {
                
                let imagePath = userDirectory().appendingPathComponent(thumbnailName)
                
                if let jpegData = UIImageJPEGRepresentation(thumbnail, 80) {
                    try jpegData.write(to: imagePath, options: [.atomicWrite])
                }
            }
            
        } catch {
            print("Failed to save to disk.")
        }
    }
    
    func resize(image: UIImage, to width: CGFloat) -> UIImage? {
        let scale = width / image.size.width
        let height = image.size.height * scale
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        image.draw(in: CGRect(x:0, y:0, width: width, height: height))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 0
        } else {
            return memos.count
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let  cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MemoCell", for: indexPath) as! MemoCell
        let memo = memos[indexPath.row]
        let imageName = thumbnailURL(memo: memo).path
        if let memoThumb = UIImage.init(contentsOfFile: imageName) {
            cell.imageView.image = memoThumb
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 1 {
            return CGSize.zero
        } else {
            return CGSize(width: 0, height: 50)
        }
    }
    
    func imageUrl(memo: URL) -> URL {
        return memo.appendingPathComponent("jpg")
    }
    
    func thumbnailURL(memo: URL) -> URL {
        return memo.appendingPathExtension("thumb")
    }
    
    func audioUrl(memo: URL) -> URL {
        return memo.appendingPathComponent("m4a")
    }
    
    func transcribtionUrl(memo: URL) -> URL {
        return memo.appendingPathComponent("txt")
    }
}
