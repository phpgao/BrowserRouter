//
//  NSImage+Resize.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import AppKit

extension NSImage {
    /// Returns a new image resized to a square of the given point size.
    /// Uses modern drawing API instead of deprecated lockFocus/unlockFocus.
    func resized(to size: CGFloat) -> NSImage {
        let newSize = NSSize(width: size, height: size)
        let resizedImage = NSImage(size: newSize, flipped: false) { rect in
            self.draw(in: rect,
                      from: NSRect(origin: .zero, size: self.size),
                      operation: .sourceOver,
                      fraction: 1.0)
            return true
        }
        resizedImage.isTemplate = self.isTemplate
        return resizedImage
    }
}
