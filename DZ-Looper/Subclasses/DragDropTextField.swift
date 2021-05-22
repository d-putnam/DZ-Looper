//
//  DragDropTextField.swift
//  DZ-Looper
//
//  Created by dp on 5/22/21.
//  Copyright © 2021 dputnam. All rights reserved.
//

import Cocoa

class mp4DropField: DragDropTextField {
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboardObjects = sender.draggingPasteboard.readObjects(forClasses: [NSImage.self, NSColor.self, NSString.self, NSURL.self], options: nil), pasteboardObjects.count > 0 else { return false }
        let url = pasteboardObjects[0] as! URL
        if FileManager.default.fileExists(atPath: url.path) {
            self.stringValue = ""
            self.stringValue = (url.path as NSString).deletingPathExtension + ".mp4"
            self.selectText(NSMakeRange(self.stringValue.count-1, 1))
        }
        return true
    }
}

class overlayDropField: DragDropTextField {
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboardObjects = sender.draggingPasteboard.readObjects(forClasses: [NSImage.self, NSColor.self, NSString.self, NSURL.self], options: nil), pasteboardObjects.count > 0 else { return false }
        let url = pasteboardObjects[0] as! URL
        if NSImage(contentsOfFile: url.path) != nil {
            self.stringValue = ""
            self.stringValue = url.path
            self.selectText(NSMakeRange(self.stringValue.count-1, 1))
        }
        return true
    }
}

class DragDropTextField: NSTextField {
    
    let supportedTypes: [NSPasteboard.PasteboardType] = [.fileURL]
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.registerForDraggedTypes(supportedTypes)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let canReadPasteboardObjects = sender.draggingPasteboard.canReadObject(forClasses: [NSImage.self, NSURL.self], options: nil)
        print("draggingEntered")
        if canReadPasteboardObjects {
            highlight()
            return .copy
        }
        return NSDragOperation()
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
