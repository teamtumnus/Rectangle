/// LaunchOnLoginPreferenceResolver.swift

import Foundation

struct LaunchOnLoginPreferenceResolver {
    static let preferenceKey = "launchOnLogin"

    let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func resolve(prompt: () -> Bool) -> Bool {
        if userDefaults.object(forKey: Self.preferenceKey) != nil {
            return userDefaults.bool(forKey: Self.preferenceKey)
        }

        let enabled = prompt()
        userDefaults.set(enabled, forKey: Self.preferenceKey)
        return enabled
    }
}
