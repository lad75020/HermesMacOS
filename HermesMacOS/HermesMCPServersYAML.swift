//
//  HermesMCPServersYAML.swift
//  HermesMacOS
//

import Foundation

enum HermesMCPServersYAML {
    static func parseServers(from yaml: String) -> [HermesDashboardMCPServer] {
        let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { isTopLevelKey($0, key: "mcp_servers") }) else { return [] }
        if lines[start].trimmingCharacters(in: .whitespacesAndNewlines) == "mcp_servers: {}" { return [] }
        let end = nextTopLevelIndex(in: lines, after: start) ?? lines.count
        guard start + 1 < end else { return [] }
        var servers: [HermesDashboardMCPServer] = []
        var index = start + 1
        while index < end {
            let line = lines[index]
            guard indentation(of: line) == 2, let name = mappingKey(from: line) else {
                index += 1
                continue
            }
            let blockStart = index
            var blockEnd = index + 1
            while blockEnd < end {
                let candidate = lines[blockEnd]
                if !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   indentation(of: candidate) == 2,
                   mappingKey(from: candidate) != nil {
                    break
                }
                blockEnd += 1
            }
            let block = Array(lines[blockStart..<blockEnd])
            servers.append(server(named: name, block: block))
            index = blockEnd
        }
        return servers
    }

    static func removingServer(named name: String, from yaml: String) throws -> String {
        var lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let hadTrailingNewline = yaml.hasSuffix("\n")
        guard let start = lines.firstIndex(where: { isTopLevelKey($0, key: "mcp_servers") }) else {
            throw HermesDashboardMCPServersError.serverNotFound(name)
        }
        let end = nextTopLevelIndex(in: lines, after: start) ?? lines.count
        var index = start + 1
        while index < end {
            guard indentation(of: lines[index]) == 2, let serverName = mappingKey(from: lines[index]) else {
                index += 1
                continue
            }
            var blockEnd = index + 1
            while blockEnd < end {
                let candidate = lines[blockEnd]
                if !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   indentation(of: candidate) == 2,
                   mappingKey(from: candidate) != nil {
                    break
                }
                blockEnd += 1
            }
            if serverName == name {
                lines.removeSubrange(index..<blockEnd)
                let newEnd = end - (blockEnd - index)
                let hasRemainingServer = lines[(start + 1)..<newEnd].contains { indentation(of: $0) == 2 && mappingKey(from: $0) != nil }
                if !hasRemainingServer {
                    lines[start] = "mcp_servers: {}"
                }
                return joined(lines, trailingNewline: hadTrailingNewline)
            }
            index = blockEnd
        }
        throw HermesDashboardMCPServersError.serverNotFound(name)
    }

    static func upsertingServer(_ server: HermesDashboardMCPServer, in yaml: String) -> String {
        var lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let hadTrailingNewline = yaml.hasSuffix("\n")
        let block = serializedBlock(for: server)
        guard let start = lines.firstIndex(where: { isTopLevelKey($0, key: "mcp_servers") }) else {
            if !lines.isEmpty, lines.last == "" { lines.removeLast() }
            if !lines.isEmpty { lines.append("") }
            lines.append("mcp_servers:")
            lines.append(contentsOf: block)
            return joined(lines, trailingNewline: hadTrailingNewline || yaml.isEmpty)
        }
        if lines[start].trimmingCharacters(in: .whitespacesAndNewlines) == "mcp_servers: {}" {
            lines[start] = "mcp_servers:"
            lines.insert(contentsOf: block, at: start + 1)
            return joined(lines, trailingNewline: hadTrailingNewline)
        }
        let end = nextTopLevelIndex(in: lines, after: start) ?? lines.count
        var index = start + 1
        while index < end {
            guard indentation(of: lines[index]) == 2, let serverName = mappingKey(from: lines[index]) else {
                index += 1
                continue
            }
            var blockEnd = index + 1
            while blockEnd < end {
                let candidate = lines[blockEnd]
                if !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   indentation(of: candidate) == 2,
                   mappingKey(from: candidate) != nil {
                    break
                }
                blockEnd += 1
            }
            if serverName == server.name {
                lines.replaceSubrange(index..<blockEnd, with: block)
                return joined(lines, trailingNewline: hadTrailingNewline)
            }
            index = blockEnd
        }
        lines.insert(contentsOf: block, at: end)
        return joined(lines, trailingNewline: hadTrailingNewline)
    }

    static func server(named name: String, block: [String]) -> HermesDashboardMCPServer {
        let command = scalarValue(for: "command", in: block)
        let url = scalarValue(for: "url", in: block)
        let disabled = boolValue(for: "disabled", in: block) == true || boolValue(for: "enabled", in: block) == false
        let args = arrayValue(for: "args", in: block)
        let auth = scalarValue(for: "auth", in: block)
        let env = mappingValue(for: "env", in: block)
        let headers = mappingValue(for: "headers", in: block)
        let include = nestedArrayValue(parent: "tools", key: "include", in: block)
        let exclude = nestedArrayValue(parent: "tools", key: "exclude", in: block)
        return HermesDashboardMCPServer(name: name, command: command, args: args, url: url, disabled: disabled, auth: auth, env: env, headers: headers, toolsInclude: include, toolsExclude: exclude)
    }

    static func serializedBlock(for server: HermesDashboardMCPServer) -> [String] {
        var lines = ["  \(quoteKey(server.name)):"]
        lines.append("    enabled: \(!server.disabled ? "true" : "false")")
        if let url = server.url, !url.isEmpty {
            lines.append("    url: \(quoted(url))")
        } else if let command = server.command, !command.isEmpty {
            lines.append("    command: \(quoted(command))")
            if !server.args.isEmpty { appendArray(server.args, key: "args", indent: 4, to: &lines) }
        }
        if let auth = server.auth, !auth.isEmpty { lines.append("    auth: \(quoted(auth))") }
        if !server.env.isEmpty { appendMapping(server.env, key: "env", indent: 4, to: &lines) }
        if !server.headers.isEmpty { appendMapping(server.headers, key: "headers", indent: 4, to: &lines) }
        if server.toolsInclude != nil || server.toolsExclude != nil {
            lines.append("    tools:")
            if let include = server.toolsInclude { appendArray(include, key: "include", indent: 6, to: &lines) }
            if let exclude = server.toolsExclude { appendArray(exclude, key: "exclude", indent: 6, to: &lines) }
        }
        return lines
    }

    static func scalarValue(for key: String, in block: [String]) -> String? {
        for line in block {
            guard indentation(of: line) == 4 else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            let raw = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty || raw == "{}" { return nil }
            return unquoted(raw)
        }
        return nil
    }

    static func boolValue(for key: String, in block: [String]) -> Bool? {
        guard let value = scalarValue(for: key, in: block)?.lowercased() else { return nil }
        if ["true", "yes", "on", "1"].contains(value) { return true }
        if ["false", "no", "off", "0"].contains(value) { return false }
        return nil
    }

    static func arrayValue(for key: String, in block: [String]) -> [String] {
        for (offset, line) in block.enumerated() {
            guard indentation(of: line) == 4 else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            return parseArray(after: key, offset: offset, indent: 4, in: block) ?? []
        }
        return []
    }

    static func nestedArrayValue(parent: String, key: String, in block: [String]) -> [String]? {
        guard let parentOffset = block.firstIndex(where: { indentation(of: $0) == 4 && $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(parent):") }) else { return nil }
        var index = parentOffset + 1
        while index < block.count {
            let line = block[index]
            if indentation(of: line) <= 4 { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if indentation(of: line) == 6, trimmed.hasPrefix("\(key):") {
                return parseArray(after: key, offset: index, indent: 6, in: block) ?? []
            }
            index += 1
        }
        return nil
    }

    static func parseArray(after key: String, offset: Int, indent: Int, in block: [String]) -> [String]? {
        let line = block[offset]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("\(key):") else { return nil }
        let raw = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("["), raw.hasSuffix("]") {
            let body = String(raw.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            if body.isEmpty { return [] }
            return splitInlineArray(body).map { unquoted($0.trimmingCharacters(in: .whitespacesAndNewlines)) }.filter { !$0.isEmpty }
        }
        var values: [String] = []
        var index = offset + 1
        while index < block.count {
            let candidate = block[index]
            let trimmedCandidate = candidate.trimmingCharacters(in: .whitespaces)
            if indentation(of: candidate) <= indent { break }
            if trimmedCandidate.hasPrefix("-") {
                values.append(unquoted(String(trimmedCandidate.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)))
            }
            index += 1
        }
        return values
    }

    static func mappingValue(for key: String, in block: [String]) -> [String: String] {
        guard let offset = block.firstIndex(where: { indentation(of: $0) == 4 && $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(key):") }) else { return [:] }
        let trimmed = block[offset].trimmingCharacters(in: .whitespaces)
        let raw = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        if raw == "{}" { return [:] }
        var result: [String: String] = [:]
        var index = offset + 1
        while index < block.count {
            let line = block[index]
            if indentation(of: line) <= 4 { break }
            if indentation(of: line) == 6, let split = splitMappingLine(line.trimmingCharacters(in: .whitespaces)) {
                result[unquoted(split.key)] = unquoted(split.value)
            }
            index += 1
        }
        return result
    }

    static func splitMappingLine(_ line: String) -> (key: String, value: String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let key = String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return (key, value)
    }

    static func isTopLevelKey(_ line: String, key: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return indentation(of: line) == 0 && (trimmed == "\(key):" || trimmed.hasPrefix("\(key):"))
    }

    static func nextTopLevelIndex(in lines: [String], after start: Int) -> Int? {
        guard start + 1 < lines.count else { return nil }
        return lines[(start + 1)...].firstIndex { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#") && indentation(of: line) == 0 && trimmed.contains(":")
        }
    }

    static func mappingKey(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(":"), !trimmed.hasPrefix("-") else { return nil }
        return unquoted(String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    static func unquoted(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            trimmed.removeFirst()
            trimmed.removeLast()
        }
        return trimmed.replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\")
    }

    static func quoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    static func quoteKey(_ value: String) -> String {
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.")
        if !value.isEmpty, value.unicodeScalars.allSatisfy({ safe.contains($0) }) { return value }
        return quoted(value)
    }

    static func appendArray(_ values: [String], key: String, indent: Int, to lines: inout [String]) {
        let spaces = String(repeating: " ", count: indent)
        lines.append("\(spaces)\(key):")
        if values.isEmpty { return }
        for value in values {
            lines.append("\(spaces)  - \(quoted(value))")
        }
    }

    static func appendMapping(_ mapping: [String: String], key: String, indent: Int, to lines: inout [String]) {
        let spaces = String(repeating: " ", count: indent)
        lines.append("\(spaces)\(key):")
        for key in mapping.keys.sorted() {
            lines.append("\(spaces)  \(quoteKey(key)): \(quoted(mapping[key] ?? ""))")
        }
    }

    static func splitInlineArray(_ body: String) -> [String] {
        var values: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false
        for character in body {
            if escaping {
                current.append(character)
                escaping = false
            } else if character == "\\" {
                current.append(character)
                escaping = true
            } else if let activeQuote = quote {
                current.append(character)
                if character == activeQuote { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
                current.append(character)
            } else if character == "," {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { values.append(current) }
        return values
    }

    static func joined(_ lines: [String], trailingNewline: Bool) -> String {
        let text = lines.joined(separator: "\n")
        return trailingNewline ? text + "\n" : text
    }
}
