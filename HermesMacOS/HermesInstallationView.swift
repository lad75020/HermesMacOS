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

    private let runner = HermesGitCommandRunner()

    var canMergeFromMain: Bool {
        !isRefreshing && !isPreviewingMerge && !isMerging && status.behindCount > 0 && !status.isDirty
    }

    var canPreviewMerge: Bool {
        !isRefreshing && !isPreviewingMerge && !isMerging && status.behindCount > 0
    }

    func refresh(repositoryPath: String? = nil) {
        if let repositoryPath { status.repositoryPath = repositoryPath }
        isRefreshing = true
        lastErrorMessage = ""
        let path = status.repositoryPath
        Task {
            do {
                let refreshed = try await runner.status(repositoryPath: path)
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
        Task {
            do {
                var refreshed = try await runner.status(repositoryPath: path)
                refreshed.mergePreview = try await runner.previewMerge(repositoryPath: path)
                status = refreshed
            } catch {
                lastErrorMessage = error.localizedDescription
            }
            isPreviewingMerge = false
        }
    }

    func mergeFromMainIntoLocalBranch() {
        isMerging = true
        lastErrorMessage = ""
        let path = status.repositoryPath
        Task {
            do {
                var refreshed = try await runner.mergeOriginMainIntoUpdateBranch(repositoryPath: path)
                refreshed.mergePreview = status.mergePreview
                status = refreshed
            } catch {
                lastErrorMessage = error.localizedDescription
                do { status = try await runner.status(repositoryPath: path) } catch { }
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

    @AppStorage("hermes.macOS.installation.repositoryPath") private var repositoryPath = NSString(string: "~/.hermes/hermes-agent").expandingTildeInPath
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
                .font(.title2.weight(.semibold))
            Spacer()
            if session.isRefreshing || session.isPreviewingMerge || session.isMerging {
                ProgressView().controlSize(.small)
                Text(activeOperationLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.hermesSecondaryText)
            }
        }
        .padding(18)
        .hermesGlassPanel(cornerRadius: 0)
    }

    private var repositorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Hermes repository")
                .font(.headline)
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
                .font(.headline)
            HStack(spacing: 10) {
                Button { session.refresh(repositoryPath: repositoryPath) } label: {
                    Label("Refresh lag", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(session.isRefreshing || session.isPreviewingMerge || session.isMerging)

                Button { session.previewMergeFromMain() } label: {
                    Label("Review conflicts", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .disabled(!session.canPreviewMerge)
                .help(session.status.behindCount == 0 ? "No upstream changes to review." : "Run a dry merge preview against origin/main.")

                Button { onReviewWithHermes(session.hermesReviewPrompt()) } label: {
                    Label("Ask Hermes", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .disabled(session.status.mergePreview.isEmpty && session.status.operationOutput.isEmpty && session.status.conflictFiles.isEmpty)

                Button { session.mergeFromMainIntoLocalBranch() } label: {
                    Label("Merge into local branch", systemImage: "arrow.triangle.merge")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!session.canMergeFromMain)
                .help(mergeHelpText)
            }
            Text("Merge creates a new local branch from the current HEAD, fetches origin/main, then runs git merge --no-ff --no-commit origin/main. If conflicts occur, the branch is left in conflict state for manual resolution.")
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
                    .font(.headline)
                Spacer()
                if !displayOutput.isEmpty {
                    Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(displayOutput, forType: .string) }
                        .buttonStyle(.bordered)
                }
            }
            ScrollView {
                Text(displayOutput.isEmpty ? "Run a refresh, conflict review, or merge to see command output here." : displayOutput)
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
        if session.isMerging { return "Merging" }
        if session.isPreviewingMerge { return "Reviewing" }
        return "Refreshing"
    }

    private var mergeHelpText: String {
        if session.status.behindCount == 0 { return "Already up to date with origin/main." }
        if session.status.isDirty { return "Commit or stash local changes before creating the update branch." }
        return "Create a local update branch and merge origin/main without committing."
    }
}

private final class HermesGitCommandRunner: @unchecked Sendable {
    func status(repositoryPath: String) async throws -> HermesInstallationStatus {
        try await runGit(repositoryPath: repositoryPath, arguments: ["fetch", "origin", "main"])
        let root = try await output(repositoryPath: repositoryPath, arguments: ["rev-parse", "--show-toplevel"])
        let branch = (try? await output(repositoryPath: repositoryPath, arguments: ["branch", "--show-current"])) ?? ""
        let head = (try? await output(repositoryPath: repositoryPath, arguments: ["rev-parse", "--short", "HEAD"])) ?? ""
        let remote = (try? await output(repositoryPath: repositoryPath, arguments: ["remote", "get-url", "origin"])) ?? ""
        let behind = Int(((try? await output(repositoryPath: repositoryPath, arguments: ["rev-list", "--count", "HEAD..origin/main"])) ?? "0")) ?? 0
        let ahead = Int(((try? await output(repositoryPath: repositoryPath, arguments: ["rev-list", "--count", "origin/main..HEAD"])) ?? "0")) ?? 0
        let dirty = (try? await output(repositoryPath: repositoryPath, arguments: ["status", "--porcelain"])) ?? ""
        let conflicts = (try? await output(repositoryPath: repositoryPath, arguments: ["diff", "--name-only", "--diff-filter=U"])) ?? ""

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

    func previewMerge(repositoryPath: String) async throws -> String {
        try await runGit(repositoryPath: repositoryPath, arguments: ["fetch", "origin", "main"])
        let result = try await run(repositoryPath: repositoryPath, arguments: ["merge-tree", "--write-tree", "HEAD", "origin/main"], allowFailure: true)
        let trimmed = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.exitCode == 0 {
            return trimmed.isEmpty ? "Dry merge preview completed: no conflicts predicted." : "Dry merge preview completed: no conflicts predicted.\n\n\(trimmed)"
        }
        return trimmed.isEmpty ? "Dry merge preview found conflicts." : trimmed
    }

    func mergeOriginMainIntoUpdateBranch(repositoryPath: String) async throws -> HermesInstallationStatus {
        var current = try await status(repositoryPath: repositoryPath)
        guard !current.isDirty else {
            throw HermesInstallationError.commandFailed("Working tree has local changes. Commit or stash them before creating the update branch.")
        }
        guard current.behindCount > 0 else {
            current.operationOutput = "Already up to date with origin/main."
            return current
        }

        let stamp = Self.branchStampFormatter.string(from: Date())
        let branchName = "hermes-update-\(stamp)"
        var outputLines: [String] = []
        outputLines.append(try await runGit(repositoryPath: repositoryPath, arguments: ["switch", "-c", branchName]).combinedOutput)
        let merge = try await run(repositoryPath: repositoryPath, arguments: ["merge", "--no-ff", "--no-commit", "origin/main"], allowFailure: true)
        outputLines.append(merge.combinedOutput)

        var refreshed = try await status(repositoryPath: repositoryPath)
        refreshed.operationOutput = "Created local branch \(branchName).\n" + outputLines.joined(separator: "\n")
        if merge.exitCode != 0 {
            refreshed.operationOutput += "\nMerge stopped with conflicts. Resolve the files above, then commit the merge manually."
        } else {
            refreshed.operationOutput += "\nMerge applied without committing. Review the changes, run tests, then commit manually when ready."
        }
        return refreshed
    }

    @discardableResult
    private func runGit(repositoryPath: String, arguments: [String]) async throws -> HermesGitCommandResult {
        try await run(repositoryPath: repositoryPath, arguments: arguments, allowFailure: false)
    }

    private func output(repositoryPath: String, arguments: [String]) async throws -> String {
        try await runGit(repositoryPath: repositoryPath, arguments: arguments).combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func run(repositoryPath: String, arguments: [String], allowFailure: Bool) async throws -> HermesGitCommandResult {
        try await Task.detached(priority: .userInitiated) {
            let expandedPath = NSString(string: repositoryPath).expandingTildeInPath
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw HermesInstallationError.invalidRepository("Repository folder does not exist: \(expandedPath)")
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", expandedPath] + arguments
            process.environment = [
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
                "LC_ALL": "C"
            ]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do { try process.run() } catch {
                throw HermesInstallationError.commandFailed("Could not run git: \(error.localizedDescription)")
            }
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let result = HermesGitCommandResult(exitCode: process.terminationStatus, combinedOutput: output)
            if !allowFailure && process.terminationStatus != 0 {
                throw HermesInstallationError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "git \(arguments.joined(separator: " ")) failed" : output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return result
        }.value
    }

    private static let branchStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

private struct HermesGitCommandResult {
    let exitCode: Int32
    let combinedOutput: String
}
