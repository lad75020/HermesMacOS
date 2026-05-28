//
//  HermesLocalConfigurationRuntime.swift
//  HermesMacOS
//

import SwiftUI
import Foundation

enum HermesLocalConfigurationSection: String, CaseIterable, Hashable {
    case skills, profiles, tools, mcpServers, schedules, models

    init(title: String) {
        switch title {
        case "Skills": self = .skills
        case "Profiles": self = .profiles
        case "Tools": self = .tools
        case "MCP Servers": self = .mcpServers
        case "Schedules": self = .schedules
        case "Models": self = .models
        default: self = .skills
        }
    }
}

struct HermesConfigurationValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
final class HermesLocalConfigurationRuntime: ObservableObject {
    @Published var outputs: [HermesLocalConfigurationSection: String] = [:]
    @Published var runningSections: Set<HermesLocalConfigurationSection> = []

    let hermesExecutable = HermesRuntimePaths.defaultHermesExecutable
    let hermesHome = HermesRuntimePaths.defaultHermesHome
    var remoteHostName = defaultHermesMacHost

    func refreshAll() {
    }

    func run(_ section: HermesLocalConfigurationSection, _ arguments: [String]) {
        let cleanArguments = arguments.map { $0.trimmedForHermes }.filter { !$0.isEmpty }
        guard cleanArguments.isEmpty == false else { return }
        runningSections.insert(section)
        outputs[section] = "$ hermes \(cleanArguments.joined(separator: " "))\nRunning…"
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome, remoteHostName] in
            let result = Self.execute(executable: hermesExecutable, arguments: cleanArguments, hermesHome: hermesHome, remoteHostName: remoteHostName)
            await MainActor.run {
                self.outputs[section] = result
                self.runningSections.remove(section)
            }
        }
    }

    func runChained(_ section: HermesLocalConfigurationSection, _ commands: [[String]]) {
        runningSections.insert(section)
        outputs[section] = "Running \(commands.count) local Hermes commands…"
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome, remoteHostName] in
            let combined = commands.map { command in
                Self.execute(executable: hermesExecutable, arguments: command.map { $0.trimmedForHermes }.filter { !$0.isEmpty }, hermesHome: hermesHome, remoteHostName: remoteHostName)
            }.joined(separator: "\n\n")
            await MainActor.run {
                self.outputs[section] = combined
                self.runningSections.remove(section)
            }
        }
    }

    func installSkill(from source: String, completion: @escaping @MainActor () -> Void) {
        let trimmedSource = source.trimmedForHermes
        guard !trimmedSource.isEmpty else { return }
        runningSections.insert(.skills)
        outputs[.skills] = "$ hermes skills install \(trimmedSource)\nRunning…"
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome, remoteHostName] in
            let result = Self.execute(executable: hermesExecutable, arguments: ["skills", "install", trimmedSource], hermesHome: hermesHome, remoteHostName: remoteHostName)
            await MainActor.run {
                self.outputs[.skills] = result
                self.runningSections.remove(.skills)
                completion()
            }
        }
    }

    func addMCPServer(name: String, command: String, args: [String], completion: @escaping @MainActor () -> Void) {
        let cleanName = name.trimmedForHermes
        let cleanCommand = command.trimmedForHermes
        guard !cleanName.isEmpty, !cleanCommand.isEmpty else { return }
        let cleanArgs = args.map { $0.trimmedForHermes }.filter { !$0.isEmpty }
        let arguments = ["mcp", "add", cleanName, "--command", cleanCommand] + (cleanArgs.isEmpty ? [] : ["--args"] + cleanArgs)
        runningSections.insert(.mcpServers)
        outputs[.mcpServers] = "$ hermes \(arguments.joined(separator: " "))\nRunning…"
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome, remoteHostName] in
            let result = Self.execute(executable: hermesExecutable, arguments: arguments, hermesHome: hermesHome, remoteHostName: remoteHostName)
            await MainActor.run {
                self.outputs[.mcpServers] = result
                self.runningSections.remove(.mcpServers)
                completion()
            }
        }
    }

    nonisolated static func execute(executable: String, arguments: [String], hermesHome: String, remoteHostName: String) -> String {
        let process = Process()
        let normalizedHost = HermesHostEndpoints.normalizedHost(remoteHostName)
        let isRemote = !HermesSSHHostCredentials.isLocalHost(normalizedHost)
        let commandLabel = "$ hermes \(arguments.joined(separator: " "))"
        var temporaryIdentityURL: URL?
        defer {
            if let temporaryIdentityURL { try? FileManager.default.removeItem(at: temporaryIdentityURL) }
        }

        if isRemote {
            let credentials = HermesSettingsStore.loadSSHCredentials(forHost: normalizedHost)
            let username = credentials.username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !username.isEmpty else { return "\(commandLabel)\nSSH settings missing for \(normalizedHost): enter a username in Settings." }
            do { temporaryIdentityURL = try HermesSSHKeychain.temporaryIdentityFile(forHost: normalizedHost) }
            catch { return "\(commandLabel)\nSSH settings missing for \(normalizedHost): \(error.localizedDescription)" }
            let remoteCommand = HermesShellQuoting.command(
                executable,
                arguments: arguments,
                environment: ["HERMES_HOME": hermesHome, "TERM": "xterm-256color"]
            )
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = [
                "-i", temporaryIdentityURL!.path,
                "-o", "BatchMode=yes",
                "-o", "IdentitiesOnly=yes",
                "-o", "StrictHostKeyChecking=accept-new",
                "\(username)@\(normalizedHost)",
                remoteCommand
            ]
        } else {
            process.executableURL = FileManager.default.isExecutableFile(atPath: executable) ? URL(fileURLWithPath: executable) : URL(fileURLWithPath: "/opt/homebrew/bin/hermes")
            process.arguments = arguments
            var environment = ProcessInfo.processInfo.environment
            environment["HERMES_HOME"] = hermesHome
            environment["TERM"] = environment["TERM"] ?? "xterm-256color"
            process.environment = environment
        }

        do {
            let result = try HermesProcessRunner.run(
                executable: process.executableURL?.path ?? executable,
                arguments: process.arguments ?? [],
                environment: process.environment,
                timeout: 120
            )
            let status = isRemote ? "ssh \(normalizedHost) \(result.statusLine)" : result.statusLine
            return [commandLabel, status, result.output.isEmpty ? "No output." : result.output].joined(separator: "\n")
        } catch {
            return "Failed to run hermes \(arguments.joined(separator: " ")): \(error.localizedDescription)"
        }
    }

}
