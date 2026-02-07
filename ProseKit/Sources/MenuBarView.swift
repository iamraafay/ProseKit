// MenuBarView.swift
// ProseKit — SwiftUI menu bar dropdown UI.
//
// Shows:
// - Current status (model downloading, ready, processing)
// - Mode selector (Grammar, Concise, Casual, Professional)
// - Last rewrite time
// - Settings and Quit

import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var coordinator: RewriteCoordinator
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Status Section ───────────────────────────────────

            statusSection

            Divider()

            // ── Mode Selector ────────────────────────────────────

            modeSection

            Divider()

            // ── Actions ──────────────────────────────────────────

            actionsSection

            Divider()

            // ── Footer ──────────────────────────────────────────

            footerSection
        }
        .frame(width: 260)
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // App name and status
            HStack {
                Text("ProseKit")
                    .font(.headline)
                Spacer()
                statusBadge
            }

            // Processing status or model status
            if appState.isProcessing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(appState.processingStatus.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if case .downloading(let progress) = appState.modelStatus {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: progress)
                        .controlSize(.small)
                    Text("Downloading model: \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if appState.lastRewriteTime > 0 {
                Text("Last rewrite: \(String(format: "%.1fs", appState.lastRewriteTime))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Accessibility warning
            if !appState.hasAccessibilityPermission {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("Accessibility permission required")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onTapGesture {
                    openAccessibilitySettings()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch appState.modelStatus {
        case .ready:
            Text("Ready")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.green.opacity(0.2))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        case .downloading:
            Text("Downloading")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.2))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        case .loading:
            Text("Loading")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.2))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
        case .error:
            Text("Error")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.red.opacity(0.2))
                .foregroundStyle(.red)
                .clipShape(Capsule())
        case .notDownloaded:
            Text("Setup needed")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.gray.opacity(0.2))
                .foregroundStyle(.secondary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Mode Selector

    @ViewBuilder
    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Rewrite Mode")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.top, 6)

            ForEach(RewriteMode.allCases) { mode in
                Button(action: {
                    appState.currentMode = mode
                    settingsStore.defaultMode = mode
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: mode.sfSymbol)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(mode.rawValue)
                                .font(.body)
                            Text(mode.menuDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if appState.currentMode == mode {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        Text("⌘\(String(mode.shortcutKey))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: 0) {
            // Rewrite now (manual trigger)
            Button(action: {
                Task {
                    await coordinator.rewrite(mode: appState.currentMode, appState: appState)
                }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Rewrite Now")
                    Spacer()
                    Text("⌘⇧G")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .disabled(!appState.isReady || appState.isProcessing)

            // Undo
            Button(action: {
                coordinator.undo(appState: appState)
            }) {
                HStack {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo Last Rewrite")
                    Spacer()
                    Text("⌘⇧Z")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .disabled(!coordinator.undoBuffer.canUndo)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: 0) {
            // Stats
            if appState.rewriteCount > 0 {
                HStack {
                    Text("\(appState.rewriteCount) rewrites this session")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            // Quit
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Text("Quit ProseKit")
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
