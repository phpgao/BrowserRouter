//
//  BrowsersSettingsView.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import SwiftUI

/// Preferences tab for reordering and hiding browsers.
/// Similar to macOS Settings — each row has a checkbox + icon + name, and supports drag-to-reorder.
struct BrowsersSettingsView: View {
    @ObservedObject var store: AppStateStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Drag to reorder. Uncheck to hide from the browser picker.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            List {
                ForEach(store.settings.browserOrder) { item in
                    if let browser = store.browser(for: item.browserId) {
                        BrowserOrderRow(
                            browser: browser,
                            isVisible: item.isVisible,
                            clickCount: store.clickStats[item.browserId] ?? 0,
                            onToggle: {
                                store.toggleBrowserVisibility(browserId: item.browserId)
                            }
                        )
                    }
                }
                .onMove { source, destination in
                    store.moveBrowser(from: source, to: destination)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            if store.clickStats.values.contains(where: { $0 > 0 }) {
                HStack {
                    Spacer()
                    Button("Reset Click Stats") {
                        store.resetClickStats()
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - BrowserOrderRow

private struct BrowserOrderRow: View {
    let browser: Browser
    let isVisible: Bool
    let clickCount: Int
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button { onToggle() } label: {
                Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isVisible ? .blue : .secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "Hide \(browser.name)" : "Show \(browser.name)")

            // Browser icon
            if let icon = browser.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: UIConstants.browserIconSize, height: UIConstants.browserIconSize)
                    .clipShape(RoundedRectangle(cornerRadius: UIConstants.browserIconCornerRadius))
            } else {
                RoundedRectangle(cornerRadius: UIConstants.browserIconCornerRadius)
                    .fill(.quaternary)
                    .frame(width: UIConstants.browserIconSize, height: UIConstants.browserIconSize)
                    .overlay {
                        Text(String(browser.name.prefix(1)))
                            .font(.headline)
                    }
            }

            // Name and version
            VStack(alignment: .leading, spacing: 2) {
                Text(browser.name)
                    .font(.body)
                    .foregroundStyle(isVisible ? .primary : .secondary)
                if let version = browser.version {
                    Text(version)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Click count
            if clickCount > 0 {
                Text("\(clickCount) clicks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // Drag handle hint
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .font(.system(size: 14))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
