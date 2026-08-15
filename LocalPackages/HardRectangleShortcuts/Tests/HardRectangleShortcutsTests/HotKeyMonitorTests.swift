import AppKit
import Carbon.HIToolbox
import XCTest
@testable import HardRectangleShortcuts

private final class FakeRegistrationToken: NSObject {
    let identifier: UInt32

    init(identifier: UInt32) {
        self.identifier = identifier
    }
}

private final class FakeRegistrationBackend: HotKeyRegistrationBackend {
    struct Registration: Equatable {
        let keyCode: UInt32
        let modifiers: UInt32
        let identifier: UInt32
    }

    var startResult = true
    var registerResult = true
    var registrations = [Registration]()
    var unregisteredIdentifiers = [UInt32]()
    var stopCallCount = 0
    private var handler: ((UInt32) -> Void)?

    func start(handler: @escaping (UInt32) -> Void) -> Bool {
        self.handler = handler
        return startResult
    }

    func register(keyCode: UInt32, modifiers: UInt32, identifier: UInt32) -> AnyObject? {
        registrations.append(Registration(
            keyCode: keyCode,
            modifiers: modifiers,
            identifier: identifier
        ))
        return registerResult ? FakeRegistrationToken(identifier: identifier) : nil
    }

    func unregister(_ token: AnyObject) {
        guard let token = token as? FakeRegistrationToken else {
            XCTFail("Unexpected registration token")
            return
        }
        unregisteredIdentifiers.append(token.identifier)
    }

    func stop() {
        stopCallCount += 1
        handler = nil
    }

    func send(identifier: UInt32) {
        handler?(identifier)
    }
}

final class HotKeyMonitorTests: XCTestCase {
    private func shortcut(_ keyCode: Int = kVK_ANSI_R) -> KeyboardShortcut {
        KeyboardShortcut(keyCode: keyCode, modifierFlags: [.control, .option])
    }

    func testRegistrationUsesCarbonValuesAndDispatchesAction() {
        let backend = FakeRegistrationBackend()
        let monitor = HotKeyMonitor(backend: backend)
        let shortcut = shortcut()
        let actionExpectation = expectation(description: "registered action")

        XCTAssertTrue(monitor.registerShortcut(shortcut) {
            actionExpectation.fulfill()
        })
        XCTAssertEqual(backend.registrations, [
            FakeRegistrationBackend.Registration(
                keyCode: shortcut.carbonKeyCode,
                modifiers: shortcut.carbonModifierFlags,
                identifier: 1
            )
        ])
        XCTAssertTrue(monitor.isShortcutRegistered(shortcut))

        backend.send(identifier: 1)

        wait(for: [actionExpectation], timeout: 1)
    }

    func testReplacingSameShortcutUnregistersPreviousToken() {
        let backend = FakeRegistrationBackend()
        let monitor = HotKeyMonitor(backend: backend)
        let shortcut = shortcut()

        XCTAssertTrue(monitor.registerShortcut(shortcut, action: {}))
        XCTAssertTrue(monitor.registerShortcut(shortcut, action: {}))

        XCTAssertEqual(backend.registrations.map(\.identifier), [1, 2])
        XCTAssertEqual(backend.unregisteredIdentifiers, [1])
        XCTAssertTrue(monitor.isShortcutRegistered(shortcut))
    }

    func testFailedRegistrationIsNotTracked() {
        let backend = FakeRegistrationBackend()
        backend.registerResult = false
        let monitor = HotKeyMonitor(backend: backend)
        let shortcut = shortcut()

        XCTAssertFalse(monitor.registerShortcut(shortcut, action: {}))
        XCTAssertFalse(monitor.isShortcutRegistered(shortcut))
        XCTAssertTrue(backend.unregisteredIdentifiers.isEmpty)
    }

    func testFailedBackendStartPreventsRegistration() {
        let backend = FakeRegistrationBackend()
        backend.startResult = false
        let monitor = HotKeyMonitor(backend: backend)

        XCTAssertFalse(monitor.registerShortcut(shortcut(), action: {}))
        XCTAssertTrue(backend.registrations.isEmpty)
    }

    func testUnregisterAllAndDeinitCleanUpRegistrationsAndBackend() {
        let backend = FakeRegistrationBackend()
        var monitor: HotKeyMonitor? = HotKeyMonitor(backend: backend)
        let first = shortcut(kVK_ANSI_R)
        let second = shortcut(kVK_ANSI_T)
        XCTAssertTrue(monitor?.registerShortcut(first, action: {}) == true)
        XCTAssertTrue(monitor?.registerShortcut(second, action: {}) == true)

        monitor?.unregisterAllShortcuts()

        XCTAssertEqual(Set(backend.unregisteredIdentifiers), Set([1, 2]))
        XCTAssertFalse(monitor?.isShortcutRegistered(first) == true)
        XCTAssertFalse(monitor?.isShortcutRegistered(second) == true)

        monitor = nil

        XCTAssertEqual(backend.stopCallCount, 1)
    }
}
