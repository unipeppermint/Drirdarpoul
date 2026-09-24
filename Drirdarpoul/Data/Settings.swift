import Foundation

final class Settings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["cardTrace.hapticsEnabled": true, "cardTrace.largerText": false])
    }

    var hapticsEnabled: Bool {
        get { defaults.bool(forKey: "cardTrace.hapticsEnabled") }
        set { defaults.set(newValue, forKey: "cardTrace.hapticsEnabled") }
    }

    /// A supplemental reading preference; system Dynamic Type is always respected.
    var largerText: Bool {
        get { defaults.bool(forKey: "cardTrace.largerText") }
        set { defaults.set(newValue, forKey: "cardTrace.largerText") }
    }
}
