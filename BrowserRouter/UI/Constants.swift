//
//  Constants.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import AppKit

/// Centralized UI constants to eliminate scattered magic numbers.
enum UIConstants {
    /// Size of browser icons in the floating picker (width & height).
    static let pickerIconSize: CGFloat = 60
    /// Width of each browser item column in the floating picker.
    static let pickerItemWidth: CGFloat = 70
    /// Corner radius of the floating picker's frosted-glass background.
    static let pickerCornerRadius: CGFloat = 22
    /// Size of browser icons in the Browsers settings list (width & height).
    static let browserIconSize: CGFloat = 32
    /// Corner radius for browser icons in the settings list.
    static let browserIconCornerRadius: CGFloat = 7
    /// Default size of the Preferences window.
    static let preferencesSize = NSSize(width: 520, height: 420)
}
