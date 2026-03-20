//
//  SharedComponents.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/20.
//

import SwiftUI
import AppKit
import Combine

// MARK: - PickerKeyboardHandler

/// Bridges keyboard events from NSEvent monitor to SwiftUI BrowserPickerView.
@MainActor
final class PickerKeyboardHandler: ObservableObject {
    @Published var selectedIndex: Int? = nil
    let browserCount: Int

    init(browserCount: Int) {
        self.browserCount = browserCount
    }

    /// Returns true if the event was handled.
    func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123: // Left arrow
            moveSelection(by: -1)
            return true
        case 124: // Right arrow
            moveSelection(by: 1)
            return true
        case 36, 76: // Return / Enter
            return selectedIndex != nil  // caller handles the selection
        default:
            // Number keys 1-9
            if let chars = event.charactersIgnoringModifiers,
               let digit = Int(chars), digit >= 1, digit <= min(9, browserCount) {
                selectedIndex = digit - 1
                return true  // caller handles the selection
            }
            return false
        }
    }

    private func moveSelection(by offset: Int) {
        guard browserCount > 0 else { return }
        let current = selectedIndex ?? (offset > 0 ? -1 : browserCount)
        let next = current + offset
        if next >= 0 && next < browserCount {
            selectedIndex = next
        }
    }
}

// MARK: - BrowserMenuPicker

/// Reusable browser picker (menu style) used in AddRulesSheet, QuickAddRuleSheet, GeneralSettingsView.
struct BrowserMenuPicker: View {
    let browsers: [Browser]
    @Binding var selectedBrowserId: String

    var body: some View {
        Picker("", selection: $selectedBrowserId) {
            ForEach(browsers) { browser in
                Label {
                    Text(browser.name)
                } icon: {
                    if let icon = browser.icon {
                        Image(nsImage: icon.resized(to: 16))
                    }
                }
                .tag(browser.id)
            }
        }
        .pickerStyle(.menu)
    }
}

// MARK: - BrowserIconView

/// Browser icon with fallback initial letter, used in BrowserPickerView and BrowsersSettingsView.
struct BrowserIconView: View {
    let icon: NSImage?
    let name: String
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.quaternary)
                .frame(width: size, height: size)
                .overlay {
                    Text(String(name.prefix(1)))
                        .font(size > 40 ? .title2 : .headline)
                }
        }
    }
}

// MARK: - ValidationErrorLabel

/// Red validation error label with warning icon, used in AddRulesSheet and QuickAddRuleSheet.
struct ValidationErrorLabel: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .font(.caption)
    }
}
