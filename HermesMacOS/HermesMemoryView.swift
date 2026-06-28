//
//  HermesMemoryView.swift
//  HermesMacOS
//

import SwiftUI

struct HermesMemoryView: View {
    @Bindable var store: HermesMemoryStore
    @State private var pendingDeleteEntry: MemoryEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            controls
            statusArea
            memoryList
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await store.load() }
        .confirmationDialog(
            pendingDeleteEntry.map { "Delete memory \($0.id)?" } ?? "Delete memory?",
            isPresented: Binding(
                get: { pendingDeleteEntry != nil },
                set: { if !$0 { pendingDeleteEntry = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeleteEntry
        ) { entry in
            Button("Delete Memory", role: .destructive) {
                Task { await store.delete(entry) }
                pendingDeleteEntry = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteEntry = nil }
        } message: { entry in
            Text("This invalidates the selected Hindsight memory after provider confirmation. Preview: \(entry.preview)")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Memory", systemImage: "brain.head.profile")
                .font(.largeTitle.weight(.semibold))
            Text("Browse, filter, and delete readable Hindsight memories without exposing raw provider debug output.")
                .font(.subheadline)
                .foregroundStyle(Color.hermesSecondaryText)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TextField("Filter memories", text: $store.filterText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { store.applyFilterChange() }
                    .accessibilityLabel("Filter memories")
                Button {
                    store.applyFilterChange()
                } label: {
                    Label("Apply Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Apply memory filter")
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
                .accessibilityLabel("Refresh memories")
            }
            HStack(spacing: 12) {
                Button {
                    Task { await store.previousPage() }
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(!store.canGoPrevious)
                .accessibilityLabel("Previous memory page")

                Button {
                    Task { await store.nextPage() }
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .disabled(!store.canGoNext)
                .accessibilityLabel("Next memory page")

                Text(store.rangeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.hermesSecondaryText)
                    .accessibilityLabel("Memory range: \(store.rangeText)")
                if store.isLoading { ProgressView().controlSize(.small) }
            }
        }
        .padding(14)
        .hermesGlassPanel(tint: Color.white.opacity(0.05), cornerRadius: 18)
    }

    @ViewBuilder
    private var statusArea: some View {
        if let errorMessage = store.errorMessage, !errorMessage.isEmpty {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(Color.hermesDestructive)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hermesGlassPanel(tint: Color.hermesDestructive.opacity(0.08), cornerRadius: 14)
                .accessibilityLabel("Memory provider error: \(errorMessage)")
        } else if let statusMessage = store.statusMessage, !statusMessage.isEmpty {
            Label(statusMessage, systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(Color.hermesSecondaryText)
                .accessibilityLabel(statusMessage)
        }
    }

    @ViewBuilder
    private var memoryList: some View {
        if store.entries.isEmpty && !store.isLoading {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.emptyStateTitle)
                    .font(.headline)
                Text("Use Refresh to retry the active Hindsight provider. Default tests use fixtures; live provider access is opt-in.")
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hermesGlassPanel(tint: Color.white.opacity(0.04), cornerRadius: 18)
            .accessibilityLabel(store.emptyStateTitle)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.entries) { entry in
                        HermesMemoryRow(
                            entry: entry,
                            isDeleting: store.deleteInFlightID == entry.id,
                            onDelete: { pendingDeleteEntry = entry }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct HermesMemoryRow: View {
    let entry: MemoryEntry
    let isDeleting: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "brain")
                .foregroundStyle(Color.hermesActionBlue)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.hermesSecondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        if isDeleting {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isDeleting)
                    .accessibilityLabel("Delete memory \(entry.id)")
                    .accessibilityHint("Shows a confirmation before deleting this Hindsight memory")
                }
                Text(entry.preview)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !entry.metadataSummary.isEmpty {
                    Text(entry.metadataSummary)
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesGlassPanel(tint: Color.white.opacity(0.04), cornerRadius: 18)
        .accessibilityElement(children: .contain)
    }
}
