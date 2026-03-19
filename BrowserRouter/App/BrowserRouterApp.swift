//
//  BrowserRouterApp.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import SwiftUI

@main
struct BrowserRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window scene — app lives in status bar only
        Settings { EmptyView() }
    }
}
