//
//  AddRulesSheet.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import SwiftUI

/// A single pattern entry with stable identity for safe ForEach binding.
private struct PatternEntry: Identifiable {
    let id = UUID()
    var text: String
}

struct AddRulesSheet: View {
    @ObservedObject var store: AppStateStore
    var onDismiss: () -> Void

    // For edit mode: pre-fill with existing rule
    var editingRule: BrowserRule? = nil

    @State private var entries: [PatternEntry] = [PatternEntry(text: "")]
    @State private var selectedBrowserId: String = ""
    @State private var validationError: String? = nil
    @State private var showWildcardHelp: Bool = false

    private var isEditing: Bool { editingRule != nil }

    private var nonEmptyPatterns: [String] {
        entries
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Edit Rule" : "Add Rules")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing
                     ? NSLocalizedString("URL Pattern", comment: "")
                     : NSLocalizedString("URL Patterns", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    ForEach($entries) { $entry in
                        HStack(spacing: 4) {
                            NativeTextField(
                                text: $entry.text,
                                placeholder: "*.example.com"
                            )
                            .onChange(of: entry.text) { _ in validatePatterns() }

                            if !isEditing && entries.count > 1 {
                                Button {
                                    entries.removeAll { $0.id == entry.id }
                                    validatePatterns()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !isEditing {
                        Button {
                            entries.append(PatternEntry(text: ""))
                        } label: {
                            Label("Add Pattern", systemImage: "plus.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                }
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
                    wildcardHelpContent
                }
            }

            if let error = validationError {
                ValidationErrorLabel(message: error)
            }

            Divider()

            HStack {
                Text("Open with")
                Spacer()
                BrowserMenuPicker(browsers: store.installedBrowsers, selectedBrowserId: $selectedBrowserId)
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
                .disabled(nonEmptyPatterns.isEmpty || validationError != nil || selectedBrowserId.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            if let rule = editingRule {
                entries = [PatternEntry(text: rule.pattern)]
                selectedBrowserId = rule.browserId
            } else {
                selectedBrowserId = store.installedBrowsers.first?.id ?? ""
            }
        }
    }

    // MARK: - Helpers

    private var addButtonTitle: String {
        if editingRule != nil { return NSLocalizedString("Save", comment: "") }
        let count = nonEmptyPatterns.count
        if count > 0 {
            return String(format: NSLocalizedString("Add %lld Rule(s)", comment: ""), count)
        }
        return NSLocalizedString("Add", comment: "")
    }

    private func validatePatterns() {
        for line in nonEmptyPatterns {
            if let error = URLRouter.validate(line) {
                validationError = "\"\(line)\": \(error)"
                return
            }
        }
        validationError = nil
    }

    private func submit() {
        if let rule = editingRule {
            store.updateRule(id: rule.id, pattern: nonEmptyPatterns.first ?? rule.pattern, browserId: selectedBrowserId)
        } else {
            store.addRules(patterns: nonEmptyPatterns, browserId: selectedBrowserId)
        }
        onDismiss()
    }

    // MARK: - Wildcard Help Popover

    @ViewBuilder
    private var wildcardHelpContent: some View {
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
