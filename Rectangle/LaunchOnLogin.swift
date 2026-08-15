/// LaunchOnLogin.swift

import Foundation
import ServiceManagement
import os.log

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

@available(macOS 13.0, *)
public enum LaunchOnLogin {
    public static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status == .enabled {
                        try? SMAppService.mainApp.unregister()
                    }
                    
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                os_log("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        }
    }
}
