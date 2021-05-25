//
//  ViewController.swift
//  DZ-Looper
//
//  Created by dp on 5/15/21.
//  Copyright © 2021 dputnam. All rights reserved.
//

import Cocoa
import AVKit
import AVFoundation
import AppKit
import Photos


// Custom class for assets
class Asset: NSObject {
    var url: URL
    var image: NSImageRep
    var name: String
    
    init(url: URL, image: NSImageRep) {
        self.url = url
        self.image = image
        self.name = url.lastPathComponent
    }
}


class ViewController: NSViewController {
    
    // IBOutlet Properties
    @IBOutlet weak var secPerImg: NSTextField!
    @IBOutlet weak var fpsMenu: NSPopUpButton!
    @IBOutlet weak var outputWidthOutlet: NSTextField!
    @IBOutlet weak var outputHeightOutlet: NSTextField!
    @IBOutlet weak var overlayButton: NSButton!
    @IBOutlet weak var overlayFilePathField: NSTextField!
    @IBOutlet weak var outputFilePathField: NSTextField!
    @IBOutlet weak var loopNumber: NSTextField!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var renderButton: NSButton!
    @IBOutlet weak var overlayXPlacement: NSTextField!
    @IBOutlet weak var overlayYPlacement: NSTextField!
    @IBOutlet weak var assetTokenField: DragDropTokenField!
    
    // Global variables for encoding settings
    var loops = 2
    var secondsPerImage: TimeInterval = 1
    var overlay: Bool = true
    var outputFrameSize = CGSize(width: 1080, height: 1080)
    var fps: Int32 = 24
    var ntsc: Bool = true
    var frameTimeValue: Int64 = 1000
    var frameTimeScale: Int32 = 23976
    
    
    // Prevent window resizing
    override func viewDidAppear() {
        self.view.window?.styleMask = [.closable, .titled, .miniaturizable]
    }
    
    
    // Load user defaults on load if available
    override func viewDidLoad() {
        super.viewDidLoad()
            
        assetTokenField.delegate = self
        
        if UserDefaults.standard.object(forKey: "fpsSelection") != nil {
            fpsMenu.selectItem(withTitle: (UserDefaults().string(forKey: "fpsSelection")!))
        }
        if UserDefaults.standard.object(forKey: "overlayToggle") != nil {
            overlayButton.state = NSControl.StateValue(UserDefaults().integer(forKey: "overlayToggle"))
        }
        if UserDefaults.standard.object(forKey: "secPerImg") != nil {
            secPerImg.doubleValue = UserDefaults().double(forKey: "secPerImg")
        }
        if UserDefaults.standard.object(forKey: "loopNumber") != nil {
            loopNumber.intValue = Int32(UserDefaults().integer(forKey: "loopNumber"))
        }
        if UserDefaults.standard.object(forKey: "overlayXPlacement") != nil {
            overlayXPlacement.intValue = Int32(UserDefaults().integer(forKey: "overlayXPlacement"))
        }
        if UserDefaults.standard.object(forKey: "overlayYPlacement") != nil {
            overlayYPlacement.intValue = Int32(UserDefaults().integer(forKey: "overlayYPlacement"))
        }
    }
    
    // MARK:- Actions For UI Elements
    
    // "Select Files" adds to our asset array (stored in our token field)
    @IBAction func selectFiles(_ sender: Any) {
        let dialog = NSOpenPanel();
        dialog.title                   = "Choose multiple files";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = false;
        dialog.allowsMultipleSelection = true;
        dialog.allowedFileTypes        = ["tif", "png", "jpg", "jpeg", "gif"];
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let results = dialog.urls
            var labelArray = [String]()
            if (assetTokenField.objectValue as? [String] != nil) {
                let original_array = assetTokenField.objectValue as! [String]
                for obj in original_array {
                    labelArray.append(obj)
                }
            }
            for result in results {
                let image = NSImageRep(contentsOfFile: result.path)
                let asset = Asset(url: result, image: image!)
                assetTokenField.appendAsset(asset: asset)
                labelArray.append(asset.name)
            }
            assetTokenField.objectValue = labelArray
        }
    }
    
    
    // Seconds Per Image field: prevent entries <0
    @IBAction func selectSeconds(_ sender: NSTextField) {
        if secPerImg.doubleValue <= Double(0) {
            secPerImg.doubleValue = Double(1)
        }
        UserDefaults().set(secPerImg.doubleValue, forKey: "secPerImg")
    }
    
    
    // Number of Loops field: prevent entries <0 or decimal
    @IBAction func selectLoops(_ sender: NSTextField) {
        if loopNumber.intValue <= Int32(0) {
            loopNumber.intValue = 2
        }
        // get rid of any decimals
        loopNumber.stringValue = String(loopNumber.intValue)
        UserDefaults().set(loopNumber.intValue, forKey: "loopNumber")
    }
    

    // Overlay toggle
    @IBAction func overlayToggle(_ sender: NSButton) {
        UserDefaults().set(overlayButton.state.rawValue, forKey: "overlayToggle")
    }
    
    // Overlay placement from bottom right corner
    @IBAction func placementXSelect(_ sender: NSTextField) {
        UserDefaults().set(overlayXPlacement.intValue, forKey: "overlayXPlacement")
    }
    
    @IBAction func placementYSelect(_ sender: NSTextField) {
        UserDefaults().set(overlayYPlacement.intValue, forKey: "overlayYPlacement")
    }
    
    
    // Select overlay file
    @IBAction func selectOverlay(_ sender: NSButton) {
        let dialog = NSOpenPanel();
        dialog.title                   = "Select overlay image";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = false;
        dialog.allowsMultipleSelection = false;
        dialog.allowedFileTypes        = ["tif", "png", "jpg", "jpeg", "gif"];
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let results = dialog.url!.path
            overlayFilePathField.stringValue = results
        }
    }
    
    
    // Select frames per second from drop-down
    @IBAction func fpsSelect(_ sender: NSPopUpButton) {
        UserDefaults().set(fpsMenu.titleOfSelectedItem, forKey: "fpsSelection")
    }
    
    
    // Output selector
    @IBAction func selectOutput(_ sender: NSButton) {
        let dialog = NSSavePanel();
        dialog.title                     = "Choose output file";
        dialog.nameFieldStringValue      = "output.mp4";
        dialog.directoryURL              = URL(string: NSHomeDirectory() + "/Desktop")
        dialog.allowedFileTypes          = ["mp4"]
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let results = dialog.url!.path
            outputFilePathField.stringValue = results
        }
    }
    
    

    // MARK:- Render Action (sorry for the mess)

    // Called upon render -- all the magic is here:
    @IBAction func renderButtonAction(_ sender: NSButton) {
        // Disable our button until process is finished
        renderButton.isEnabled = false
        
        // Arrange our assets in order of the tokens
        var arrangedArray = [Asset]()
        for token in assetTokenField?.objectValue as! NSArray {
            for asset in assetTokenField.returnAssets() {
                if asset.name == token as? String {
                    arrangedArray.append(asset)
                }
            }
        }
        
        // Get the output filepath from UI
        let filePathStringFromInputField = outputFilePathField.stringValue
        
        // If output file exists, confirm overwrite
        if !fileOverwriteAskContinue(path: filePathStringFromInputField) {
            self.renderButton.isEnabled = true
            return
        }
        let outputFileURL = URL(fileURLWithPath: filePathStringFromInputField)
        removeFileAtURLIfExists(url: outputFileURL)
        
        // Set the rest of our output variables based on inputs
        refreshGlobalVariablesFromUI()
        
        // exit if no input assets parsed
        if arrangedArray.count == 0 {
            genericAlert(message:"Select at least one input image!")
            self.renderButton.isEnabled = true
            return
        }
        
        // Calculate our total number of frames
        let totalFrames = Double(arrangedArray.count) * secondsPerImage * Double(fps) * Double(loops)
        
        // Set our UI progress bar values
        progressBar.maxValue = totalFrames
        progressBar.doubleValue = 0
        
        // Get overlay info once before we run the render loop
        var overlayImg: NSImageRep
        var overlaySize = CGSize()
        var overlayRect = CGRect()
        var cgOverlay: CGImage?
        var overlayX = CGFloat()
        var overlayY = CGFloat()
        olCheck: if (self.overlay == true) {
            if (!FileManager.default.fileExists(atPath: overlayFilePathField.stringValue)) {
                overlay = false
                break olCheck
            }
            overlayImg = NSImageRep(contentsOfFile: overlayFilePathField.stringValue)!
            overlaySize = CGSize(width: overlayImg.pixelsWide, height: overlayImg.pixelsHigh)
            overlayRect = CGRect(origin: CGPoint(x: 0, y: 0), size: overlaySize)
            cgOverlay = overlayImg.cgImage(forProposedRect: &overlayRect, context: NSGraphicsContext.current, hints: nil)!
            overlayX = self.outputFrameSize.width - overlaySize.width - CGFloat(overlayXPlacement.intValue)
            overlayY = CGFloat(overlayYPlacement.intValue)
            if (overlayImg.pixelsWide > (arrangedArray[0].image.pixelsWide) || overlayImg.pixelsHigh > arrangedArray[0].image.pixelsHigh) {
                genericAlert(message: "Overlay image cannot be larger in width or height than the source image")
                self.renderButton.isEnabled = true
                return
            }
        }
        
        // Set up our AVAssetWriter
        guard let videoWriter = try? AVAssetWriter(outputURL: outputFileURL, fileType: AVFileType.mp4) else {
            fatalError("AVAssetWriter error")
        }
        videoWriter.movieTimeScale = frameTimeScale
        let outputSettings = [AVVideoCodecKey : AVVideoCodecType.h264, AVVideoWidthKey : NSNumber(value: Float(outputFrameSize.width)), AVVideoHeightKey : NSNumber(value: Float(outputFrameSize.height))] as [String : Any]
        guard videoWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaType.video) else {
            fatalError("Negative : Can't applay the Output settings...")
        }
        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        videoWriterInput.mediaTimeScale = frameTimeScale
        let sourcePixelBufferAttributesDictionary = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32ARGB), kCVPixelBufferWidthKey as String: NSNumber(value: Float(outputFrameSize.width)), kCVPixelBufferHeightKey as String: NSNumber(value: Float(outputFrameSize.height))]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        
        if videoWriter.startWriting() {
            let frameCMTime = CMTimeMake(value: frameTimeValue, timescale: frameTimeScale)
            videoWriter.startSession(atSourceTime: frameCMTime)
            assert(pixelBufferAdaptor.pixelBufferPool != nil)
            let media_queue = DispatchQueue(label: "mediaInputQueue")
            videoWriterInput.requestMediaDataWhenReady(on: media_queue, using: { () -> Void in
                var frameCounter: Int64 = 0
                var imageCounter = 0
                var appendSucceeded = true
                var droppedFrameFlag = false
                for frame in 1...Int(totalFrames) {
                    // Get the right image
                    if imageCounter == arrangedArray.count {
                        imageCounter = 0
                    }
                    let image = arrangedArray[imageCounter].image
                    if frame % Int(floor(Double(self.fps) * self.secondsPerImage)) == 0 {
                        imageCounter = imageCounter + 1
                    }
                    while !videoWriterInput.isReadyForMoreMediaData {
                        print("Sleeping to catch up")
                        usleep(useconds_t(50000))
                    }
                    if (videoWriterInput.isReadyForMoreMediaData) {
                        let lastFrameTime = CMTimeMake(value: frameCounter * self.frameTimeValue, timescale: self.frameTimeScale)
                        let presentationTime = CMTimeAdd(lastFrameTime, frameCMTime)
                        var pixelBuffer: CVPixelBuffer? = nil
                        let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
                        if let pixelBuffer = pixelBuffer, status == 0 {
                            let managedPixelBuffer = pixelBuffer
                            CVPixelBufferLockBaseAddress(managedPixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                            let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
                            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                            let context = CGContext(data: data, width: Int(self.outputFrameSize.width), height: Int(self.outputFrameSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
                            context!.clear(CGRect(x: 0, y: 0, width: CGFloat(self.outputFrameSize.width), height: CGFloat(self.outputFrameSize.height)))
                            let horizontalRatio = CGFloat(self.outputFrameSize.width) / image.size.width
                            let verticalRatio = CGFloat(self.outputFrameSize.height) / image.size.height
                            let aspectRatio = min(horizontalRatio, verticalRatio)
                            let newSize: CGSize = CGSize(width: image.size.width * aspectRatio, height: image.size.height * aspectRatio)
                            let x = newSize.width < self.outputFrameSize.width ? (self.outputFrameSize.width - newSize.width) / 2 : 0
                            let y = newSize.height < self.outputFrameSize.height ? (self.outputFrameSize.height - newSize.height) / 2 : 0
                            var rect = CGRect(origin: CGPoint(x: 0, y: 0), size: self.outputFrameSize)
                            let cgImage: CGImage = image.cgImage(forProposedRect: &rect, context: NSGraphicsContext.current, hints: nil)!
                            context!.draw(cgImage, in: CGRect(x: x, y: y, width: newSize.width, height: newSize.height))
                            if (self.overlay == true) {
                                context!.draw(cgOverlay!, in: CGRect(x: overlayX, y: overlayY, width: overlaySize.width, height: overlaySize.height))
                            }
                            CVPixelBufferUnlockBaseAddress(managedPixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                            appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                            frameCounter += 1
                            DispatchQueue.main.async {
                                self.progressBar.increment(by: Double(1))
                                if self.progressBar.doubleValue == self.progressBar.maxValue {
                                    self.progressBar.doubleValue = 0
                                }
                            }
                        } else {
                            print("Failed to allocate pixel buffer")
                            appendSucceeded = false
                        }
                    } else {
                        print("Not ready for frame")
                        if !droppedFrameFlag {
                            self.genericAlert(message: "Something may have went wrong, please QC output when finished")
                            droppedFrameFlag = true
                        }
                    }
                    if !appendSucceeded {
                        self.renderButton.isEnabled = true
                        break
                    }
                }
                videoWriterInput.markAsFinished()
                videoWriter.finishWriting { () -> Void in
                    print("-----video1 url = \(outputFileURL)")
                    print(outputFileURL)
                    NSWorkspace.shared.activateFileViewerSelecting([outputFileURL])
                }
            })
            self.renderButton.isEnabled = true
        }
    }
    
    
    
    // MARK:- Helpers used in Render function

    func removeFileAtURLIfExists(url: URL) {
        let filePath = url.path
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath) {
            do{
                try fileManager.removeItem(atPath: filePath)
            } catch let error as NSError {
                print("Couldn't remove existing destination file: \(error)")
            }
        }
        
    }
    
    
    func genericAlert(message: String) {
            let alert: NSAlert = NSAlert()
            alert.messageText = "\(message as NSString)"
            alert.addButton(withTitle: "Ok")
            alert.runModal()
    }
    
    
    func fileOverwriteAskContinue(path: String) -> Bool {
        var response = true
        if (FileManager.default.fileExists(atPath: path)) {
            let fileExistsAlert: NSAlert = NSAlert()
            fileExistsAlert.messageText = "'\((path as NSString).lastPathComponent)' already exists. Do you want to replace it?"
            fileExistsAlert.informativeText = "A file or folder with the same name already exists in the folder \((path as NSString).deletingLastPathComponent). Replacing it will overwrite its current contents."
            fileExistsAlert.addButton(withTitle: "Yes")
            fileExistsAlert.addButton(withTitle: "No")
            let responseTag: NSApplication.ModalResponse = fileExistsAlert.runModal()
            if (responseTag == NSApplication.ModalResponse.alertSecondButtonReturn) {
                response = false
            }
        }
        return response
    }
    
    
    func refreshGlobalVariablesFromUI() -> Void {
        loops = Int(loopNumber.intValue)
        secondsPerImage = secPerImg.doubleValue
        overlay = overlayButton.state.rawValue == 1 ? true : false
        
        outputFrameSize.width = CGFloat(outputWidthOutlet.intValue)
        outputFrameSize.height = CGFloat(outputHeightOutlet.intValue)
                
        // update frame rate render settings
        if fpsMenu.titleOfSelectedItem == "23.976 fps" {
            fps = 24
            frameTimeValue = 1000
            frameTimeScale = 23976
            ntsc = true
        } else if fpsMenu.titleOfSelectedItem == "24 fps" {
            fps = 24
            frameTimeValue = 1
            frameTimeScale = 24
            ntsc = false
        } else if fpsMenu.titleOfSelectedItem == "25 fps" {
            fps = 25
            frameTimeValue = 1
            frameTimeScale = 25
            ntsc = false
        } else if fpsMenu.titleOfSelectedItem == "30 fps" {
            fps = 30
            frameTimeValue = 1
            frameTimeScale = 30
            ntsc = false
        }
    }
}



// MARK:- NSTokenFieldDelegate


extension ViewController: NSTokenFieldDelegate {
    
    func tokenField(_ tokenField: NSTokenField,
    shouldAdd tokens: [Any],
    at index: Int) -> [Any] {
        let labelArray = assetTokenField.returnAssets().map { $0.name }
        var flag = false
        for token in tokens {
            if labelArray.contains(String(describing: token)) {
                flag = true
            } else {
                print("false")
                flag = false
            }
        }
        print("repsonding to ShouldAdd")
        if !flag {
            return []
        } else {
            return tokens as! [String]
        }
    }
    
    // return middle-truncated string for long filenames
    func tokenField(_ tokenField: NSTokenField,
                    displayStringForRepresentedObject representedObject: Any) -> String? {
        let string = representedObject as! String
        if string.count < 30 {
            return string
        } else {
            let first15 = string.prefix(15)
            let last15 = "..." + string.suffix(15)
            return String(first15 + last15)
        }
    }
    
}

