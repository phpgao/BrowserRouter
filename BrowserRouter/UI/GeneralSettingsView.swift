//
//  GeneralSettingsView.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var store: AppStateStore
    @State private var isDefault: Bool = false

    var body: some View {
        Form {
            // System Section
            Section("System") {
                Picker("Language", selection: languageBinding) {
                    Text("System Default").tag("")
                    Divider()
                    Text("English").tag("en")
                    Text("简体中文").tag("zh-Hans")
                    Text("繁體中文").tag("zh-Hant")
                    Text("日本語").tag("ja")
                }

                Toggle("Launch at Login", isOn: $store.settings.launchAtLogin)
                    .onChange(of: store.settings.launchAtLogin) { _ in
                        store.saveSettings()
                    }

                LabeledContent("Default Browser") {
                    HStack {
                        Button("Set as Default") {
                            setAsDefault()
                        }
                        .disabled(isDefault)
                        if isDefault {
                            Label("Currently set as default", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                }
            }

            // Fallback Behavior Section
            Section("Fallback Behavior") {
                if store.installedBrowsers.isEmpty {
                    Label("No supported browsers detected. Please install a browser.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    // Use a Picker with radioGroup style for fallback behavior
                    Picker("When no rule matches:", selection: fallbackSelection) {
                        Text("Show browser picker").tag("showPicker")
                        Text("Open in specific browser").tag("openInBrowser")
                    }
                    .pickerStyle(.radioGroup)

                    if case .openInBrowser(let currentId) = store.settings.defaultBehavior {
                        Picker("Browser:", selection: Binding(
                            get: { currentId },
                            set: { store.settings.defaultBehavior = .openInBrowser($0); store.saveSettings() }
                        )) {
                            ForEach(store.installedBrowsers) { browser in
                                Label {
                                    Text(browser.name)
                                } icon: {
                                    if let icon = browser.icon {
                                        Image(nsImage: resized(icon, to: 16))
                                    }
                                }
                                .tag(browser.id)
                            }
                        }
                        .frame(width: 240)
                    }

                    if case .showPicker = store.settings.defaultBehavior {
                        Toggle("Show quick-add rule button in picker", isOn: $store.settings.showQuickAddButton)
                            .onChange(of: store.settings.showQuickAddButton) { _ in
                                store.saveSettings()
                            }
                            .padding(.top, 4)
                    }
                }
            }

            // Incognito Hover Section
            Section("Incognito Mode") {
                Toggle("Enable hover-to-incognito in browser picker", isOn: $store.settings.incognitoHoverEnabled)
                    .onChange(of: store.settings.incognitoHoverEnabled) { _ in
                        store.saveSettings()
                    }

                if store.settings.incognitoHoverEnabled {
                    HStack {
                        Text("Hover delay:")
                        Slider(value: $store.settings.incognitoHoverDelay, in: 0.3...3.0, step: 0.1)
                            .onChange(of: store.settings.incognitoHoverDelay) { _ in
                                store.saveSettings()
                            }
                        Text(String(format: "%.1fs", store.settings.incognitoHoverDelay))
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }

                    Text("Hold your cursor over a browser icon to switch to incognito mode before clicking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Supported browsers: Chrome, Chrome Canary, Chromium, Edge, Firefox, Brave, Opera, Opera GX, Vivaldi, Yandex")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { checkIsDefault() }
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { store.settings.language },
            set: { newValue in
                store.settings.language = newValue
                store.saveSettings()
                applyLanguage(newValue)
            }
        )
    }

    private func applyLanguage(_ language: String) {
        if language.isEmpty {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
        }
        // Prompt user to restart app
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Restart Required", comment: "")
        alert.informativeText = NSLocalizedString("The language change will take effect after restarting BrowserRouter.", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("Restart Now", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Later", comment: ""))
        if alert.runModal() == .alertFirstButtonReturn {
            // Relaunch the app
            let url = Bundle.main.bundleURL
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-n", url.path]
            try? task.run()
            NSApp.terminate(nil)
        }
    }

    private var fallbackSelection: Binding<String> {
        Binding(
            get: {
                switch store.settings.defaultBehavior {
                case .showPicker: return "showPicker"
                case .openInBrowser: return "openInBrowser"
                case .doNothing: return "doNothing"
                }
            },
            set: { newValue in
                switch newValue {
                case "showPicker":
                    store.settings.defaultBehavior = .showPicker
                case "openInBrowser":
                    let first = store.installedBrowsers.first?.id ?? ""
                    store.settings.defaultBehavior = .openInBrowser(first)
                case "doNothing":
                    store.settings.defaultBehavior = .doNothing
                default: break
                }
                store.saveSettings()
            }
        )
    }

    private func checkIsDefault() {
        isDefault = BrowserManager.isDefaultBrowser()
    }

    private func setAsDefault() {
        BrowserManager.setAsDefaultBrowser { success in
            if !success {
                BrowserManager.showDefaultBrowserFailureAlert()
            }
            checkIsDefault()
        }
    }
}
