//
//  AddRulesSheet.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import SwiftUI

struct AddRulesSheet: View {
    @ObservedObject var store: AppStateStore
    var onDismiss: () -> Void

    // For edit mode: pre-fill with existing rule
    var editingRule: BrowserRule? = nil

    @State private var patternsText: String = ""
    @State private var selectedBrowserId: String = ""
    @State private var validationError: String? = nil
    @State private var showWildcardHelp: Bool = false

    private var isEditing: Bool { editingRule != nil }

    private var nonEmptyLines: [String] {
        if isEditing {
            let trimmed = patternsText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }
        return patternsText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Edit Rule" : "Add Rules")
                .font(.headline)

            if isEditing {
                Text(NSLocalizedString("URL Pattern", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("*.example.com", text: $patternsText)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: patternsText) { _ in validatePatterns() }
            } else {
                Text("URL Patterns (one per line)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $patternsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .border(Color(.separatorColor))
                    .onChange(of: patternsText) { _ in validatePatterns() }
            }

            HStack(spacing: 4) {
                Text("Supports wildcards: * (single label) and ** (multi-level)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showWildcardHelp.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showWildcardHelp, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Wildcard Reference")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text("*  — matches a single level (no `.` or `/`)")
                                    .font(.callout)
                            } icon: {
                                Text("✦").font(.caption)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("*.foo.com").font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                                    Text("→").font(.caption).foregroundStyle(.secondary)
                                    Text("bar.foo.com").font(.system(.caption, design: .monospaced))
                                    Image(systemName: "checkmark").font(.caption2).foregroundStyle(.green)
                                }
                                HStack(spacing: 4) {
                                    Text("*.foo.com").font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                                    Text("→").font(.caption).foregroundStyle(.secondary)
                                    Text("a.b.foo.com").font(.system(.caption, design: .monospaced))
                                    Image(systemName: "xmark").font(.caption2).foregroundStyle(.red)
                                }
                            }
                            .padding(.leading, 24)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text("** — matches multiple levels (including `.` and `/`)")
                                    .font(.callout)
                            } icon: {
                                Text("✦").font(.caption)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("**.foo.com").font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                                    Text("→").font(.caption).foregroundStyle(.secondary)
                                    Text("bar.foo.com").font(.system(.caption, design: .monospaced))
                                    Image(systemName: "checkmark").font(.caption2).foregroundStyle(.green)
                                }
                                HStack(spacing: 4) {
                                    Text("**.foo.com").font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                                    Text("→").font(.caption).foregroundStyle(.secondary)
                                    Text("a.b.c.foo.com").font(.system(.caption, design: .monospaced))
                                    Image(systemName: "checkmark").font(.caption2).foregroundStyle(.green)
                                }
                            }
                            .padding(.leading, 24)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text("Path matching — use `/` to match URL paths")
                                    .font(.callout)
                            } icon: {
                                Text("✦").font(.caption)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("*.foo.com/bar").font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                                    Text("→").font(.caption).foregroundStyle(.secondary)
                                    Text("x.foo.com/bar").font(.system(.caption, design: .monospaced))
                                    Image(systemName: "checkmark").font(.caption2).foregroundStyle(.green)
                                }
                                HStack(spacing: 4) {
                                    Text("*.foo.com/bar").font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                                    Text("→").font(.caption).foregroundStyle(.secondary)
                                    Text("x.foo.com/bar/baz").font(.system(.caption, design: .monospaced))
                                    Image(systemName: "xmark").font(.caption2).foregroundStyle(.red)
                                }
                                HStack(spacing: 4) {
                                    Text("*.foo.com/bar**").font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                                    Text("→").font(.caption).foregroundStyle(.secondary)
                                    Text("x.foo.com/bar/baz").font(.system(.caption, design: .monospaced))
                                    Image(systemName: "checkmark").font(.caption2).foregroundStyle(.green)
                                }
                            }
                            .padding(.leading, 24)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text("Query matching — use `?` to match query parameters")
                                    .font(.callout)
                            } icon: {
                                Text("✦").font(.caption)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("*.foo.com/bar").font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                                    Text("→").font(.caption).foregroundStyle(.secondary)
                                    Text(".../bar?id=1").font(.system(.caption, design: .monospaced))
                                    Image(systemName: "checkmark").font(.caption2).foregroundStyle(.green)
                                }
                                Text("Without `?`, query params are ignored")
                                    .font(.caption2).foregroundStyle(.secondary).italic()

                                HStack(spacing: 4) {
                                    Text("*.foo.com/bar?id=**").font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                                    Text("→").font(.caption).foregroundStyle(.secondary)
                                    Text(".../bar?id=123").font(.system(.caption, design: .monospaced))
                                    Image(systemName: "checkmark").font(.caption2).foregroundStyle(.green)
                                }
                                HStack(spacing: 4) {
                                    Text("*.foo.com/bar?id=**").font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                                    Text("→").font(.caption).foregroundStyle(.secondary)
                                    Text(".../bar?x=1").font(.system(.caption, design: .monospaced))
                                    Image(systemName: "xmark").font(.caption2).foregroundStyle(.red)
                                }
                            }
                            .padding(.leading, 24)
                        }

                        Divider()

                        Text("Tip: Use `**` at the end of a path to match all sub-paths and params.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(width: 380)
                }
            }

            if let error = validationError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Divider()

            HStack {
                Text("Open with")
                Spacer()
                Picker("", selection: $selectedBrowserId) {
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
                .pickerStyle(.menu)
                .frame(width: 200)
            }

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button(addButtonTitle) {
                    submit()
                }
                .keyboardShortcut(.return)
                .disabled(nonEmptyLines.isEmpty || validationError != nil || selectedBrowserId.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            if let rule = editingRule {
                patternsText = rule.pattern
                selectedBrowserId = rule.browserId
            } else {
                selectedBrowserId = store.installedBrowsers.first?.id ?? ""
            }
        }
    }

    private var addButtonTitle: String {
        if editingRule != nil { return NSLocalizedString("Save", comment: "") }
        let count = nonEmptyLines.count
        if count > 0 {
            return String(format: NSLocalizedString("Add %lld Rule(s)", comment: ""), count)
        }
        return NSLocalizedString("Add", comment: "")
    }

    private func validatePatterns() {
        for line in nonEmptyLines {
            if let error = URLRouter.validate(line) {
                validationError = "\"\(line)\": \(error)"
                return
            }
        }
        validationError = nil
    }

    private func submit() {
        if let rule = editingRule {
            // Edit mode — update existing rule in place
            if let idx = store.rules.firstIndex(where: { $0.id == rule.id }) {
                store.rules[idx].pattern = nonEmptyLines.first ?? rule.pattern
                store.rules[idx].browserId = selectedBrowserId
                store.saveRules()
            }
        } else {
            store.addRules(patterns: nonEmptyLines, browserId: selectedBrowserId)
        }
        onDismiss()
    }
}
