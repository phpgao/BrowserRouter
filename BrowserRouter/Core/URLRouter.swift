//
//  URLRouter.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import Foundation

/// Matches URLs against ordered wildcard rules.
/// Pure computation — no UI or system dependencies, safe off MainActor.
nonisolated final class URLRouter {

    private struct CompiledRule {
        let rule: BrowserRule
        let regex: NSRegularExpression
        let isHostOnly: Bool  // true = pattern has no '/', match host only
    }

    private var compiledRules: [CompiledRule] = []

    init(rules: [BrowserRule]) throws {
        compiledRules = try rules.map { rule in
            let regex = try URLRouter.compilePattern(rule.pattern)
            let isHostOnly = !rule.pattern.contains("/")
            return CompiledRule(rule: rule, regex: regex, isHostOnly: isHostOnly)
        }
    }

    /// Updates rules (re-compiles patterns).
    func update(rules: [BrowserRule]) throws {
        compiledRules = try rules.map { rule in
            let regex = try URLRouter.compilePattern(rule.pattern)
            let isHostOnly = !rule.pattern.contains("/")
            return CompiledRule(rule: rule, regex: regex, isHostOnly: isHostOnly)
        }
    }

    /// Returns the first enabled matching rule, or nil.
    func match(_ url: URL) -> BrowserRule? {
        let normalizedFull = URLRouter.normalize(url, keepQuery: true)
        let normalizedNoQuery = URLRouter.normalize(url, keepQuery: false)
        let hostFull = String(normalizedNoQuery.split(separator: "/", maxSplits: 1).first ?? Substring(normalizedNoQuery))

        for compiled in compiledRules {
            guard compiled.rule.isEnabled else { continue }
            let hasQuery = compiled.rule.pattern.contains("?")
            let target: String
            if compiled.isHostOnly {
                target = hostFull
            } else if hasQuery {
                target = normalizedFull
            } else {
                target = normalizedNoQuery
            }
            let range = NSRange(target.startIndex..., in: target)
            if compiled.regex.firstMatch(in: target, range: range) != nil {
                return compiled.rule
            }
        }
        return nil
    }

    // MARK: - Static Helpers

    /// Tests if a single pattern matches a given URL.
    static func matches(pattern: String, url: URL) -> Bool {
        guard let regex = try? compilePattern(pattern) else { return false }
        let hasQuery = pattern.contains("?")
        let isHostOnly = !pattern.contains("/")
        let normalized = normalize(url, keepQuery: hasQuery)
        let host = String(normalize(url, keepQuery: false).split(separator: "/", maxSplits: 1).first ?? Substring(normalized))
        let target = isHostOnly ? host : normalized
        let range = NSRange(target.startIndex..., in: target)
        return regex.firstMatch(in: target, range: range) != nil
    }

    /// Strips scheme, lowercases host, optionally removes query/fragment, normalises trailing slash.
    static func normalize(_ url: URL, keepQuery: Bool = false) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = nil
        if !keepQuery {
            components?.query = nil
        }
        components?.fragment = nil

        var result = components?.string ?? url.absoluteString
        // Remove leading "//"
        if result.hasPrefix("//") { result = String(result.dropFirst(2)) }

        // Lowercase the host portion only
        if let host = url.host {
            result = result.replacingOccurrences(of: host, with: host.lowercased(), options: [], range: result.range(of: host))
        }

        // Remove trailing slash on bare host (no path)
        if result.hasSuffix("/") && result.filter({ $0 == "/" }).count == 1 {
            result = String(result.dropLast())
        }
        return result
    }

    /// Compiles a wildcard pattern to NSRegularExpression.
    /// `**` → matches any chars including / and .
    /// `*`  → matches any chars except / and .
    static func compilePattern(_ pattern: String) throws -> NSRegularExpression {
        // Escape all regex metacharacters except * which we handle specially
        var escaped = ""
        var i = pattern.startIndex
        while i < pattern.endIndex {
            let c = pattern[i]
            if c == "*" {
                let next = pattern.index(after: i)
                if next < pattern.endIndex && pattern[next] == "*" {
                    escaped += ".+"       // ** = one or more of anything (including / and .)
                    i = pattern.index(after: next)
                    continue
                } else {
                    escaped += "[^/.]+"  // * = one or more non-slash non-dot
                }
            } else if "^$+?{}()|\\[]".contains(c) {
                escaped += "\\\(c)"
            } else {
                escaped += String(c)
            }
            i = pattern.index(after: i)
        }
        return try NSRegularExpression(pattern: "^\(escaped)$", options: [])
    }

    /// Validates a pattern string. Returns an error message string if invalid, nil if valid.
    static func validate(_ pattern: String) -> String? {
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return "Pattern cannot be empty"
        }
        if pattern.contains(" ") {
            return "Pattern cannot contain spaces"
        }
        let invalidChars = CharacterSet(charactersIn: "[]{}|\\^")
        if pattern.unicodeScalars.contains(where: { invalidChars.contains($0) }) {
            return "Pattern contains invalid characters"
        }
        // Try compiling — catches any edge cases
        do {
            _ = try compilePattern(trimmed)
        } catch {
            return "Invalid pattern: \(error.localizedDescription)"
        }
        return nil
    }
}
