import AppKit
import CodexPulseCore
import SwiftUI

@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?
    private let settingsStore: SettingsStore
    private let rateLimitStore: RateLimitStore
    private let notificationManager: NotificationManager

    init(
        settingsStore: SettingsStore,
        rateLimitStore: RateLimitStore,
        notificationManager: NotificationManager
    ) {
        self.settingsStore = settingsStore
        self.rateLimitStore = rateLimitStore
        self.notificationManager = notificationManager
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = PreferencesView(
            settingsStore: settingsStore,
            rateLimitStore: rateLimitStore,
            notificationManager: notificationManager
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CodexPulse Preferences"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

private struct PreferencesView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var rateLimitStore: RateLimitStore
    let notificationManager: NotificationManager

    private var settings: CodexPulseSettings {
        settingsStore.settings
    }

    var body: some View {
        TabView {
            displayTab
                .tabItem { Text("Display") }
            alertsTab
                .tabItem { Text("Alerts") }
            diagnosticsTab
                .tabItem { Text("Diagnostics") }
        }
        .padding(20)
        .frame(width: 520, height: 520)
    }

    private var displayTab: some View {
        Form {
            Picker("Menu bar", selection: binding(\.displayMode)) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.menuTitle).tag(mode)
                }
            }

            Picker("Percent", selection: binding(\.percentDisplay)) {
                ForEach(PercentDisplay.allCases, id: \.self) { mode in
                    Text(mode.menuTitle).tag(mode)
                }
            }

            Picker("Refresh", selection: binding(\.refreshInterval)) {
                ForEach(RefreshInterval.allCases, id: \.self) { interval in
                    Text(interval.menuTitle).tag(interval)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var alertsTab: some View {
        Form {
            Toggle("Enable notifications", isOn: Binding(
                get: { settings.notificationsEnabled },
                set: { enabled in
                    settingsStore.update { $0.notificationsEnabled = enabled }
                    if enabled {
                        notificationManager.requestAuthorizationIfNeeded()
                    }
                }
            ))

            Section("5-hour warnings") {
                ForEach([20, 10, 5], id: \.self) { threshold in
                    Toggle("\(threshold)% remaining", isOn: thresholdBinding(threshold, keyPath: \.notifyFiveHourThresholds))
                }
            }

            Section("Weekly warnings") {
                ForEach([20, 10, 5], id: \.self) { threshold in
                    Toggle("\(threshold)% remaining", isOn: thresholdBinding(threshold, keyPath: \.notifyWeeklyThresholds))
                }
            }

            Stepper(
                "Stale data alert after \(settings.staleAfterMinutes) minutes",
                value: Binding(
                    get: { settings.staleAfterMinutes },
                    set: { value in settingsStore.update { $0.staleAfterMinutes = value } }
                ),
                in: 5...120,
                step: 5
            )
        }
        .formStyle(.grouped)
    }

    private var diagnosticsTab: some View {
        Form {
            Section("Current status") {
                Text(rateLimitStore.emptyState.menuMessage)
                Text("Source: \(rateLimitStore.data?.source.rawValue ?? "none")")
                Text("Last update: \(rateLimitStore.data.map { DisplayFormatter.relativeAge($0.fetchedAt) } ?? "never")")
            }

            Section("Codex") {
                Text("Plan: \(rateLimitStore.data?.snapshot.planType ?? "unknown")")
                Text("5-hour: \(DisplayFormatter.detailLine(label: "", window: rateLimitStore.data?.snapshot.primary).trimmingCharacters(in: CharacterSet(charactersIn: ": ")))")
                Text("Weekly: \(DisplayFormatter.detailLine(label: "", window: rateLimitStore.data?.snapshot.secondary).trimmingCharacters(in: CharacterSet(charactersIn: ": ")))")
            }

            Section("Last error") {
                Text(rateLimitStore.lastErrorMessage ?? "No recent error")
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<CodexPulseSettings, Value>) -> Binding<Value> {
        Binding(
            get: { settingsStore.settings[keyPath: keyPath] },
            set: { value in settingsStore.update { $0[keyPath: keyPath] = value } }
        )
    }

    private func thresholdBinding(
        _ threshold: Int,
        keyPath: WritableKeyPath<CodexPulseSettings, [Int]>
    ) -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings[keyPath: keyPath].contains(threshold) },
            set: { enabled in
                settingsStore.update { settings in
                    if enabled {
                        settings[keyPath: keyPath].append(threshold)
                    } else {
                        settings[keyPath: keyPath].removeAll { $0 == threshold }
                    }
                }
            }
        )
    }
}
