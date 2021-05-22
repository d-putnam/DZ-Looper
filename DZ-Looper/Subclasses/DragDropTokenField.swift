//
//  DragDropTokenField.swift
//  DZ-Looper
//
//  Created by dp on 5/22/21.
//  Copyright © 2021 dputnam. All rights reserved.
//

import Cocoa

class DragDropTokenField: NSTokenField {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
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
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        print("UPDATED")
        return NSDragOperation()
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        print("EXITED")

        super.draggingExited(sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        print("PREPARE")

        return super.prepareForDragOperation(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        NSLog("PERFORM")

        return super.performDragOperation(sender)
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        NSLog("CONCLUDE")

        super.concludeDragOperation(sender)
    }

    override func draggingEnded(_ sender: NSDraggingInfo?) {
        NSLog("ENDED")

        super.draggingEnded(sender!)
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
