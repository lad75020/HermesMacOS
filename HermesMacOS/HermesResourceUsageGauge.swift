//
//  HermesResourceUsageGauge.swift
//  HermesMacOS
//

import SwiftUI

enum HermesResourceUsageKind: Sendable {
    case memory
    case gpu

    var label: String {
        switch self {
        case .memory: String(localized: "Memory")
        case .gpu: String(localized: "GPU")
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .memory: String(localized: "Memory usage")
        case .gpu: String(localized: "GPU usage")
        }
    }

    var tint: Color {
        switch self {
        case .memory: .hermesPurple
        case .gpu: .hermesActionBlue
        }
    }
}

struct HermesResourceUsageGauge: View {
    let kind: HermesResourceUsageKind
    let snapshot: HermesResourceUsageSnapshot?
    let availability: HermesResourceUsageAvailability

    private var percentage: Double? {
        guard let snapshot else { return nil }
        switch kind {
        case .memory: return snapshot.memoryPercentage
        case .gpu: return snapshot.gpuPercentage
        }
    }

    private var statusText: String {
        switch availability {
        case .fresh: percentage.map(formatPercentage) ?? String(localized: "Unavailable")
        case .stale: String(localized: "Stale")
        case .unavailable: String(localized: "Unavailable")
        }
    }

    private var accessibilityValue: String {
        switch availability {
        case .fresh:
            return percentage.map(formatPercentage) ?? String(localized: "Unavailable")
        case .stale:
            if let percentage { return "\(formatPercentage(percentage)), \(String(localized: "Stale"))" }
            return String(localized: "Unavailable")
        case .unavailable:
            return String(localized: "Unavailable")
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.13), lineWidth: 5)
                if let percentage {
                    Circle()
                        .trim(from: 0, to: percentage / 100)
                        .stroke(kind.tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                } else {
                    Circle()
                        .stroke(kind.tint.opacity(0.32), style: StrokeStyle(lineWidth: 5, dash: [2, 2]))
                }
                Text(percentage.map(formatPercentage) ?? "—")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .frame(width: 34, height: 34)

            Text(kind.label)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
            Text(statusText)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(availability == .fresh ? Color.hermesSecondaryText : kind.tint)
                .lineLimit(1)
        }
        .frame(width: 44)
        .padding(.vertical, 5)
        .hermesGlassPanel(tint: kind.tint.opacity(0.08), cornerRadius: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private func formatPercentage(_ percentage: Double) -> String {
        let number = percentage.formatted(.number.precision(.fractionLength(0...1)))
        return String(format: String(localized: "%@%%"), locale: .autoupdatingCurrent, number)
    }
}
