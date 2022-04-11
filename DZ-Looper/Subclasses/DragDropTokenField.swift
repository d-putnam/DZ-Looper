//
//  DragDropTokenField.swift
//  DZ-Looper
//
//  Created by dp on 5/22/21.
//  Copyright © 2021 dputnam. All rights reserved.
//

import Cocoa

class DragDropTokenField: NSTokenField {
    
    let supportedTypes: [NSPasteboard.PasteboardType] = [.fileURL]
    
    var assets: [Asset] = []
    
    func returnAssets() -> [Asset] {
        return assets
    }
    
    func appendAsset(asset: Asset) {
        var flag = false
        for assetSource in assets {
            if assetSource.name == asset.name {
                flag = true
            }
        }
        if flag == false {
            assets.append(asset)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.registerForDraggedTypes(supportedTypes)
    }
        
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let canReadPasteboardObjects = sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: nil)
        if canReadPasteboardObjects {
            highlight()
            return .copy
        }
        return NSDragOperation()
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation()
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        unhighlight()
        guard let pasteboardObjects = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil), pasteboardObjects.count > 0 else { return false }
        var labelArray = [String]()
        if (self.objectValue as? [String] != nil) {
            let original_array = self.objectValue as! [String]
            for obj in original_array {
                labelArray.append(obj)
            }
        }
        for object in pasteboardObjects {
            let url = object as! URL
            let asset = Asset(url: url, image: NSImageRep(contentsOf: url)!)
            appendAsset(asset: asset)
            labelArray.append(asset.name)
        }
        self.objectValue = labelArray

        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        unhighlight()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        unhighlight()
    }
     
    override func draggingExited(_ sender: NSDraggingInfo?) {
        unhighlight()
    }
    
    func highlight() {
        self.layer?.borderColor = NSColor.controlAccentColor.cgColor
        self.layer?.borderWidth = 2.0
    }
    
    func unhighlight() {
        self.layer?.borderColor = NSColor.clear.cgColor
        self.layer?.borderWidth = 0.0
    }
}
