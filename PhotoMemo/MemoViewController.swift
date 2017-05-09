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
import CoreSpotlight
import MobileCoreServices

class MemoViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegateFlowLayout, AVAudioRecorderDelegate, UISearchBarDelegate {

    var activeMemo: URL!
    var audioRecorder: AVAudioRecorder?
    var recordingUrl: URL!
    var audioPlayer: AVAudioPlayer?
    var memos = [URL]()
    var filteredMemos = [URL]()
    var searchQuery: CSSearchQuery?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
      
        recordingUrl = userDirectory().appendingPathComponent("recording.m4a")
        
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
        print("load \(memos.count) memos from disk")
        
        filteredMemos = memos
        
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
            return filteredMemos.count
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let  cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MemoCell", for: indexPath) as! MemoCell
        let memo = filteredMemos[indexPath.row]
        let imageName = thumbnailURL(memo: memo).path
        if let memoThumb = UIImage.init(contentsOfFile: imageName) {
            cell.imageView.image = memoThumb
        }
        
        if cell.gestureRecognizers == nil {
            // Add long press gesture
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressOnCell))
            recognizer.minimumPressDuration = 0.25
            cell.addGestureRecognizer(recognizer)
            
            // Add frame
            cell.layer.borderColor = UIColor.white.cgColor
            cell.layer.borderWidth = 3
            cell.layer.cornerRadius = 10
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
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedMemo = filteredMemos[indexPath.row]
        let fm = FileManager.default
        
        do {
            let audioName = audioUrl(memo: selectedMemo)
            let transcription = transcribtionUrl(memo: selectedMemo)
            
            if fm.fileExists(atPath: audioName.path) {
                audioPlayer = try AVAudioPlayer(contentsOf: audioName)
                audioPlayer?.play()
            }
            
            if fm.fileExists(atPath: transcription.path) {
                let contents = try String(contentsOf: transcription)
                print("transcription \(contents)")
            }
        } catch {
            print("Error playing back audio or reading transcription")
        }
    }
    
    func imageUrl(memo: URL) -> URL {
        return memo.appendingPathExtension("jpg")
    }
    
    func thumbnailURL(memo: URL) -> URL {
        return memo.appendingPathExtension("thumb")
    }
    
    func audioUrl(memo: URL) -> URL {
        return memo.appendingPathExtension("m4a")
    }
    
    func transcribtionUrl(memo: URL) -> URL {
        return memo.appendingPathExtension("txt")
    }
    
    func didLongPressOnCell(sender: UILongPressGestureRecognizer) {
        
        if sender.state == .began {
            let cell = sender.view as! MemoCell
            
            if let index = collectionView?.indexPath(for: cell) {
                activeMemo = filteredMemos[index.row]
                recordMemo()
            }
            
        } else if sender.state == .ended {
            finishRecording(success: true)
        }
    }
    
    func recordMemo() {
        audioPlayer?.stop()
        
        collectionView?.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        let recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
            
            let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            
            audioRecorder = try AVAudioRecorder(url: recordingUrl, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch let error {
            print("Failed to record: \(error)")
            finishRecording(success: false)
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
    
    func finishRecording(success: Bool) {
        collectionView?.backgroundColor = UIColor.lightGray
        
        audioRecorder?.stop()
        
        if success {
            do {
                let memoAudioUrl = audioUrl(memo: activeMemo)
                
                let fm = FileManager.default
                // Remove old audio
                if fm.fileExists(atPath: memoAudioUrl.path) {
                    try fm.removeItem(at: memoAudioUrl)
                }
                // Add new audio
                try fm.moveItem(at: recordingUrl, to: memoAudioUrl)
                
                transcribeAudio(memo: activeMemo)
                
            } catch let error {
                print("Failure finishing recording: \(error)")
            }
        }
    }
    
    func transcribeAudio(memo: URL) {
        let audio = audioUrl(memo: memo)
        let transcription = transcribtionUrl(memo: memo)
        
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: audio)
        
        recognizer?.recognitionTask(with: request, resultHandler: { [unowned self] (result, error) in
            guard let transResult = result else {
                print("Transcription error \(error!)")
                return
            }
            
            if transResult.isFinal {
                let text = transResult.bestTranscription.formattedString
                
                do {
                    try text.write(to: transcription, atomically:true, encoding: String.Encoding.utf8)
                    
                    self.indexMemo(memo: memo, text: text)
                } catch {
                    print("Failed to save transcription")
                }
            }
        })
    }
    
    func indexMemo(memo: URL, text: String) {
        // Create a basic attribute set
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        
        attributeSet.title = "Photo Memo"
        attributeSet.contentDescription = text
        
        // Wrap it in a searchable item
        let item = CSSearchableItem(uniqueIdentifier: memo.path, domainIdentifier: "bj.fr", attributeSet: attributeSet)
        
        item.expirationDate = Date.distantFuture
        
        CSSearchableIndex.default().indexSearchableItems([item]) { (error) in
            if let error = error {
                print("Spotlight indexing error \(error.localizedDescription)")
            }
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredMemos(text: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func filteredMemos(text: String) {
        
        guard text.characters.count > 0 else {
            filteredMemos = memos
            UIView.performWithoutAnimation {
                collectionView?.reloadSections(IndexSet(integer: 1))
            }
            return
        }
        
        var allItems = [CSSearchableItem]()
        searchQuery?.cancel()
        let queryString = "contentDescription == \"*\(text)*\"c"
        
        searchQuery = CSSearchQuery(queryString: queryString, attributes: nil)
        
        searchQuery?.foundItemsHandler = { items in
            allItems.append(contentsOf: items)
        }
        
        searchQuery?.completionHandler = { error in
            DispatchQueue.main.async {
                [unowned self] in
                self.activateFilter(matches: allItems)
            }
        }
        
        searchQuery?.start()
    }
    
    func activateFilter(matches: [CSSearchableItem]) {
        filteredMemos = matches.map{ (item) in
            return URL(fileURLWithPath: item.uniqueIdentifier)
        }
        UIView.performWithoutAnimation {
            collectionView?.reloadSections(IndexSet(integer: 1))
        }
    }
}
