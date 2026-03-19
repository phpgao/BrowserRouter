//
//  Browser.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import AppKit

struct Browser: Identifiable, Equatable {
    let id: String        // Bundle ID, e.g. "com.google.Chrome"
    let name: String      // Display name
    let version: String?  // From Info.plist; nil if unavailable
    let icon: NSImage?    // From NSWorkspace

    static func == (lhs: Browser, rhs: Browser) -> Bool {
        lhs.id == rhs.id
    }
}
