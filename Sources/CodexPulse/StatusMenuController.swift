import AppKit
import CodexPulseCore
import Foundation

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private enum Keys {
        static let displayMode = "displayMode"
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store = RateLimitStore()
    private let launchAtLogin = LaunchAtLoginManager()
    private let userDefaults: UserDefaults
    private var timer: Timer?
    private var displayMode: DisplayMode {
        didSet {
            userDefaults.set(displayMode.rawValue, forKey: Keys.displayMode)
            updateStatusTitle()
            rebuildMenu()
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.displayMode = DisplayMode(rawValue: userDefaults.string(forKey: Keys.displayMode) ?? "") ?? .both
        super.init()
        configureStatusButton()
        store.onChange = { [weak self] in
            self?.updateStatusTitle()
            self?.rebuildMenu()
        }
        rebuildMenu()
        updateStatusTitle()
    }

    func start() {
        store.refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.store.refresh()
            }
        }
    }

    private func updateStatusTitle() {
        let title = DisplayFormatter.statusTitle(for: store.data, mode: displayMode)
        statusItem.button?.title = title
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

            if !data.additionalLimits.isEmpty {
                menu.addItem(.separator())
                menu.addItem(disabled("Additional limits"))
                for (name, snapshot) in data.additionalLimits.sorted(by: { $0.key < $1.key }) {
                    let five = DisplayFormatter.percentText(snapshot.primary)
                    let weekly = DisplayFormatter.percentText(snapshot.secondary)
                    menu.addItem(disabled("\(name): 5h \(five), W \(weekly)"))
                }
            }
        } else {
            menu.addItem(disabled("Codex rate limits unavailable"))
        }

        menu.addItem(.separator())
        menu.addItem(disabled("Display"))
        for mode in DisplayMode.allCases {
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(setDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == displayMode ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let launch = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = launchAtLogin.isEnabled ? .on : .off
        menu.addItem(launch)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit CodexPulse", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc private func setDisplayMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = DisplayMode(rawValue: rawValue) else {
            return
        }
        displayMode = mode
    }

    @objc private func refreshNow() {
        store.refresh()
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
}
