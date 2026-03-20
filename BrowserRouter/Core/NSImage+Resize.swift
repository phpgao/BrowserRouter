//
//  NSImage+Resize.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import AppKit

/// Cache for resized images, keyed by "objectIdentifier-WxH".
private nonisolated(unsafe) let resizedImageCache = NSCache<NSString, NSImage>()

extension NSImage {
    /// Returns a new image resized to a square of the given point size.
    /// Results are cached by image identity + size to avoid redundant drawing.
    /// Uses modern drawing API instead of deprecated lockFocus/unlockFocus.
    func resized(to size: CGFloat) -> NSImage {
        let cacheKey = "\(ObjectIdentifier(self))-\(size)" as NSString
        if let cached = resizedImageCache.object(forKey: cacheKey) {
            return cached
        }

        let newSize = NSSize(width: size, height: size)
        let resizedImage = NSImage(size: newSize, flipped: false) { rect in
            self.draw(in: rect,
                      from: NSRect(origin: .zero, size: self.size),
                      operation: .sourceOver,
                      fraction: 1.0)
            return true
        }
        resizedImage.isTemplate = self.isTemplate
        resizedImageCache.setObject(resizedImage, forKey: cacheKey)
        return resizedImage
    }
}
