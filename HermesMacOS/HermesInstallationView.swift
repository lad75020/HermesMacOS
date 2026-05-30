//
//  HermesInstallationView.swift
//  HermesMacOS
//

import Foundation
import SwiftUI

struct HermesInstallationStatus: Equatable {
    var repositoryPath = NSString(string: "~/.hermes/hermes-agent").expandingTildeInPath
    var rootPath = ""
    var currentBranch = ""
    var headRevision = ""
    var remoteURL = ""
    var behindCount = 0
    var aheadCount = 0
    var isDirty = false
    var dirtySummary = ""
    var conflictFiles: [String] = []
    var lastChecked: Date?
    var mergePreview = ""
    var operationOutput = ""

    var lagSummary: String {
        if behindCount == 0 { return "Up to date with origin/main" }
        if behindCount == 1 { return "1 commit behind origin/main" }
        return "\(behindCount) commits behind origin/main"
    }

    var branchSummary: String {
        currentBranch.isEmpty ? "Detached HEAD" : currentBranch
    }
}

enum HermesInstallationError: LocalizedError {
    case invalidRepository(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepository(let message): message
        case .commandFailed(let message): message
        }
    }
}

@MainActor
@Observable
final class HermesInstallationSession {
    var status = HermesInstallationStatus()
    var isRefreshing = false
    var isPreviewingMerge = false
    var isMerging = false
    var lastErrorMessage = ""
    var remoteHostName = defaultHermesMacHost

    private let runner = HermesGitCommandRunner()

    var canUpdateHermes: Bool {
        !isRefreshing && !isPreviewingMerge && !isMerging && !status.isDirty
    }

    func refresh(repositoryPath: String? = nil) {
        if let repositoryPath { status.repositoryPath = repositoryPath }
        isRefreshing = true
        lastErrorMessage = ""
        let path = status.repositoryPath
        let host = remoteHostName
        Task {
            do {
                let refreshed = try await runner.status(repositoryPath: path, remoteHostName: host)
                status = refreshed
            } catch {
                lastErrorMessage = error.localizedDescription
            }
            isRefreshing = false
        }
    }

    func previewMergeFromMain() {
        isPreviewingMerge = true
        lastErrorMessage = ""
        let path = status.repositoryPath
        let host = remoteHostName
        Task {
            do {
                var refreshed = try await runner.status(repositoryPath: path, remoteHostName: host)
                refreshed.mergePreview = try await runner.previewMerge(repositoryPath: path, remoteHostName: host)
                status = refreshed
            } catch {
                lastErrorMessage = error.localizedDescription
            }
            isPreviewingMerge = false
        }
    }

    func updateHermes() {
        isMerging = true
        lastErrorMessage = ""
        let path = status.repositoryPath
        let host = remoteHostName
        Task {
            do {
                status = try await runner.updateHermesFromUpstream(repositoryPath: path, remoteHostName: host)
            } catch {
                lastErrorMessage = error.localizedDescription
                do { status = try await runner.status(repositoryPath: path, remoteHostName: host) } catch { }
            }
            isMerging = false
        }
    }

    func hermesReviewPrompt() -> String {
        var prompt = """
        Review this Hermes Agent update attempt and help resolve it safely.

        Repository: \(status.rootPath.isEmpty ? status.repositoryPath : status.rootPath)
        Current branch: \(status.branchSummary)
        Local HEAD: \(status.headRevision)
        Remote: \(status.remoteURL)
        Lag: \(status.lagSummary)
        Dirty working tree: \(status.isDirty ? "yes" : "no")

        """

        if !status.conflictFiles.isEmpty {
            prompt += "Conflicting files:\n\(status.conflictFiles.map { "- \($0)" }.joined(separator: "\n"))\n\n"
        }
        if !status.dirtySummary.isEmpty {
            prompt += "Working tree summary:\n\(status.dirtySummary)\n\n"
        }
        if !status.mergePreview.isEmpty {
            prompt += "Merge preview output:\n\(status.mergePreview)\n\n"
        }
        if !status.operationOutput.isEmpty {
            prompt += "Last git operation output:\n\(status.operationOutput)\n\n"
        }
        prompt += "Please summarize the risk, identify the likely conflict areas, and propose exact conflict-resolution steps. Do not run commands; give a review first."
        return prompt
    }
}

struct HermesInstallationView: View {
    enum Presentation {
        case standalone
        case utilitySection
    }

    @Bindable var session: HermesInstallationSession
    var onReviewWithHermes: (String) -> Void
    var presentation: Presentation = .standalone

    @State private var repositoryPath = HermesSettingsStore.loadInstallationRepositoryPath()
    @State private var selectedOutput = ""

    var body: some View {
        Group {
            switch presentation {
            case .standalone:
                VStack(spacing: 0) {
                    header
                    ScrollView { installationContent.padding(22) }
                }
                .background(HermesLiquidGlassCanvas().ignoresSafeArea())
            case .utilitySection:
                installationContent
                    .padding(.top, 12)
            }
        }
        .task {
            if session.status.lastChecked == nil {
                session.refresh(repositoryPath: repositoryPath)
            }
        }
        .onChange(of: repositoryPath) { _, newValue in
            HermesSettingsStore.saveInstallationRepositoryPath(newValue)
            session.refresh(repositoryPath: newValue)
        }
        .onChange(of: session.status.mergePreview) { _, _ in selectedOutput = displayOutput }
        .onChange(of: session.status.operationOutput) { _, _ in selectedOutput = displayOutput }
    }

    private var installationContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            repositorySection
            statusSection
            actionsSection
            outputSection
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("Hermes Installation", systemImage: "arrow.triangle.2.circlepath")
                .hermesWebsiteTitleFont(size: 22, weight: .bold)
            Spacer()
            if session.isRefreshing || session.isPreviewingMerge || session.isMerging {
                ProgressView().controlSize(.small)
                Text(activeOperationLabel)
                    .hermesWebsiteLabelFont(size: 11, weight: .bold)
                    .foregroundStyle(Color.hermesSecondaryText)
            }
        }
        .padding(18)
        .hermesGlassPanel(cornerRadius: 0)
    }

    private var repositorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Hermes repository")
                .hermesWebsiteTitleFont(size: 15, weight: .bold)
            TextField("Hermes agent repository path", text: $repositoryPath)
                .textFieldStyle(.roundedBorder)
            Text("Git commands run directly on this Mac against the selected repository. No macOS companion host is used.")
                .font(.caption)
                .foregroundStyle(Color.hermesSecondaryText)
        }
        .padding(16)
        .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.72))
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                HermesStatusCard(title: "Lag", value: session.status.lagSummary, tint: session.status.behindCount == 0 ? .green : .hermesOrange, minimumWidth: 210, maximumWidth: .infinity)
                HermesStatusCard(title: "Branch", value: session.status.branchSummary, tint: .hermesActionBlue, minimumWidth: 180, maximumWidth: .infinity)
                HermesStatusCard(title: "Ahead", value: "\(session.status.aheadCount)", tint: .hermesPurple, minimumWidth: 96, maximumWidth: 110)
            }
            detailsGrid
            if !session.status.conflictFiles.isEmpty {
                conflictList
            }
            if !session.lastErrorMessage.isEmpty {
                Label(session.lastErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color.hermesDestructive)
            }
        }
        .padding(16)
        .hermesGlassPanel(tint: Color.hermesActionBlue.opacity(0.07))
    }

    private var detailsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
            detailRow("Repository", session.status.rootPath.isEmpty ? session.status.repositoryPath : session.status.rootPath)
            detailRow("HEAD", session.status.headRevision.isEmpty ? "Unknown" : session.status.headRevision)
            detailRow("Remote", session.status.remoteURL.isEmpty ? "Unknown" : session.status.remoteURL)
            detailRow("Working tree", session.status.isDirty ? "Has local changes" : "Clean")
            if let lastChecked = session.status.lastChecked {
                detailRow("Last check", lastChecked.formatted(date: .abbreviated, time: .standard))
            }
        }
        .font(.caption)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(Color.hermesSecondaryText)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(value)
        }
    }

    private var conflictList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Conflicts detected", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.hermesDestructive)
            ForEach(session.status.conflictFiles, id: \.self) { file in
                Text(file)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .hermesGlassPanel(tint: Color.hermesDestructive.opacity(0.08), cornerRadius: 14)
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Update workflow")
                .hermesWebsiteTitleFont(size: 15, weight: .bold)
            HStack(spacing: 10) {
                Button { session.refresh(repositoryPath: repositoryPath) } label: {
                    Label("Refresh lag", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(session.isRefreshing || session.isPreviewingMerge || session.isMerging)

                Button { session.updateHermes() } label: {
                    Label("Update Hermes", systemImage: "arrow.triangle.merge")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!session.canUpdateHermes)
                .help(updateHelpText)
            }
            Text("Update fetches NousResearch/hermes-agent main into upstream-latest, switches local main, merges upstream-latest, stops on conflicts, and pushes main to the lad75020 fork when the merge succeeds.")
                .font(.caption)
                .foregroundStyle(Color.hermesSecondaryText)
        }
        .padding(16)
        .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.72))
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Git output")
                    .hermesWebsiteTitleFont(size: 15, weight: .bold)
                Spacer()
                if !displayOutput.isEmpty {
                    Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(displayOutput, forType: .string) }
                        .buttonStyle(.bordered)
                }
            }
            ScrollView {
                Text(displayOutput.isEmpty ? "Run a refresh or update to see command output here." : displayOutput)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(displayOutput.isEmpty ? Color.hermesSecondaryText : Color.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 140, maxHeight: 260)
            .hermesGlassPanel(tint: Color.black.opacity(0.08), cornerRadius: 14)
        }
        .padding(16)
        .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.72))
    }

    private var displayOutput: String {
        [session.status.mergePreview, session.status.operationOutput, session.status.dirtySummary]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private var activeOperationLabel: String {
        if session.isMerging { return "Updating" }
        if session.isPreviewingMerge { return "Reviewing" }
        return "Refreshing"
    }

    private var updateHelpText: String {
        if session.status.isDirty { return "Commit or stash local changes before updating Hermes." }
        return "Fetch NousResearch main into upstream-latest, merge it into local main, then push main to the lad75020 fork."
    }
}

private final class HermesGitCommandRunner: @unchecked Sendable {
    func status(repositoryPath: String, remoteHostName: String) async throws -> HermesInstallationStatus {
        try await ensureRemote(repositoryPath: repositoryPath, name: "upstream", url: Self.upstreamRemoteURL, remoteHostName: remoteHostName)
        try await runGit(repositoryPath: repositoryPath, arguments: ["fetch", "upstream", "main"], remoteHostName: remoteHostName)
        let root = try await output(repositoryPath: repositoryPath, arguments: ["rev-parse", "--show-toplevel"], remoteHostName: remoteHostName)
        let branch = (try? await output(repositoryPath: repositoryPath, arguments: ["branch", "--show-current"], remoteHostName: remoteHostName)) ?? ""
        let head = (try? await output(repositoryPath: repositoryPath, arguments: ["rev-parse", "--short", "HEAD"], remoteHostName: remoteHostName)) ?? ""
        let remote = (try? await output(repositoryPath: repositoryPath, arguments: ["remote", "get-url", "origin"], remoteHostName: remoteHostName)) ?? ""
        let behind = Int(((try? await output(repositoryPath: repositoryPath, arguments: ["rev-list", "--count", "HEAD..upstream/main"], remoteHostName: remoteHostName)) ?? "0")) ?? 0
        let ahead = Int(((try? await output(repositoryPath: repositoryPath, arguments: ["rev-list", "--count", "upstream/main..HEAD"], remoteHostName: remoteHostName)) ?? "0")) ?? 0
        let dirty = (try? await output(repositoryPath: repositoryPath, arguments: ["status", "--porcelain"], remoteHostName: remoteHostName)) ?? ""
        let conflicts = (try? await output(repositoryPath: repositoryPath, arguments: ["diff", "--name-only", "--diff-filter=U"], remoteHostName: remoteHostName)) ?? ""

        var status = HermesInstallationStatus(repositoryPath: NSString(string: repositoryPath).expandingTildeInPath)
        status.rootPath = root
        status.currentBranch = branch
        status.headRevision = head
        status.remoteURL = remote
        status.behindCount = behind
        status.aheadCount = ahead
        status.isDirty = !dirty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        status.dirtySummary = dirty
        status.conflictFiles = conflicts.split(separator: "\n").map(String.init)
        status.lastChecked = Date()
        return status
    }

    func previewMerge(repositoryPath: String, remoteHostName: String) async throws -> String {
        try await runGit(repositoryPath: repositoryPath, arguments: ["fetch", "origin", "main"], remoteHostName: remoteHostName)
        let result = try await run(repositoryPath: repositoryPath, arguments: ["merge-tree", "--write-tree", "HEAD", "origin/main"], allowFailure: true, remoteHostName: remoteHostName)
        let trimmed = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.exitCode == 0 {
            return trimmed.isEmpty ? "Dry merge preview completed: no conflicts predicted." : "Dry merge preview completed: no conflicts predicted.\n\n\(trimmed)"
        }
        return trimmed.isEmpty ? "Dry merge preview found conflicts." : trimmed
    }

    func updateHermesFromUpstream(repositoryPath: String, remoteHostName: String) async throws -> HermesInstallationStatus {
        let current = try await status(repositoryPath: repositoryPath, remoteHostName: remoteHostName)
        guard !current.isDirty else {
            throw HermesInstallationError.commandFailed("Working tree has local changes. Commit or stash them before updating Hermes.")
        }

        var outputLines: [String] = []
        outputLines.append("Ensuring upstream remote points to \(Self.upstreamRemoteURL)")
        try await ensureRemote(repositoryPath: repositoryPath, name: "upstream", url: Self.upstreamRemoteURL, remoteHostName: remoteHostName)

        outputLines.append("Fetching NousResearch main")
        outputLines.append(try await runGit(repositoryPath: repositoryPath, arguments: ["fetch", "upstream", "main"], remoteHostName: remoteHostName).combinedOutput)

        outputLines.append("Updating local branch upstream-latest from upstream/main")
        outputLines.append(try await runGit(repositoryPath: repositoryPath, arguments: ["switch", "-C", "upstream-latest", "upstream/main"], remoteHostName: remoteHostName).combinedOutput)

        outputLines.append("Switching to local main")
        outputLines.append(try await runGit(repositoryPath: repositoryPath, arguments: ["switch", "main"], remoteHostName: remoteHostName).combinedOutput)

        outputLines.append("Merging upstream-latest into main")
        let merge = try await run(repositoryPath: repositoryPath, arguments: ["merge", "--no-ff", "upstream-latest"], allowFailure: true, remoteHostName: remoteHostName)
        outputLines.append(merge.combinedOutput)

        var refreshed = try await status(repositoryPath: repositoryPath, remoteHostName: remoteHostName)
        if merge.exitCode != 0 || !refreshed.conflictFiles.isEmpty {
            refreshed.operationOutput = outputLines.joined(separator: "\n") + "\nConflicts detected. Update stopped before push; resolve the listed conflicts on local main."
            return refreshed
        }

        outputLines.append("Pushing main to origin (expected: \(Self.forkRemoteURL))")
        outputLines.append(try await runGit(repositoryPath: repositoryPath, arguments: ["push", "origin", "main"], remoteHostName: remoteHostName).combinedOutput)

        refreshed = try await status(repositoryPath: repositoryPath, remoteHostName: remoteHostName)
        refreshed.operationOutput = outputLines.joined(separator: "\n") + "\nHermes update completed: upstream-latest merged into local main and main pushed to origin."
        return refreshed
    }

    private func ensureRemote(repositoryPath: String, name: String, url: String, remoteHostName: String) async throws {
        let existing = try await run(repositoryPath: repositoryPath, arguments: ["remote", "get-url", name], allowFailure: true, remoteHostName: remoteHostName)
        if existing.exitCode == 0 {
            let currentURL = existing.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if currentURL != url {
                try await runGit(repositoryPath: repositoryPath, arguments: ["remote", "set-url", name, url], remoteHostName: remoteHostName)
            }
        } else {
            try await runGit(repositoryPath: repositoryPath, arguments: ["remote", "add", name, url], remoteHostName: remoteHostName)
        }
    }

    @discardableResult
    private func runGit(repositoryPath: String, arguments: [String], remoteHostName: String) async throws -> HermesGitCommandResult {
        try await run(repositoryPath: repositoryPath, arguments: arguments, allowFailure: false, remoteHostName: remoteHostName)
    }

    private func output(repositoryPath: String, arguments: [String], remoteHostName: String) async throws -> String {
        try await runGit(repositoryPath: repositoryPath, arguments: arguments, remoteHostName: remoteHostName).combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func run(repositoryPath: String, arguments: [String], allowFailure: Bool, remoteHostName: String) async throws -> HermesGitCommandResult {
        try await HermesFilesystemAccessPolicy.requireAccess(to: repositoryPath, operation: "Run git in Hermes installation repository")
        return try await Task.detached(priority: .userInitiated) {
            let expandedPath = NSString(string: repositoryPath).expandingTildeInPath
            let normalizedHost = HermesHostEndpoints.normalizedHost(remoteHostName)
            let isRemote = !HermesSSHHostCredentials.isLocalHost(normalizedHost)
            var temporaryIdentityURL: URL?
            defer {
                if let temporaryIdentityURL { try? FileManager.default.removeItem(at: temporaryIdentityURL) }
            }

            let process = Process()
            if isRemote {
                let credentials = HermesSettingsStore.loadSSHCredentials(forHost: normalizedHost)
                let username = credentials.username.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !username.isEmpty else {
                    throw HermesInstallationError.commandFailed("SSH settings missing for \(normalizedHost): enter a username in Settings.")
                }
                do { temporaryIdentityURL = try HermesSSHKeychain.temporaryIdentityFile(forHost: normalizedHost) }
                catch { throw HermesInstallationError.commandFailed("SSH settings missing for \(normalizedHost): \(error.localizedDescription)") }
                let remoteCommand = HermesShellQuoting.command(
                    "/usr/bin/git",
                    arguments: ["-C", expandedPath] + arguments,
                    environment: ["LC_ALL": "C", "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
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
                let fileManager = FileManager.default
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
                    throw HermesInstallationError.invalidRepository("Repository folder does not exist: \(expandedPath)")
                }
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = ["-C", expandedPath] + arguments
                process.environment = [
                    "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
                    "LC_ALL": "C"
                ]
            }
            let result: HermesProcessResult
            do {
                result = try HermesProcessRunner.run(
                    executable: process.executableURL?.path ?? "/usr/bin/git",
                    arguments: process.arguments ?? [],
                    environment: process.environment,
                    timeout: 180
                )
            } catch {
                throw HermesInstallationError.commandFailed("Could not run git: \(error.localizedDescription)")
            }
            let gitResult = HermesGitCommandResult(exitCode: result.exitCode, combinedOutput: result.output)
            if !allowFailure && result.exitCode != 0 {
                throw HermesInstallationError.commandFailed(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "git \(arguments.joined(separator: " ")) failed" : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return gitResult
        }.value
    }

    private static let upstreamRemoteURL = "https://github.com/NousResearch/hermes-agent.git"
    private static let forkRemoteURL = "https://github.com/lad75020/hermes-agent.git"
}

private struct HermesGitCommandResult {
    let exitCode: Int32
    let combinedOutput: String
}
