import XCTest
@testable import HermesMacOS

final class TUIGatewayWorkflowTests: XCTestCase {
    func testReasoningEffortCanonicalValuesAndLabelsAreStable() {
        XCTAssertEqual(HermesReasoningEffort.all, ["none", "minimal", "low", "medium", "high", "xhigh", "max", "ultra"])
        XCTAssertEqual(HermesReasoningEffort.all.map(HermesReasoningEffort.label), ["Off", "Minimal", "Low", "Medium", "High", "Extra High", "Max", "Ultra"])
        XCTAssertNil(HermesReasoningEffort.normalized("unsupported"))
    }

    func testReasoningCapabilityUsesSelectedModelBeforeProfileFallback() {
        let profile = HermesAPIProfile(
            id: "default",
            name: "Default",
            isDefault: true,
            model: "gpt-5",
            provider: "openai",
            reasoning: HermesAPIProfileReasoning(supported: true, effortLevels: ["low", "medium", "high"])
        )
        let unsupportedCapabilities = ["gpt-4o": HermesTUIModelCapabilities(fast: false, reasoning: false)]

        XCTAssertFalse(HermesTUIReasoningCapability.supports(selectedModel: "gpt-4o", provider: "openai", capabilities: unsupportedCapabilities, profile: profile))
        XCTAssertFalse(HermesTUIReasoningCapability.supports(selectedModel: "gpt-4o", provider: "openai", capabilities: [:], profile: profile))
        XCTAssertTrue(HermesTUIReasoningCapability.supports(selectedModel: "gpt-5", provider: "openai", capabilities: [:], profile: profile))
        XCTAssertTrue(HermesTUIReasoningCapability.supports(selectedModel: "gpt-5", provider: "openai", capabilities: [:], profile: HermesAPIProfile(id: "fallback", name: "Fallback", isDefault: false, model: nil, provider: "openai")))
        XCTAssertEqual(HermesTUIReasoningCapability.efforts(selectedModel: "gpt-5", provider: "openai", capabilities: [:], profile: profile), ["low", "medium", "high"])
        XCTAssertEqual(HermesTUIReasoningCapability.efforts(selectedModel: "gpt-5", provider: "openai", capabilities: ["gpt-5": HermesTUIModelCapabilities(fast: true, reasoning: true)], profile: profile), HermesReasoningEffort.all)
    }

    func testProfileReasoningMetadataDecodesWhenPresentAndRemainsOptional() throws {
        let supported = try JSONDecoder().decode(HermesAPIProfile.self, from: Data(#"{"id":"default","name":"Default","is_default":true,"model":"gpt-5","provider":"openai","reasoning":{"supported":true,"effort_levels":["low","high"]}}"#.utf8))
        let legacy = try JSONDecoder().decode(HermesAPIProfile.self, from: Data(#"{"id":"legacy","name":"Legacy","is_default":false}"#.utf8))

        XCTAssertEqual(supported.reasoning, HermesAPIProfileReasoning(supported: true, effortLevels: ["low", "high"]))
        XCTAssertNil(legacy.reasoning)
    }

    func testDashboardProfilesMapToTUIGatewayProfileOptions() throws {
        let payload = Data(#"{"profiles":[{"name":"default","is_default":true,"model":"gpt-5.6-sol","provider":"openai-codex"},{"name":"ollama","is_default":false,"model":"gemma4:e4b","provider":"custom"},{"name":"opus47","is_default":false,"model":"claude-opus-4.7","provider":"anthropic"}]}"#.utf8)

        let response = try JSONDecoder().decode(HermesDashboardProfilesResponse.self, from: payload)
        let profiles = response.apiProfiles

        XCTAssertEqual(profiles.map(\.id), ["default", "ollama", "opus47"])
        XCTAssertEqual(profiles[1].model, "gemma4:e4b")
        XCTAssertEqual(profiles[2].provider, "anthropic")
    }

    func testStaleOllamaSessionCatalogCannotBeAcceptedForOpus48Selection() throws {
        let staleOllamaCatalog = HermesTUIModelCatalog(
            provider: "custom",
            currentModel: "gemma4:e4b",
            models: ["gemma4:e4b"],
            capabilities: [:]
        )
        let inFlightOllamaRefresh = HermesTUIModelOptionsRefreshIdentity(
            selectedProfile: "ollama",
            activeProfile: "ollama",
            sessionID: "ollama-session",
            generation: 40
        )

        XCTAssertTrue(inFlightOllamaRefresh.shouldQuery)
        XCTAssertNil(
            inFlightOllamaRefresh.catalogIfCurrent(
                staleOllamaCatalog,
                selectedProfile: "opus48",
                activeProfile: "opus48",
                sessionID: "opus48-session",
                generation: 40
            ),
            "A model.options response for the old custom/gemma4:e4b Ollama session must not replace opus48 routing."
        )

        let refreshDuringProfileSwitch = HermesTUIModelOptionsRefreshIdentity(
            selectedProfile: "opus48",
            activeProfile: "ollama",
            sessionID: "ollama-session",
            generation: 40
        )
        XCTAssertFalse(
            refreshDuringProfileSwitch.shouldQuery,
            "Model options must not be queried until the active session belongs to the selected opus48 profile."
        )

        let olderOpus48Refresh = HermesTUIModelOptionsRefreshIdentity(
            selectedProfile: "opus48",
            activeProfile: "opus48",
            sessionID: "opus48-session",
            generation: 41
        )
        let newerOpus48Refresh = HermesTUIModelOptionsRefreshIdentity(
            selectedProfile: "opus48",
            activeProfile: "opus48",
            sessionID: "opus48-session",
            generation: 42
        )
        let opus48Catalog = HermesTUIModelCatalog(
            provider: "anthropic",
            currentModel: "claude-opus-4.8",
            models: ["claude-opus-4.8"],
            capabilities: [:]
        )

        XCTAssertNil(
            olderOpus48Refresh.catalogIfCurrent(
                opus48Catalog,
                selectedProfile: newerOpus48Refresh.selectedProfile,
                activeProfile: newerOpus48Refresh.activeProfile,
                sessionID: newerOpus48Refresh.sessionID,
                generation: newerOpus48Refresh.generation
            ),
            "An older model refresh generation must not publish after a newer refresh starts for the same profile and session."
        )
        XCTAssertEqual(
            newerOpus48Refresh.catalogIfCurrent(
                opus48Catalog,
                selectedProfile: newerOpus48Refresh.selectedProfile,
                activeProfile: newerOpus48Refresh.activeProfile,
                sessionID: newerOpus48Refresh.sessionID,
                generation: newerOpus48Refresh.generation
            ),
            opus48Catalog,
            "The newest model refresh generation may publish for the current profile and session."
        )

        let source = try HermesTestAssertions.readRepositoryFile("HermesMacOS/HermesTUIGatewayView.swift")
        let automaticRefreshStart = try XCTUnwrap(source.range(of: ".onChange(of: selectedProfile)"))
        let automaticRefreshEnd = try XCTUnwrap(
            source.range(of: ".onChange(of: store.activeModel)", range: automaticRefreshStart.upperBound..<source.endIndex)
        )
        let automaticRefreshHooks = String(source[automaticRefreshStart.lowerBound..<automaticRefreshEnd.lowerBound])
        XCTAssertEqual(
            automaticRefreshHooks.components(separatedBy: "scheduleAvailableModelsRefresh()").count - 1,
            4,
            "Selected-profile, connection, active-profile, and session changes must all use the centralized model refresh scheduler."
        )
        XCTAssertFalse(
            automaticRefreshHooks.contains("Task { await refreshAvailableModels() }"),
            "Automatic lifecycle hooks must not launch independent model refresh tasks."
        )

        let schedulerStart = try XCTUnwrap(source.range(of: "private func scheduleAvailableModelsRefresh()"))
        let schedulerEnd = try XCTUnwrap(
            source.range(of: "private func refreshAvailableModels(", range: schedulerStart.upperBound..<source.endIndex)
        )
        let schedulerSource = String(source[schedulerStart.lowerBound..<schedulerEnd.lowerBound])
        XCTAssertTrue(
            schedulerSource.contains("modelOptionsRefreshTask?.cancel()")
                && schedulerSource.contains("modelOptionsRefreshTask = Task {")
                && schedulerSource.contains("await refreshAvailableModels(generation: generation, refresh: refresh)"),
            "The centralized model refresh scheduler must cancel the older generation before starting the newest one."
        )
        XCTAssertTrue(
            source.contains(".onDisappear { modelOptionsRefreshTask?.cancel() }"),
            "The scheduled model refresh must be cancelled when the TUI Gateway view disappears."
        )
    }

    func testStaleOllamaSessionCreationCannotPublishAfterOpus48CreationStarts() throws {
        let olderOllamaCreation = HermesTUISessionCreationIdentity(profile: "ollama", generation: 40)
        let newerOpus48Creation = HermesTUISessionCreationIdentity(profile: "opus48", generation: 41)

        XCTAssertFalse(
            olderOllamaCreation.isCurrent(newerOpus48Creation),
            "An older Ollama session.create completion must not publish after a newer opus48 creation starts."
        )
        XCTAssertFalse(
            HermesTUISessionCreationIdentity(profile: "ollama", generation: 41).isCurrent(newerOpus48Creation),
            "The current generation must still reject a stale profile."
        )
        XCTAssertFalse(
            HermesTUISessionCreationIdentity(profile: "opus48", generation: 40).isCurrent(newerOpus48Creation),
            "The current profile must still reject a stale generation."
        )
        XCTAssertTrue(
            newerOpus48Creation.isCurrent(newerOpus48Creation),
            "Only the newest profile and generation may publish its session.create result."
        )

        let source = try HermesTestAssertions.readRepositoryFile("HermesMacOS/HermesTUIGatewayView.swift")
        let createSessionStart = try XCTUnwrap(source.range(of: "func createSession(profile:"))
        let createSessionEnd = try XCTUnwrap(
            source.range(of: "func submitPrompt(", range: createSessionStart.upperBound..<source.endIndex)
        )
        let createSessionSource = String(source[createSessionStart.lowerBound..<createSessionEnd.lowerBound])
        XCTAssertTrue(
            createSessionSource.contains("sessionCreationGeneration += 1")
                && createSessionSource.contains("sessionCreationTask?.cancel()")
                && createSessionSource.contains("sessionCreationTask = Task {")
                && createSessionSource.contains("HermesTUISessionCreationIdentity(profile: selectedProfile, generation: sessionCreationGeneration)")
                && createSessionSource.contains("identity: identity"),
            "createSession must advance the identity generation and cancel/replace the prior session creation task."
        )

        let gatewayCreationStart = try XCTUnwrap(source.range(of: "private func createGatewaySession("))
        let gatewayCreationEnd = try XCTUnwrap(
            source.range(of: "private func submit(", range: gatewayCreationStart.upperBound..<source.endIndex)
        )
        let gatewayCreationSource = String(source[gatewayCreationStart.lowerBound..<gatewayCreationEnd.lowerBound])
        let publicationGuard = try XCTUnwrap(gatewayCreationSource.range(of: "guard identity.isCurrent(sessionCreationIdentity) else { return }"))
        let sessionAssignment = try XCTUnwrap(gatewayCreationSource.range(of: "sessionID = object[\"session_id\"]"))
        let profileAssignment = try XCTUnwrap(gatewayCreationSource.range(of: "activeProfile = selectedProfile"))
        XCTAssertLessThan(publicationGuard.lowerBound, sessionAssignment.lowerBound)
        XCTAssertLessThan(publicationGuard.lowerBound, profileAssignment.lowerBound)
    }

    func testTUIGatewayLoadsProfilesFromDashboardBeforeAPIServerFallback() throws {
        let source = try HermesTestAssertions.readRepositoryFile("HermesMacOS/HermesTUIGatewayView.swift")
        XCTAssertTrue(source.contains("HermesTUIGatewayProfilesClient.fetchProfiles"))
        XCTAssertTrue(source.contains("dashboardBaseURL: dashboardURL"))
    }

    @MainActor
    func testTUIWorkspaceDefaultsAndCopiesReasoningEffort() {
        let initial = HermesTUIWorkspace(number: 1)
        XCTAssertEqual(initial.selectedReasoningEffort, "medium")

        let copied = HermesTUIWorkspace(number: 2, selectedProfile: initial.selectedProfile, selectedModel: initial.selectedModel, fastModeEnabled: initial.fastModeEnabled, selectedReasoningEffort: "ultra")
        XCTAssertEqual(copied.selectedReasoningEffort, "ultra")
        XCTAssertEqual(HermesTUIWorkspace(number: 3, selectedReasoningEffort: "invalid").selectedReasoningEffort, "medium")
    }

    func testReasoningProtocolPayloadsUseSessionScopedConfiguration() throws {
        let source = try HermesTestAssertions.readRepositoryFile("HermesMacOS/HermesTUIGatewayView.swift")
        XCTAssertTrue(source.contains("params[\"reasoning_effort\"] = .string(reasoningEffort)"))
        XCTAssertTrue(source.contains("\"config.set\""))
        XCTAssertTrue(source.contains("\"key\": .string(\"reasoning\")"))
        XCTAssertTrue(source.contains("updateReasoningEffort(from: object[\"info\"]?.objectValue ?? [:])"))
    }

    func testGatewayEventParserHandlesMessageAndRequestEvents() throws {
        let stream = try HermesFixtureLoader.string(named: "stream-fixtures", extension: "ndjson", subdirectory: "Streams")
        let parsed = try stream.split(separator: "\n").compactMap { try HermesTUIGatewayEventParser.parseEventEnvelope(String($0)) }
        XCTAssertTrue(parsed.contains { $0.type == "gateway.ready" && $0.sessionID == "sess-test" })
        XCTAssertTrue(parsed.contains { $0.type == "message.delta" && $0.text == "Hello" })
        XCTAssertTrue(parsed.contains { $0.type == "approval.request" && $0.requestID == "approval-test" })
        XCTAssertTrue(parsed.contains { $0.type == "unknown.fixture" })
    }

    func testGatewayMessageRequestMetadataIsStable() {
        var message = HermesTUIGatewayMessage(role: .request, title: "Approval required", content: "Approve fake action", eventType: "approval.request", requestKind: .approval, requestID: "approval-test")
        XCTAssertEqual(message.role, .request)
        XCTAssertEqual(message.requestKind, .approval)
        XCTAssertFalse(message.isResolved)
        message.isResolved = true
        XCTAssertTrue(message.isResolved)
    }

    @MainActor
    func testCurrentContextUsageFormatsAndUpdatesOnlyAssistantBubble() {
        let usage = HermesTUICurrentContextUsage(used: 12_345, maximum: 131_072, percent: 9.42)
        XCTAssertEqual(usage.displayText, "Context 12.3K")
        XCTAssertEqual(usage.accessibilityText, "12,345 of 131,072 context tokens, 9.42 percent used")

        let store = HermesTUIGatewayStore()
        store.sessionID = "live-session"
        store.isStreaming = true
        store.messages = [
            HermesTUIGatewayMessage(role: .user, title: "You", content: "Question"),
            HermesTUIGatewayMessage(role: .assistant, title: "Hermes", content: "Answer")
        ]

        store.applyCurrentContextUsage(usage, eventSessionID: "live-session", allowLatestAssistant: true)

        XCTAssertNil(store.messages[0].currentContextUsage)
        XCTAssertEqual(store.messages[1].currentContextUsage, usage)
        XCTAssertEqual(store.messages.count, 2)

        store.messages[1].currentContextUsage = nil
        store.isStreaming = false
        store.applyCurrentContextUsage(usage, eventSessionID: "live-session", allowLatestAssistant: true)
        XCTAssertNil(store.messages[1].currentContextUsage)

        store.connectionStatus = "Completed"
        store.applyCurrentContextUsage(usage, eventSessionID: "live-session", allowLatestAssistant: true)
        XCTAssertEqual(store.messages[1].currentContextUsage, usage)
    }

    @MainActor
    func testCurrentContextUsageDoesNotCrossSessionOrUserTurn() {
        let store = HermesTUIGatewayStore()
        store.sessionID = "current"
        store.isStreaming = true
        store.messages = [
            HermesTUIGatewayMessage(role: .assistant, title: "Hermes", content: "Old answer"),
            HermesTUIGatewayMessage(role: .user, title: "You", content: "New question")
        ]

        store.applyCurrentContextUsage(HermesTUICurrentContextUsage(used: 500), eventSessionID: "other", allowLatestAssistant: true)
        store.applyCurrentContextUsage(HermesTUICurrentContextUsage(used: 600), eventSessionID: "current", allowLatestAssistant: true)

        XCTAssertNil(store.messages[0].currentContextUsage)
        XCTAssertNil(store.messages[1].currentContextUsage)
    }

    func testTUIGatewayConfiguresWebSocketForNativeVisionFrames() {
        let session = URLSession(configuration: .ephemeral)
        let task = session.webSocketTask(with: URL(string: "ws://127.0.0.1:9")!)

        XCTAssertEqual(task.maximumMessageSize, 1_048_576)
        HermesTUIGatewayWebSocketPolicy.configure(task)

        XCTAssertEqual(task.maximumMessageSize, 32 * 1_024 * 1_024)
    }

    func testTUIGatewayRegistersPendingResponseBeforeSendingRequest() throws {
        let source = try HermesTestAssertions.readRepositoryFile("HermesMacOS/HermesTUIGatewayView.swift")
        let requestStart = try XCTUnwrap(source.range(of: "private func request(_ method:"))
        let requestEnd = try XCTUnwrap(source.range(of: "private func webSocketURL(", range: requestStart.upperBound..<source.endIndex))
        let requestSource = source[requestStart.lowerBound..<requestEnd.lowerBound]
        let registration = try XCTUnwrap(requestSource.range(of: "pendingResponses[id] = continuation"))
        let send = try XCTUnwrap(requestSource.range(of: "try await task.send(.string(text))"))

        XCTAssertLessThan(
            requestSource.distance(from: requestSource.startIndex, to: registration.lowerBound),
            requestSource.distance(from: requestSource.startIndex, to: send.lowerBound),
            "A fast JSON-RPC response can be dropped unless its continuation is registered before WebSocket send."
        )
    }


    func testTUIGatewaySubcategoryCoverageMatchesFR007() throws {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "tui-gateway")
        XCTAssertTrue(subcategories.isSuperset(of: Set(["WebSocket authentication", "workspace create", "workspace activate", "workspace resume", "workspace close", "prompt submission", "attachment flow", "interrupt", "request-response bubbles", "event grouping", "background completion", "malformed events", "unknown events"])))
        let stream = try HermesFixtureLoader.string(named: "stream-fixtures", extension: "ndjson", subdirectory: "Streams")
        XCTAssertTrue(stream.contains("gateway.ready"))
        XCTAssertTrue(stream.contains("unknown.fixture"))
        XCTAssertTrue(HermesMacOSTestCoverageMap.category("tui-gateway").defaultCoverage.contains { $0.contains("TUIGatewayWorkflowTests") })
    }
}
