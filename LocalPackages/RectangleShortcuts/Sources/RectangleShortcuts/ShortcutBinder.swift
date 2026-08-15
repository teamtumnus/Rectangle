import Foundation

public final class ShortcutBinder {
    public static let shared = ShortcutBinder()

    public let shortcutMonitor: HotKeyMonitoring

    private struct Binding {
        let action: () -> Void
        var shortcut: KeyboardShortcut?
    }

    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private var bindings = [String: Binding]()
    private var defaultShortcuts = [String: KeyboardShortcut]()
    private var defaultsObserver: NSObjectProtocol?
    private var isChangingDefaults = false

    public convenience init() {
        self.init(
            userDefaults: .standard,
            shortcutMonitor: HotKeyMonitor.shared,
            notificationCenter: .default
        )
    }

    init(
        userDefaults: UserDefaults,
        shortcutMonitor: HotKeyMonitoring,
        notificationCenter: NotificationCenter
    ) {
        self.userDefaults = userDefaults
        self.shortcutMonitor = shortcutMonitor
        self.notificationCenter = notificationCenter
        defaultsObserver = notificationCenter.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: .main
        ) { [weak self] _ in
            self?.reloadChangedBindings()
        }
    }

    deinit {
        if let defaultsObserver {
            notificationCenter.removeObserver(defaultsObserver)
        }
        for key in Array(bindings.keys) {
            breakBinding(withDefaultsKey: key)
        }
    }

    public func registerDefaultShortcuts(_ shortcuts: [String: KeyboardShortcut]) {
        defaultShortcuts.merge(shortcuts) { _, new in new }

        isChangingDefaults = true
        for (key, shortcut) in shortcuts {
            if let storedValue = userDefaults.object(forKey: key),
               !Self.isExplicitlyCleared(storedValue),
               Self.shortcut(from: storedValue) == nil {
                // Archived or malformed values are intentionally unsupported.
                // Removing them exposes Rectangle's registered default.
                userDefaults.removeObject(forKey: key)
            }
            userDefaults.register(defaults: [key: shortcut.dictionaryRepresentation])
        }
        isChangingDefaults = false
        reloadChangedBindings()
    }

    public func bindShortcut(
        withDefaultsKey defaultsKey: String,
        toAction action: @escaping () -> Void
    ) {
        precondition(!defaultsKey.contains(".") && !defaultsKey.contains(" "))
        breakBinding(withDefaultsKey: defaultsKey)
        bindings[defaultsKey] = Binding(action: action, shortcut: nil)
        reloadBinding(forKey: defaultsKey)
    }

    public func breakBinding(withDefaultsKey defaultsKey: String) {
        if let shortcut = bindings[defaultsKey]?.shortcut {
            shortcutMonitor.unregisterShortcut(shortcut)
        }
        bindings.removeValue(forKey: defaultsKey)
    }

    public func isRegisteredAction(_ defaultsKey: String) -> Bool {
        bindings[defaultsKey] != nil
    }

    private func reloadChangedBindings() {
        guard !isChangingDefaults else { return }
        for key in Array(bindings.keys) {
            reloadBinding(forKey: key)
        }
    }

    private func reloadBinding(forKey key: String) {
        guard var binding = bindings[key] else { return }
        let newShortcut = Self.shortcut(from: userDefaults.object(forKey: key))
            ?? fallbackShortcut(forKey: key)
        guard newShortcut != binding.shortcut else { return }

        if let oldShortcut = binding.shortcut {
            shortcutMonitor.unregisterShortcut(oldShortcut)
        }

        binding.shortcut = newShortcut
        bindings[key] = binding
        if let newShortcut {
            _ = shortcutMonitor.registerShortcut(newShortcut, action: binding.action)
        }
    }

    private func fallbackShortcut(forKey key: String) -> KeyboardShortcut? {
        guard userDefaults.object(forKey: key) == nil else { return nil }
        return defaultShortcuts[key]
    }

    private static func shortcut(from value: Any?) -> KeyboardShortcut? {
        guard let dictionary = value as? [String: Any] else { return nil }
        return KeyboardShortcut(dictionaryRepresentation: dictionary)
    }

    private static func isExplicitlyCleared(_ value: Any) -> Bool {
        guard let dictionary = value as? [String: Any] else { return false }
        return dictionary.isEmpty
    }
}
