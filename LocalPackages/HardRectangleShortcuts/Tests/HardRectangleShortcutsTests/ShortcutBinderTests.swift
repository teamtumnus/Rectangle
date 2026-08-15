import AppKit
import Carbon.HIToolbox
import XCTest
@testable import HardRectangleShortcuts

private final class FakeHotKeyMonitor: HotKeyMonitoring {
    var registered = [KeyboardShortcut: () -> Void]()
    var registrationHistory = [KeyboardShortcut]()
    var unregistrationHistory = [KeyboardShortcut]()
    var registrationResult = true

    func registerShortcut(_ shortcut: KeyboardShortcut, action: @escaping () -> Void) -> Bool {
        registrationHistory.append(shortcut)
        guard registrationResult else { return false }
        registered[shortcut] = action
        return true
    }

    func unregisterShortcut(_ shortcut: KeyboardShortcut) {
        unregistrationHistory.append(shortcut)
        registered.removeValue(forKey: shortcut)
    }

    func unregisterAllShortcuts() {
        unregistrationHistory.append(contentsOf: registered.keys)
        registered.removeAll()
    }

    func isShortcutRegistered(_ shortcut: KeyboardShortcut) -> Bool {
        registered[shortcut] != nil
    }
}

final class ShortcutBinderTests: XCTestCase {
    private func makeDefaults() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "HardRectangleShortcutsTests.\(UUID().uuidString)"
        return (suiteName, UserDefaults(suiteName: suiteName)!)
    }

    private func shortcut(_ keyCode: Int) -> KeyboardShortcut {
        KeyboardShortcut(keyCode: keyCode, modifierFlags: [.control, .option])
    }

    func testRegisteredDefaultIsBoundWhenPreferenceIsAbsent() {
        let (suiteName, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let monitor = FakeHotKeyMonitor()
        let notificationCenter = NotificationCenter()
        let binder = ShortcutBinder(
            userDefaults: defaults,
            shortcutMonitor: monitor,
            notificationCenter: notificationCenter
        )
        let defaultShortcut = shortcut(kVK_ANSI_R)

        binder.registerDefaultShortcuts(["testShortcut": defaultShortcut])
        binder.bindShortcut(withDefaultsKey: "testShortcut", toAction: {})

        XCTAssertTrue(monitor.isShortcutRegistered(defaultShortcut))
        XCTAssertEqual(monitor.registrationHistory, [defaultShortcut])
        XCTAssertTrue(binder.isRegisteredAction("testShortcut"))
    }

    func testExplicitEmptyDictionarySuppressesRegisteredDefault() {
        let (suiteName, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set([String: Any](), forKey: "testShortcut")
        let monitor = FakeHotKeyMonitor()
        let binder = ShortcutBinder(
            userDefaults: defaults,
            shortcutMonitor: monitor,
            notificationCenter: NotificationCenter()
        )

        binder.registerDefaultShortcuts(["testShortcut": shortcut(kVK_ANSI_R)])
        binder.bindShortcut(withDefaultsKey: "testShortcut", toAction: {})

        XCTAssertTrue(monitor.registrationHistory.isEmpty)
        XCTAssertTrue(monitor.registered.isEmpty)
        XCTAssertNil(defaults.object(forKey: ShortcutBinder.unsupportedPreferencesBackupKey))
    }

    func testArchivedPreferenceIsQuarantinedWithoutDecodingAndDefaultIsRegistered() throws {
        let (suiteName, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "MASShortcut-v0_40",
                withExtension: "archive.base64"
            )
        )
        let fixture = try XCTUnwrap(
            Data(
                base64Encoded: String(contentsOf: fixtureURL),
                options: .ignoreUnknownCharacters
            )
        )
        defaults.set(fixture, forKey: "testShortcut")
        let monitor = FakeHotKeyMonitor()
        let binder = ShortcutBinder(
            userDefaults: defaults,
            shortcutMonitor: monitor,
            notificationCenter: NotificationCenter()
        )
        let defaultShortcut = shortcut(kVK_ANSI_R)

        binder.registerDefaultShortcuts(["testShortcut": defaultShortcut])
        binder.bindShortcut(withDefaultsKey: "testShortcut", toAction: {})

        XCTAssertTrue(monitor.isShortcutRegistered(defaultShortcut))
        XCTAssertNil(
            defaults.persistentDomain(forName: suiteName)?["testShortcut"]
        )
        XCTAssertEqual(
            KeyboardShortcut(
                dictionaryRepresentation: defaults.dictionary(forKey: "testShortcut") ?? [:]
            ),
            defaultShortcut
        )
        let backup = try XCTUnwrap(
            defaults.dictionary(forKey: ShortcutBinder.unsupportedPreferencesBackupKey)
        )
        XCTAssertEqual(backup["testShortcut"] as? Data, fixture)

        defaults.set(Data([0x01, 0x02, 0x03]), forKey: "testShortcut")
        binder.registerDefaultShortcuts(["testShortcut": defaultShortcut])

        let unchangedBackup = try XCTUnwrap(
            defaults.dictionary(forKey: ShortcutBinder.unsupportedPreferencesBackupKey)
        )
        XCTAssertEqual(unchangedBackup["testShortcut"] as? Data, fixture)
    }

    func testCurrentDictionaryPreferenceIsNotQuarantined() {
        let (suiteName, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let currentShortcut = shortcut(kVK_ANSI_T)
        defaults.set(currentShortcut.dictionaryRepresentation, forKey: "testShortcut")
        let monitor = FakeHotKeyMonitor()
        let binder = ShortcutBinder(
            userDefaults: defaults,
            shortcutMonitor: monitor,
            notificationCenter: NotificationCenter()
        )

        binder.registerDefaultShortcuts(["testShortcut": shortcut(kVK_ANSI_R)])
        binder.bindShortcut(withDefaultsKey: "testShortcut", toAction: {})

        XCTAssertTrue(monitor.isShortcutRegistered(currentShortcut))
        XCTAssertNil(defaults.object(forKey: ShortcutBinder.unsupportedPreferencesBackupKey))
    }

    func testDefaultsChangeAutomaticallyRebindsShortcut() {
        let (suiteName, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let monitor = FakeHotKeyMonitor()
        let notificationCenter = NotificationCenter()
        let binder = ShortcutBinder(
            userDefaults: defaults,
            shortcutMonitor: monitor,
            notificationCenter: notificationCenter
        )
        let first = shortcut(kVK_ANSI_R)
        let second = shortcut(kVK_ANSI_T)
        defaults.set(first.dictionaryRepresentation, forKey: "testShortcut")
        binder.bindShortcut(withDefaultsKey: "testShortcut", toAction: {})

        defaults.set(second.dictionaryRepresentation, forKey: "testShortcut")
        notificationCenter.post(
            name: UserDefaults.didChangeNotification,
            object: defaults
        )

        XCTAssertEqual(monitor.unregistrationHistory, [first])
        XCTAssertEqual(monitor.registrationHistory, [first, second])
        XCTAssertFalse(monitor.isShortcutRegistered(first))
        XCTAssertTrue(monitor.isShortcutRegistered(second))
    }

    func testBreakBindingUnregistersShortcutAndAction() {
        let (suiteName, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let monitor = FakeHotKeyMonitor()
        let binder = ShortcutBinder(
            userDefaults: defaults,
            shortcutMonitor: monitor,
            notificationCenter: NotificationCenter()
        )
        let existing = shortcut(kVK_ANSI_R)
        defaults.set(existing.dictionaryRepresentation, forKey: "testShortcut")
        binder.bindShortcut(withDefaultsKey: "testShortcut", toAction: {})

        binder.breakBinding(withDefaultsKey: "testShortcut")

        XCTAssertEqual(monitor.unregistrationHistory, [existing])
        XCTAssertFalse(monitor.isShortcutRegistered(existing))
        XCTAssertFalse(binder.isRegisteredAction("testShortcut"))
    }

    func testBinderDeinitUnregistersEveryBoundShortcut() {
        let (suiteName, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let monitor = FakeHotKeyMonitor()
        let first = shortcut(kVK_ANSI_R)
        let second = shortcut(kVK_ANSI_T)
        defaults.set(first.dictionaryRepresentation, forKey: "first")
        defaults.set(second.dictionaryRepresentation, forKey: "second")
        var binder: ShortcutBinder? = ShortcutBinder(
            userDefaults: defaults,
            shortcutMonitor: monitor,
            notificationCenter: NotificationCenter()
        )
        binder?.bindShortcut(withDefaultsKey: "first", toAction: {})
        binder?.bindShortcut(withDefaultsKey: "second", toAction: {})

        binder = nil

        XCTAssertEqual(Set(monitor.unregistrationHistory), Set([first, second]))
        XCTAssertTrue(monitor.registered.isEmpty)
    }
}
