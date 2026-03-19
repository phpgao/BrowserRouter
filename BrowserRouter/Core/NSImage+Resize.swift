//
//  NSImage+Resize.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import AppKit

/// Resize an NSImage to a square of the given point size, suitable for Picker menu items.
func resized(_ image: NSImage, to size: CGFloat) -> NSImage {
    let newSize = NSSize(width: size, height: size)
    let resizedImage = NSImage(size: newSize)
    resizedImage.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: newSize),
               from: NSRect(origin: .zero, size: image.size),
               operation: .sourceOver,
               fraction: 1.0)
    resizedImage.unlockFocus()
    resizedImage.isTemplate = image.isTemplate
    return resizedImage
}
