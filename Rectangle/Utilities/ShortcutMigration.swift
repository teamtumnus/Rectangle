/// ShortcutMigration.swift

import Foundation

class ShortcutMigration {
    static func syncRenamedSideShortcutAliases(userDefaults: UserDefaults = .standard) {
        for action in WindowAction.active {
            guard let aliasName = action.aliasName,
                  let aliasValue = userDefaults.object(forKey: aliasName)
            else { continue }

            if let currentValue = userDefaults.object(forKey: action.name) as? NSObject,
               let aliasObject = aliasValue as? NSObject,
               currentValue.isEqual(aliasObject) {
                userDefaults.removeObject(forKey: aliasName)
                continue
            }

            userDefaults.set(aliasValue, forKey: action.name)
            userDefaults.removeObject(forKey: aliasName)
        }
    }

}
