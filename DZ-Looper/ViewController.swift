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

class Asset: NSObject {
    var url: String
    var image: NSImageRep
    
    init(url: String, image: NSImageRep) {
        self.url = url
        self.image = image
    }
}

class ViewController: NSViewController {

    @IBOutlet weak var selectedFileList: NSScrollView!
    @IBOutlet var scrollViewText: NSTextView!
    @IBOutlet weak var secPerImg: NSTextField!
    @IBOutlet weak var fpsSelect: NSPopUpButton!
    @IBOutlet weak var fpsMenu: NSPopUpButton!
    @IBOutlet weak var overlayButton: NSButton!
    @IBOutlet weak var overlayFilePathField: NSTextField!
    @IBOutlet weak var outputFilePathField: NSTextField!
    @IBOutlet weak var loopNumber: NSTextField!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var fileTable: NSTableView!
    @IBOutlet weak var renderButton: NSButton!
    
    var assetArray = [Asset]()
    
    var loops = 2
    var secondsPerImage: TimeInterval = 1
    var overlay: Bool = true
    
    var outputFrameSize = CGSize(width: 0, height: 0)
    var fps: Int32 = 24
    var ntsc: Bool = true
    var frameTimeValue: Int64 = 1000
    var frameTimeScale: Int32 = 23976
    
    
    override func viewDidAppear() {
        self.view.window?.styleMask = [.closable, .titled, .miniaturizable]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // LOAD USER DEFAULTS
        // Note: disabling remembered paths for sandboxed app
        /*
        if UserDefaults.standard.object(forKey: "lastOutputPath") != nil {
            outputFilePathField.stringValue = UserDefaults().string(forKey: "lastOutputPath")!
        }
        if UserDefaults.standard.object(forKey: "overlayPath") != nil {
            overlayFilePathField.stringValue = UserDefaults().string(forKey: "overlayPath")!
        }
        */
        //selectedFileList.documentView.en
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
    }
    
    
    @IBAction func selectFiles(_ sender: Any) {
        scrollViewText.isEditable = true
        let dialog = NSOpenPanel();
        dialog.title                   = "Choose multiple files";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = false;
        dialog.allowsMultipleSelection = true;
        dialog.allowedFileTypes        = ["tif", "png", "jpg", "jpeg", "gif"];
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let results = dialog.urls
            var text = ""
            let textView : NSTextView? = selectedFileList?.documentView as? NSTextView
            textView?.string = text
            for result in results {
                text += result.path + "\n"
                /*
                let asset = Asset(url: result.path, image: NSImageRep(contentsOfFile: result.path)!)
                assetArray.append(asset)
                */
            }
            selectedFileList.documentView!.insertText(text)
        }
        scrollViewText.isEditable = false
    }
    
    
    @IBAction func selectSeconds(_ sender: NSTextField) {
        if secPerImg.doubleValue <= Double(0) {
            secPerImg.doubleValue = Double(1)
        }
        UserDefaults().set(secPerImg.doubleValue, forKey: "secPerImg")
    }
    
    
    @IBAction func selectLoops(_ sender: NSTextField) {
        if loopNumber.intValue <= Int32(0) {
            loopNumber.intValue = 2
        }
        // get rid of any decimals
        loopNumber.stringValue = String(loopNumber.intValue)
        UserDefaults().set(loopNumber.intValue, forKey: "loopNumber")
    }
    

    @IBAction func overlayToggle(_ sender: NSButton) {
        UserDefaults().set(overlayButton.state.rawValue, forKey: "overlayToggle")
    }
    
    
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
            //UserDefaults().set(results, forKey: "overlayPath")
        }
    }
    
    
    @IBAction func fpsSelect(_ sender: NSPopUpButton) {
        UserDefaults().set(fpsMenu.titleOfSelectedItem, forKey: "fpsSelection")
    }
    
    
    @IBAction func selectOutput(_ sender: NSButton) {
        let dialog = NSSavePanel();
        dialog.title                     = "Choose output file";
        dialog.nameFieldStringValue      = "output.mp4";
        dialog.directoryURL              = URL(string: NSHomeDirectory() + "/Desktop")
        dialog.allowedFileTypes          = ["mp4"]
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let results = dialog.url!.path
            //UserDefaults().set(results, forKey: "lastOutputPath")
            outputFilePathField.stringValue = results
        }
    }
    
    
    
    @IBAction func renderButtonAction(_ sender: NSButton) {
        renderButton.isEnabled = false
        // get the output filepath from UI
        let filePathStringFromInputField = outputFilePathField.stringValue
        // if output file exists, confirm overwrite
        if !fileOverwriteAskContinue(path: filePathStringFromInputField) {
            self.renderButton.isEnabled = true
            return
        }
        let outputFileURL = URL(fileURLWithPath: filePathStringFromInputField)
        removeFileAtURLIfExists(url: outputFileURL)
        
        refreshGlobalVariablesFromUI()
        // exit if no input files parsed
        if assetArray.count == 0 {
            self.renderButton.isEnabled = true
            return
        }
        
        let totalFrames = Double(assetArray.count) * secondsPerImage * Double(fps) * Double(loops)
        
        var overlayImg: NSImageRep
        var overlaySize = CGSize()
        var overlayRect = CGRect()
        var cgOverlay: CGImage?
        var overlayX = CGFloat()
        var overlayY = CGFloat()
        if (self.overlay == true) {
            overlayImg = NSImageRep(contentsOfFile: overlayFilePathField.stringValue)!
            overlaySize = CGSize(width: overlayImg.pixelsWide, height: overlayImg.pixelsHigh)
            overlayRect = CGRect(origin: CGPoint(x: 0, y: 0), size: overlaySize)
            cgOverlay = overlayImg.cgImage(forProposedRect: &overlayRect, context: NSGraphicsContext.current, hints: nil)!
            overlayX = self.outputFrameSize.width - overlaySize.width - 15
            overlayY = overlaySize.height
            
            if (overlayImg.pixelsWide > (assetArray[0].image.pixelsWide - 15) || overlayImg.pixelsHigh > assetArray[0].image.pixelsHigh) {
                let overlaySizeAlert: NSAlert = NSAlert()
                overlaySizeAlert.messageText = "Overlay image cannot be larger in width or height than the source image"
                overlaySizeAlert.addButton(withTitle: "Ok")
                overlaySizeAlert.runModal()
                return
            }
        }
        
        
        progressBar.maxValue = totalFrames
        progressBar.doubleValue = 0
        
        
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
                for frame in 1...Int(totalFrames) {
                    // Get the right image
                    if imageCounter == self.assetArray.count {
                        imageCounter = 0
                    }
                    let image = self.assetArray[imageCounter].image
                    if frame % Int(floor(Double(self.fps) * self.secondsPerImage)) == 0 {
                        imageCounter = imageCounter + 1
                    }
                    if (videoWriterInput.isReadyForMoreMediaData) {
                        let lastFrameTime = self.ntsc ? CMTimeMake(value: frameCounter * self.frameTimeValue, timescale: self.frameTimeScale) : CMTimeMake(value: frameCounter, timescale: self.frameTimeScale)
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
                            let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
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
                            usleep(useconds_t(50000))
                        } else {
                            print("Failed to allocate pixel buffer")
                            appendSucceeded = false
                        }
                    } else {print("Not ready for frame")}
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
        // parse images from the "select files" box
        assetArray = []
        outputFrameSize = CGSize(width: 0, height: 0)
        var urlArray = [String]()
        if let textFieldContent = selectedFileList.documentView as? NSTextView {
            urlArray = textFieldContent.string.components(separatedBy: "\n")
            urlArray.removeAll { $0 == "" }
            for URL in urlArray {
                let image = NSImageRep(contentsOfFile: URL)
                let asset = Asset(url: URL, image: image!)
                assetArray.append(asset)
                if outputFrameSize.width == 0 {
                    outputFrameSize.width = CGFloat(image!.pixelsWide)
                }
                if outputFrameSize.height == 0 {
                    outputFrameSize.height = CGFloat(image!.pixelsHigh)
                }
            }
        }
        // update frame rate render settings
        if fpsMenu.titleOfSelectedItem == "23.98 fps" {
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

