//
//  RulesListView.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import SwiftUI
import UniformTypeIdentifiers

struct RulesListView: View {
    @ObservedObject var store: AppStateStore
    @State private var showAddSheet = false
    @State private var editingRule: BrowserRule? = nil
    @State private var testURL: String = ""
    @State private var matchedRuleIds: Set<UUID>? = nil  // nil = not filtering
    @State private var selection: Set<UUID> = []
    @State private var filterBrowserId: String? = nil  // nil = show all
    @State private var showDeleteConfirm = false
    @State private var importFileURL: ImportFileURL? = nil
    @State private var importResultMessage: String? = nil

    private var isFiltering: Bool { matchedRuleIds != nil }

    /// Rules after applying browser filter and URL match filter.
    private var displayRules: [BrowserRule] {
        var result = store.rules

        // Browser filter
        if let browserId = filterBrowserId {
            result = result.filter { $0.browserId == browserId }
        }

        // URL match filter
        if let ids = matchedRuleIds {
            result = result.filter { ids.contains($0.id) }
        }

        return result
    }

    /// Whether any filter (browser or URL match) is active.
    private var hasActiveFilter: Bool {
        filterBrowserId != nil || matchedRuleIds != nil
    }

    /// Unique browser IDs used by current rules, for the filter picker.
    private var browserIdsInRules: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for rule in store.rules {
            if seen.insert(rule.browserId).inserted {
                result.append(rule.browserId)
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            HStack {
                Text("URL Rules")
                    .font(.headline)
                Spacer()

                Button {
                    showAddSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // MARK: - Toolbar: Test URL + Browser Filter
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                TextField("Test URL...", text: $testURL)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .onSubmit { runMatch() }

                if !testURL.isEmpty {
                    Button {
                        testURL = ""
                        matchedRuleIds = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }

                Button("Match") { runMatch() }
                    .controlSize(.small)
                    .disabled(testURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.textBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal)
            .padding(.bottom, 6)

            // Browser filter
            if browserIdsInRules.count > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))

                    Text(NSLocalizedString("Filter by browser:", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: Binding(
                        get: { filterBrowserId ?? "__all__" },
                        set: { filterBrowserId = $0 == "__all__" ? nil : $0 }
                    )) {
                        Text(NSLocalizedString("All", comment: "")).tag("__all__")
                        ForEach(browserIdsInRules, id: \.self) { browserId in
                            let browser = store.browser(for: browserId)
                            Label {
                                Text(browser?.name ?? browserId)
                            } icon: {
                                if let icon = browser?.icon {
                                    Image(nsImage: icon.resized(to: 14))
                                }
                            }
                            .tag(browserId)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .frame(maxWidth: 180)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            // Match result hint
            if let ids = matchedRuleIds {
                HStack(spacing: 4) {
                    Image(systemName: ids.isEmpty ? "exclamationmark.triangle" : "checkmark.circle")
                        .foregroundStyle(ids.isEmpty ? .orange : .green)
                        .font(.caption)
                    Text(ids.isEmpty
                         ? NSLocalizedString("No rules matched this URL.", comment: "")
                         : String(format: NSLocalizedString("%lld rule(s) matched. Reorder disabled during filtering.", comment: ""), ids.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            Divider()

            // MARK: - Rule List
            if store.rules.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No rules yet")
                        .foregroundStyle(.secondary)
                    Text("Click + Add to create URL routing rules.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(displayRules) { rule in
                        if let idx = store.rules.firstIndex(where: { $0.id == rule.id }) {
                            let browser = store.browser(for: rule.browserId)
                            RuleRow(
                                rule: $store.rules[idx],
                                browserName: browser?.name ?? rule.browserId,
                                browserIcon: browser?.icon,
                                isHighlighted: matchedRuleIds != nil,
                                isBrowserInvalid: browser == nil,
                                onToggle: { store.saveRules() },
                                onEdit: { editingRule = rule },
                                onDelete: {
                                    deleteRule(rule)
                                }
                            )
                            .tag(rule.id)
                            .contextMenu {
                                contextMenuContent(for: rule)
                            }
                        }
                    }
                    .onMove { source, dest in
                        if !hasActiveFilter {
                            store.moveRule(from: source, to: dest)
                        }
                    }
                }
                .onDeleteCommand {
                    if !selection.isEmpty {
                        showDeleteConfirm = true
                    }
                }
            }

            Divider()

            // MARK: - Footer
            HStack(spacing: 8) {
                // Select All / Deselect All
                if !store.rules.isEmpty {
                    let allDisplayIds = Set(displayRules.map { $0.id })
                    let allSelected = !allDisplayIds.isEmpty && allDisplayIds.isSubset(of: selection)

                    Button {
                        if allSelected {
                            selection.subtract(allDisplayIds)
                        } else {
                            selection.formUnion(allDisplayIds)
                        }
                    } label: {
                        Text(allSelected
                             ? NSLocalizedString("Deselect All", comment: "")
                             : NSLocalizedString("Select All", comment: ""))
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }

                Text(hasActiveFilter
                     ? NSLocalizedString("Filtering — clear URL to reorder", comment: "")
                     : NSLocalizedString("Drag to reorder ↕", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Export / Import
                Button {
                    exportRules()
                } label: {
                    Label(NSLocalizedString("Export", comment: ""), systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .disabled(store.rules.isEmpty)
                .accessibilityLabel(NSLocalizedString("Export Rules", comment: ""))

                Button {
                    openImportPanel()
                } label: {
                    Label(NSLocalizedString("Import", comment: ""), systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .accessibilityLabel(NSLocalizedString("Import Rules", comment: ""))

                if !selection.isEmpty {
                    Text(String(format: NSLocalizedString("%lld selected", comment: ""), selection.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(
                            NSLocalizedString("Delete", comment: ""),
                            systemImage: "trash"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showAddSheet) {
            AddRulesSheet(store: store, onDismiss: { showAddSheet = false })
        }
        .sheet(item: $editingRule) { rule in
            AddRulesSheet(store: store, onDismiss: { editingRule = nil }, editingRule: rule)
        }
        .alert(
            NSLocalizedString("Confirm Deletion", comment: ""),
            isPresented: $showDeleteConfirm
        ) {
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
            Button(
                String(format: NSLocalizedString("Delete %lld Rules", comment: ""), selection.count),
                role: .destructive
            ) {
                deleteSelected()
            }
        } message: {
            Text(String(format: NSLocalizedString("Are you sure you want to delete %lld selected rules? This cannot be undone.", comment: ""), selection.count))
        }
        .sheet(item: $importFileURL) { item in
            ImportRulesSheet(store: store, fileURL: item.url, onDismiss: { message in
                importFileURL = nil
                importResultMessage = message
            })
        }
        .alert(
            NSLocalizedString("Import Complete", comment: ""),
            isPresented: Binding(
                get: { importResultMessage != nil },
                set: { if !$0 { importResultMessage = nil } }
            )
        ) {
            Button("OK") { importResultMessage = nil }
        } message: {
            if let msg = importResultMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuContent(for rule: BrowserRule) -> some View {
        if selection.count > 1 && selection.contains(rule.id) {
            // Multi-selection context menu
            Button {
                setSelectedEnabled(true)
            } label: {
                Text(String(format: NSLocalizedString("Enable %lld Rules", comment: ""), selection.count))
            }
            Button {
                setSelectedEnabled(false)
            } label: {
                Text(String(format: NSLocalizedString("Disable %lld Rules", comment: ""), selection.count))
            }
            Divider()
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Text(String(format: NSLocalizedString("Delete %lld Rules", comment: ""), selection.count))
            }
        } else {
            // Single-rule context menu
            if let idx = store.rules.firstIndex(where: { $0.id == rule.id }) {
                Button {
                    store.rules[idx].isEnabled.toggle()
                    store.saveRules()
                } label: {
                    Text(rule.isEnabled
                         ? NSLocalizedString("Disable", comment: "")
                         : NSLocalizedString("Enable", comment: ""))
                }
            }
            Button(NSLocalizedString("Edit…", comment: "")) {
                editingRule = rule
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(rule.pattern, forType: .string)
            } label: {
                Text(NSLocalizedString("Copy Pattern", comment: ""))
            }
            Divider()
            Button(NSLocalizedString("Delete", comment: ""), role: .destructive) {
                deleteRule(rule)
            }
        }
    }

    // MARK: - Actions

    private func deleteRule(_ rule: BrowserRule) {
        if let idx = store.rules.firstIndex(where: { $0.id == rule.id }) {
            store.rules.remove(at: idx)
            store.saveRules()
            if isFiltering { runMatch() }
        }
    }

    private func deleteSelected() {
        guard !selection.isEmpty else { return }
        store.rules.removeAll { selection.contains($0.id) }
        store.saveRules()
        selection.removeAll()
        if isFiltering { runMatch() }
    }

    private func setSelectedEnabled(_ enabled: Bool) {
        for i in store.rules.indices where selection.contains(store.rules[i].id) {
            store.rules[i].isEnabled = enabled
        }
        store.saveRules()
    }

    private func runMatch() {
        let trimmed = testURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            matchedRuleIds = nil
            return
        }

        // Try to parse as URL, add scheme if missing
        let urlString = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? trimmed
            : "https://\(trimmed)"

        guard let url = URL(string: urlString) else {
            matchedRuleIds = Set()
            return
        }

        var ids = Set<UUID>()
        for rule in store.rules {
            if URLRouter.matches(pattern: rule.pattern, url: url) {
                ids.insert(rule.id)
            }
        }
        matchedRuleIds = ids
    }

    // MARK: - Export / Import

    private func exportRules() {
        let panel = NSSavePanel()
        panel.title = NSLocalizedString("Export Rules", comment: "")
        panel.nameFieldStringValue = "BrowserRouter-Rules.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportRules(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func openImportPanel() {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("Import Rules", comment: "")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFileURL = ImportFileURL(url: url)
    }
}

// MARK: - RuleRow

private struct RuleRow: View {
    @Binding var rule: BrowserRule
    let browserName: String
    let browserIcon: NSImage?
    let isHighlighted: Bool
    let isBrowserInvalid: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $rule.isEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .onChange(of: rule.isEnabled) { _ in onToggle() }

            if isHighlighted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 12))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.pattern)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(rule.isEnabled ? .primary : .secondary)
                HStack(spacing: 4) {
                    Text("→")
                    if isBrowserInvalid {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 10))
                    }
                    if let icon = browserIcon {
                        Image(nsImage: icon.resized(to: 14))
                    }
                    Text(browserName)
                        .foregroundStyle(isBrowserInvalid ? .red : .secondary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button { onEdit() } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit rule")

            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete rule")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Import Rules Sheet

private struct ImportRulesSheet: View {
    @ObservedObject var store: AppStateStore
    let fileURL: URL
    let onDismiss: (String?) -> Void  // pass result message

    @State private var mode: AppStateStore.ImportMode = .merge

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("Import Rules", comment: ""))
                .font(.headline)

            Text(fileURL.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Import mode
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Import Mode", comment: ""))
                    .font(.subheadline)

                Picker("", selection: $mode) {
                    Text(NSLocalizedString("Merge", comment: "Import mode: merge"))
                        .tag(AppStateStore.ImportMode.merge)
                    Text(NSLocalizedString("Replace", comment: "Import mode: replace"))
                        .tag(AppStateStore.ImportMode.replace)
                }
                .pickerStyle(.segmented)

                Text(mode == .merge
                     ? NSLocalizedString("Keep existing rules and add new ones (duplicates skipped).", comment: "")
                     : NSLocalizedString("Remove all existing rules and import.", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text(NSLocalizedString("Rules targeting browsers not installed on this Mac will be automatically disabled.", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Button(NSLocalizedString("Cancel", comment: "")) { onDismiss(nil) }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(NSLocalizedString("Import", comment: "")) { performImport() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400, height: 280)
    }

    private func performImport() {
        do {
            let result = try store.importRules(from: fileURL, mode: mode)
            var parts: [String] = []
            parts.append(String(format: NSLocalizedString("%lld rule(s) imported.", comment: ""), result.importedCount))
            if result.skippedCount > 0 {
                parts.append(String(format: NSLocalizedString("%lld duplicate(s) skipped.", comment: ""), result.skippedCount))
            }
            onDismiss(parts.joined(separator: " "))
        } catch {
            onDismiss(error.localizedDescription)
        }
    }
}

// MARK: - Identifiable URL wrapper for sheet(item:)

private struct ImportFileURL: Identifiable {
    let id = UUID()
    let url: URL
}
