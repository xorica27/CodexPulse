import AppKit
import CodexPulseCore
import Foundation

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store = RateLimitStore()
    private let settingsStore = SettingsStore()
    private let notificationManager = NotificationManager()
    private let launchAtLogin = LaunchAtLoginManager()
    private var preferencesWindowController: PreferencesWindowController?
    private let aboutWindowController = AboutWindowController()
    private var timer: Timer?

    override init() {
        super.init()
        configureStatusButton()
        store.onChange = { [weak self] in
            self?.updateStatusTitle()
            self?.rebuildMenu()
            self?.processNotifications()
        }
        settingsStore.onChange = { [weak self] in
            self?.updateStatusTitle()
            self?.rebuildMenu()
            self?.rescheduleTimer()
            self?.processNotifications()
        }
        rebuildMenu()
        updateStatusTitle()
    }

    func start() {
        store.refresh()
        rescheduleTimer()
    }

    private func updateStatusTitle() {
        let settings = settingsStore.settings
        let title = DisplayFormatter.statusTitle(
            for: store.data,
            mode: settings.displayMode,
            percentDisplay: settings.percentDisplay,
            staleAfterMinutes: settings.staleAfterMinutes
        )
        statusItem.button?.title = "  \(title)"
        statusItem.button?.toolTip = "CodexPulse \(title)"
        statusItem.button?.setAccessibilityLabel("CodexPulse \(title)")
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        button.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.toolTip = "CodexPulse"
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown

        if let image = Self.loadMenuBarIcon() {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            button.image = image
        }
    }

    private static func loadMenuBarIcon() -> NSImage? {
        let fileName = "CodexPulseMenuTemplate"

        if let url = Bundle.main.url(forResource: fileName, withExtension: "pdf"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: fileName, withExtension: "pdf"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        #endif

        return nil
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        if let data = store.data {
            menu.addItem(disabled(DisplayFormatter.detailLine(label: "5-hour window", window: data.snapshot.primary)))
            menu.addItem(disabled(DisplayFormatter.detailLine(label: "Weekly window", window: data.snapshot.secondary)))
            menu.addItem(disabled("Plan: \(data.snapshot.planType ?? "unknown")"))
            menu.addItem(disabled("Source: \(data.source.rawValue), updated \(DisplayFormatter.relativeAge(data.fetchedAt))"))
            if let message = data.errorMessage {
                menu.addItem(disabled("Fallback reason: \(message)"))
            }
        } else {
            menu.addItem(disabled("Codex rate limits unavailable"))
        }

        if store.emptyState != .available {
            menu.addItem(disabled(store.emptyState.menuMessage))
        }

        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let preferences = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(preferences)

        let launch = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = launchAtLogin.isEnabled ? .on : .off
        menu.addItem(launch)

        menu.addItem(.separator())
        let updates = NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        let about = NSMenuItem(title: "About CodexPulse", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit CodexPulse", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc private func refreshNow() {
        store.refresh()
    }

    @objc private func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(
                settingsStore: settingsStore,
                rateLimitStore: store,
                notificationManager: notificationManager
            )
        }
        preferencesWindowController?.show()
    }

    @objc private func checkForUpdates() {
        guard let url = URL(string: "https://github.com/xorica27/CodexPulse/releases/latest") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func showAbout() {
        aboutWindowController.show()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
        } catch {
            showError("Could not update launch-at-login setting: \(error.localizedDescription)")
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "CodexPulse"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func rescheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settingsStore.settings.refreshInterval.seconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.store.refresh()
            }
        }
    }

    private func processNotifications() {
        notificationManager.process(data: store.data, settings: settingsStore.settings)
    }
}
