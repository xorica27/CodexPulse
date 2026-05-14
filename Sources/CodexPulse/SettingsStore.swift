import CodexPulseCore
import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var settings: CodexPulseSettings {
        didSet {
            settings.save(to: userDefaults)
            onChange?()
        }
    }

    var onChange: (() -> Void)?

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = CodexPulseSettings.load(from: userDefaults)
        L10n.useLanguage(settings.appLanguage)
    }

    func update(_ mutate: (inout CodexPulseSettings) -> Void) {
        var next = settings
        mutate(&next)
        let normalized = next.normalized()
        L10n.useLanguage(normalized.appLanguage)
        settings = normalized
    }
}
