//
//  SplashView.swift
//  HermesMacOS
//

import AVFoundation
import SwiftUI

struct SplashView: View {
    private var splashVideoURL: URL? {
        Bundle.main.url(forResource: "HermesSplash", withExtension: "mp4")
            ?? Bundle.main.url(forResource: "HermesSplash", withExtension: "mp4", subdirectory: "Resources")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let splashVideoURL {
                SplashVideoPlayer(url: splashVideoURL)
                    .ignoresSafeArea()
            } else {
                SplashFallbackView()
            }
        }
        .accessibilityLabel("Hermes splash screen")
    }
}

private struct SplashFallbackView: View {
    var body: some View {
        ZStack {
            HermesLiquidGlassCanvas().ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 72, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.hermesActionBlue)

                Text("Hermes")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
    }
}

private struct SplashVideoPlayer: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SplashVideoPlayerView {
        let view = SplashVideoPlayerView()
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none
        view.playerLayer.player = player
        context.coordinator.player = player
        context.coordinator.observeLoop(for: player)
        player.play()
        return view
    }

    func updateNSView(_ nsView: SplashVideoPlayerView, context: Context) {
        if context.coordinator.player == nil || nsView.playerLayer.player == nil {
            let player = AVPlayer(url: url)
            player.isMuted = true
            player.actionAtItemEnd = .none
            nsView.playerLayer.player = player
            context.coordinator.player = player
            context.coordinator.observeLoop(for: player)
            player.play()
        }
    }

    static func dismantleNSView(_ nsView: SplashVideoPlayerView, coordinator: Coordinator) {
        coordinator.stop()
        nsView.playerLayer.player = nil
    }

    final class Coordinator {
        var player: AVPlayer?
        private var loopObserver: NSObjectProtocol?

        func observeLoop(for player: AVPlayer) {
            if let loopObserver {
                NotificationCenter.default.removeObserver(loopObserver)
            }

            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }

        func stop() {
            player?.pause()
            player = nil
            if let loopObserver {
                NotificationCenter.default.removeObserver(loopObserver)
                self.loopObserver = nil
            }
        }
    }
}

private final class SplashVideoPlayerView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}
