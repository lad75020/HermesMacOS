//
//  HermesConfigurationView.swift
//  HermesMacOS
//

import SwiftUI
import WebKit

struct HermesConfigurationView: View {
    @AppStorage(hermesDashboardURLStorageKey) private var dashboardURL = defaultHermesDashboardURL
    let webViewStore: HermesDashboardWebViewStore
    let colorScheme: ColorScheme
    @State private var reloadToken = UUID()

    private var normalizedDashboardURL: URL? {
        HermesConfigurationWebURL.normalizedURL(from: dashboardURL, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            Group {
                if let normalizedDashboardURL {
                    HermesDashboardWebView(store: webViewStore, url: normalizedDashboardURL, reloadToken: reloadToken)
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
                .hermesWebsiteTitleFont(size: 22, weight: .bold)
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
                .hermesWebsiteLabelFont(size: 11, weight: .bold)
                .foregroundStyle(Color.hermesSecondaryText)
        }
        .padding(18)
        .hermesGlassPanel(cornerRadius: 18)
    }
}

private enum HermesConfigurationWebURL {
    static func normalizedURL(from string: String, colorScheme: ColorScheme) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let baseURL: URL?
        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            baseURL = url
        } else {
            baseURL = URL(string: "https://\(trimmed)").flatMap { $0.host == nil ? nil : $0 }
        }

        guard let baseURL else { return nil }
        return themedURL(from: baseURL, colorScheme: colorScheme)
    }

    private static let darkDashboardThemeName = "mono"
    private static let lightDashboardThemeName = "solarized-light"

    private static func themedURL(from url: URL, colorScheme: ColorScheme) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var queryItems = components.queryItems?.filter { $0.name.lowercased() != "theme" } ?? []
        queryItems.append(URLQueryItem(name: "theme", value: colorScheme == .dark ? darkDashboardThemeName : lightDashboardThemeName))
        components.queryItems = queryItems
        return components.url
    }
}

@MainActor
final class HermesDashboardWebViewStore {
    let webView: WKWebView
    private var lastLoadedURL: URL?
    private var lastReloadToken: UUID?

    private static let themeOverrideScript = """
    (() => {
      const desiredTheme = new URLSearchParams(window.location.search).get('theme');
      if (!desiredTheme) return;

      const storageKey = 'hermes-dashboard-theme';
      window.localStorage.setItem(storageKey, desiredTheme);

      const originalFetch = window.fetch;
      if (typeof originalFetch !== 'function' || window.__hermesConfigurationThemeFetchPatched) return;
      window.__hermesConfigurationThemeFetchPatched = true;

      window.fetch = (...args) => {
        return originalFetch(...args).then(async (response) => {
          try {
            const input = args[0];
            const url = typeof input === 'string' ? input : (input && input.url) || '';
            if (url.includes('/api/dashboard/themes') && response.ok) {
              const body = await response.clone().json();
              body.active = desiredTheme;
              const headers = new Headers(response.headers);
              headers.set('content-type', 'application/json');
              return new Response(JSON.stringify(body), {
                status: response.status,
                statusText: response.statusText,
                headers,
              });
            }
          } catch (_) {}
          return response;
        });
      };
    })();
    """

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.themeOverrideScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
    }

    func loadIfNeeded(url: URL, reloadToken: UUID) {
        if lastLoadedURL != url {
            lastLoadedURL = url
            lastReloadToken = reloadToken
            webView.load(URLRequest(url: url))
            return
        }

        if lastReloadToken != reloadToken {
            lastReloadToken = reloadToken
            webView.reload()
        }
    }
}

struct HermesDashboardWebView: NSViewRepresentable {
    let store: HermesDashboardWebViewStore
    let url: URL
    let reloadToken: UUID

    func makeNSView(context: Context) -> WKWebView {
        store.loadIfNeeded(url: url, reloadToken: reloadToken)
        return store.webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        store.loadIfNeeded(url: url, reloadToken: reloadToken)
    }
}
