//
//  BrowserPickerView.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import SwiftUI

struct BrowserPickerView: View {
    let browsers: [Browser]
    let showQuickAdd: Bool
    let incognitoHoverEnabled: Bool
    let incognitoHoverDelay: Double
    let onSelect: (String, Bool) -> Void  // (browserId, isIncognito)
    let onQuickAdd: () -> Void
    let onDismiss: () -> Void

    @State private var hoveredBrowserId: String? = nil
    @State private var incognitoBrowserId: String? = nil
    @State private var hoverTimer: Timer? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Browsers that don't support incognito/private mode via CLI.
    private static let noIncognitoBrowsers: Set<String> = [
        "com.apple.Safari",
        "company.thebrowser.Browser",       // Arc
        "com.quark.desktop",                // Quark
        "org.uc.UC",                        // UC
        "net.qihoo.360browser",             // 360
        "com.duckduckgo.macos.browser",     // DuckDuckGo
        "com.kagi.kagimacOS",               // Orion
    ]

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
            ForEach(Array(browsers.enumerated()), id: \.element.id) { index, browser in
                if index > 0 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.2))
                        .frame(width: 1, height: 40)
                }

                BrowserIconButton(
                    browser: browser,
                    isHovered: hoveredBrowserId == browser.id,
                    isIncognito: incognitoBrowserId == browser.id,
                    reduceMotion: reduceMotion,
                    onHover: { hovering in
                        handleHover(browserId: browser.id, hovering: hovering)
                    },
                    onSelect: {
                        let incognito = incognitoBrowserId == browser.id
                        onSelect(browser.id, incognito)
                    }
                )
            }

            if showQuickAdd {
                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 1, height: 40)

                Button {
                    onQuickAdd()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "plus.square")
                            .font(.system(size: 24, weight: .light))
                            .frame(width: UIConstants.pickerIconSize, height: UIConstants.pickerIconSize)
                        Text("Add Rule")
                            .font(.system(size: 9))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: UIConstants.pickerItemWidth)
                .accessibilityLabel("Add Rule")
            }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: UIConstants.pickerCornerRadius, style: .continuous)
                .fill(.clear)
                .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.pickerCornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private func handleHover(browserId: String, hovering: Bool) {
        if hovering {
            let anim: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.15)
            withAnimation(anim) {
                hoveredBrowserId = browserId
            }
            // Start incognito timer if enabled and browser supports it
            if incognitoHoverEnabled && !Self.noIncognitoBrowsers.contains(browserId) {
                hoverTimer?.invalidate()
                hoverTimer = Timer.scheduledTimer(withTimeInterval: incognitoHoverDelay, repeats: false) { _ in
                    DispatchQueue.main.async {
                        let incognitoAnim: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.2)
                        withAnimation(incognitoAnim) {
                            incognitoBrowserId = browserId
                        }
                    }
                }
            }
        } else {
            let anim: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.15)
            withAnimation(anim) {
                hoveredBrowserId = nil
            }
            hoverTimer?.invalidate()
            hoverTimer = nil
            withAnimation(anim) {
                incognitoBrowserId = nil
            }
        }
    }
}

// MARK: - BrowserIconButton

private struct BrowserIconButton: View {
    let browser: Browser
    let isHovered: Bool
    let isIncognito: Bool
    let reduceMotion: Bool
    let onHover: (Bool) -> Void
    let onSelect: () -> Void

    /// Shortens browser names for the compact picker display.
    /// e.g. "Google Chrome" → "Chrome", "Microsoft Edge" → "Edge", "Brave Browser" → "Brave"
    private var shortName: String {
        let removals = ["Google ", "Microsoft ", " Browser"]
        var name = browser.name
        for word in removals {
            name = name.replacingOccurrences(of: word, with: "")
        }
        return name
    }

    var body: some View {
        VStack(spacing: 3) {
            // Browser name or "Incognito" label
            Text(isIncognito ? "Incognito" : shortName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(isIncognito ? .purple : .primary)
                .lineLimit(1)

            // Icon
            Button {
                onSelect()
            } label: {
                Group {
                    if let icon = browser.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: UIConstants.pickerIconSize, height: UIConstants.pickerIconSize)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    } else {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(.quaternary)
                            .frame(width: UIConstants.pickerIconSize, height: UIConstants.pickerIconSize)
                            .overlay {
                                Text(String(browser.name.prefix(1)))
                                    .font(.title2)
                            }
                    }
                }
                .overlay {
                    if isIncognito {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(.black.opacity(0.3))
                            .frame(width: UIConstants.pickerIconSize, height: UIConstants.pickerIconSize)
                            .overlay {
                                Image(systemName: "eyeglasses")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .scaleEffect(isHovered && !reduceMotion ? 1.15 : 1.0)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                onHover(hovering)
            }

            // Version below icon
            if let version = browser.version {
                Text(version)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: UIConstants.pickerItemWidth)
    }
}
