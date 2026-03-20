//
//  QuickAddRuleSheet.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import SwiftUI

struct QuickAddRuleSheet: View {
    let url: URL
    let browsers: [Browser]
    let onSave: (String, String) -> Void  // (pattern, browserId)
    let onCancel: () -> Void

    @State private var pattern: String = ""
    @State private var selectedBrowserId: String = ""
    @State private var validationError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Rule for this URL")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Pattern")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Pattern", text: $pattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: pattern) { _ in
                        if let error = URLRouter.validate(pattern) {
                            validationError = error
                        } else {
                            validationError = nil
                        }
                    }
            }

            if let error = validationError {
                ValidationErrorLabel(message: error)
            }

            Picker("Open with", selection: $selectedBrowserId) {
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

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Add") {
                    onSave(pattern, selectedBrowserId)
                }
                .keyboardShortcut(.return)
                .disabled(pattern.isEmpty || validationError != nil || selectedBrowserId.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            // Pre-fill pattern from URL host
            if let host = url.host {
                let components = host.split(separator: ".")
                if components.count > 2 {
                    // e.g. app.github.com → *.github.com
                    pattern = "*." + components.dropFirst().joined(separator: ".")
                } else {
                    pattern = host
                }
            }
            selectedBrowserId = browsers.first?.id ?? ""
        }
    }
}
