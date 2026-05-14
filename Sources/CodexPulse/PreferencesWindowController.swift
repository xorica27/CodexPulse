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
        window.title = L10n.text("preferences.title")
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
                .tabItem { Text(L10n.text("preferences.tab.display")) }
            alertsTab
                .tabItem { Text(L10n.text("preferences.tab.alerts")) }
            diagnosticsTab
                .tabItem { Text(L10n.text("preferences.tab.diagnostics")) }
        }
        .padding(20)
        .frame(width: 520, height: 520)
    }

    private var displayTab: some View {
        Form {
            Picker(L10n.text("preferences.menuBar"), selection: binding(\.displayMode)) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(L10n.displayModeTitle(mode)).tag(mode)
                }
            }

            Picker(L10n.text("preferences.percent"), selection: binding(\.percentDisplay)) {
                ForEach(PercentDisplay.allCases, id: \.self) { mode in
                    Text(L10n.percentDisplayTitle(mode)).tag(mode)
                }
            }

            Picker(L10n.text("preferences.language"), selection: binding(\.appLanguage)) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Text(L10n.appLanguageTitle(language)).tag(language)
                }
            }

            Picker(L10n.text("preferences.refresh"), selection: binding(\.refreshInterval)) {
                ForEach(RefreshInterval.allCases, id: \.self) { interval in
                    Text(L10n.refreshIntervalTitle(interval)).tag(interval)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var alertsTab: some View {
        Form {
            Toggle(L10n.text("preferences.notifications"), isOn: Binding(
                get: { settings.notificationsEnabled },
                set: { enabled in
                    settingsStore.update { $0.notificationsEnabled = enabled }
                    if enabled {
                        notificationManager.requestAuthorizationIfNeeded()
                    }
                }
            ))

            Section(L10n.text("preferences.fiveHourWarnings")) {
                ForEach([20, 10, 5], id: \.self) { threshold in
                    Toggle(L10n.format("preferences.thresholdRemaining", threshold), isOn: thresholdBinding(threshold, keyPath: \.notifyFiveHourThresholds))
                }
            }

            Section(L10n.text("preferences.weeklyWarnings")) {
                ForEach([20, 10, 5], id: \.self) { threshold in
                    Toggle(L10n.format("preferences.thresholdRemaining", threshold), isOn: thresholdBinding(threshold, keyPath: \.notifyWeeklyThresholds))
                }
            }

            Stepper(
                L10n.format("preferences.staleAlertAfter", settings.staleAfterMinutes),
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
            Section(L10n.text("preferences.currentStatus")) {
                Text(L10n.emptyStateMessage(rateLimitStore.emptyState))
                Text(L10n.format("preferences.source", rateLimitStore.data?.source.rawValue ?? L10n.text("generic.none")))
                Text(L10n.format("preferences.lastUpdate", rateLimitStore.data.map { LocalizedDisplayFormatter.relativeAge($0.fetchedAt) } ?? L10n.text("generic.never")))
            }

            Section(L10n.text("preferences.codex")) {
                Text(L10n.format("preferences.plan", rateLimitStore.data?.snapshot.planType ?? L10n.text("generic.unknown")))
                Text(L10n.format("preferences.fiveHour", windowSummary(rateLimitStore.data?.snapshot.primary)))
                Text(L10n.format("preferences.weekly", windowSummary(rateLimitStore.data?.snapshot.secondary)))
            }

            Section(L10n.text("preferences.lastError")) {
                Text(rateLimitStore.lastErrorMessage ?? L10n.text("preferences.noRecentError"))
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

    private func windowSummary(_ window: RateLimitWindow?) -> String {
        LocalizedDisplayFormatter
            .detailLine(label: "", window: window)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":： "))
    }
}
