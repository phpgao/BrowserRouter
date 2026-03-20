//
//  SharedComponents.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/20.
//

import SwiftUI

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
