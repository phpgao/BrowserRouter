//
//  NativeTextField.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/24.
//

import AppKit
import SwiftUI

// MARK: - NativeTextField (single-line NSTextField wrapper)

/// Wraps NSTextField via NSViewRepresentable. Used instead of SwiftUI TextField
/// in sheets to avoid the multi-second UI freeze caused by macOS Services
/// discovery on text selection in LSUIElement apps.

struct NativeTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textField.bezelStyle = .roundedBezel
        textField.delegate = context.coordinator
        textField.lineBreakMode = .byTruncatingTail
        textField.cell?.usesSingleLineMode = true
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        // Keep Coordinator's Binding in sync when SwiftUI recreates the struct
        context.coordinator.text = $text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            text.wrappedValue = textField.stringValue
        }
    }
}
