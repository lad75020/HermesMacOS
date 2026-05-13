//
//  HermesConfigurationView.swift
//  HermesMacOS
//

import SwiftUI
import WebKit

struct HermesConfigurationView: View {
    @AppStorage(hermesDashboardURLStorageKey) private var dashboardURL = defaultHermesDashboardURL
    @State private var reloadToken = UUID()

    private var normalizedDashboardURL: URL? {
        HermesConfigurationWebURL.normalizedURL(from: dashboardURL)
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            Group {
                if let normalizedDashboardURL {
                    HermesDashboardWebView(url: normalizedDashboardURL, reloadToken: reloadToken)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                } else {
                    ContentUnavailableView(
                        "Dashboard URL required",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Set the Hermes Dashboard URL in Settings, then return here to load Configuration.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.72), cornerRadius: 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(18)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("Configuration", systemImage: "gearshape.2")
                .font(.title2.weight(.semibold))
            Button {
                reloadToken = UUID()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderedProminent)
            .disabled(normalizedDashboardURL == nil)
            .help("Reload")
            .accessibilityLabel("Reload")
            Spacer()
            Text("Hermes Dashboard")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.hermesSecondaryText)
        }
        .padding(18)
        .hermesGlassPanel(cornerRadius: 18)
    }
}

private enum HermesConfigurationWebURL {
    static func normalizedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return url
        }
        return URL(string: "https://\(trimmed)").flatMap { $0.host == nil ? nil : $0 }
    }
}

struct HermesDashboardWebView: NSViewRepresentable {
    let url: URL
    let reloadToken: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.lastLoadedURL = url
        context.coordinator.lastReloadToken = reloadToken
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastLoadedURL != url {
            context.coordinator.lastLoadedURL = url
            context.coordinator.lastReloadToken = reloadToken
            webView.load(URLRequest(url: url))
            return
        }

        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            webView.reload()
        }
    }

    final class Coordinator {
        var lastLoadedURL: URL?
        var lastReloadToken: UUID?
    }
}
