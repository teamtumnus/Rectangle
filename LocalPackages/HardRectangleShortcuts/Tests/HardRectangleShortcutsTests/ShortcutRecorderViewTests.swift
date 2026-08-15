import AppKit
import Carbon.HIToolbox
import XCTest
@testable import HardRectangleShortcuts

private struct RecorderConflictBackend: ShortcutConflictBackend {
    func systemConflict(for shortcut: KeyboardShortcut) -> Bool { false }

    func menuConflict(
        for shortcut: KeyboardShortcut,
        allowOverridingServicesShortcut: Bool
    ) -> String? { nil }
}

final class ShortcutRecorderViewTests: XCTestCase {
    private func makeView() -> ShortcutRecorderView {
        let view = ShortcutRecorderView(frame: NSRect(x: 0, y: 0, width: 160, height: 19))
        view.shortcutValidator = ShortcutValidator(
            conflictBackend: RecorderConflictBackend()
        )
        return view
    }

    private func shortcut(_ keyCode: Int = kVK_ANSI_R) -> KeyboardShortcut {
        KeyboardShortcut(keyCode: keyCode, modifierFlags: [.control, .option])
    }

    func testRecordingStateCallbackReportsTransitions() {
        let view = makeView()
        defer { view.recording = false }
        var states = [Bool]()
        view.onRecordingChanged = { states.append($0) }

        view.recording = true
        view.recording = true
        view.recording = false

        XCTAssertEqual(states, [true, false])
        XCTAssertFalse(view.isRecording)
    }

    func testValidShortcutIsRecordedPersistedAndEndsRecording() {
        let suiteName = "ShortcutRecorderViewTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let view = makeView()
        defer { view.recording = false }
        view.bind(toUserDefaultsKey: "shortcut", userDefaults: defaults)
        var changedValues = [KeyboardShortcut?]()
        view.onShortcutChanged = { changedValues.append($0) }
        view.recording = true

        let disposition = view.processKeyEvent(
            keyCode: kVK_ANSI_R,
            modifierFlags: [.control, .option]
        )

        XCTAssertEqual(disposition, .consume)
        XCTAssertEqual(view.shortcutValue, shortcut())
        XCTAssertFalse(view.isRecording)
        XCTAssertEqual(changedValues, [shortcut()])
        XCTAssertEqual(
            KeyboardShortcut(
                dictionaryRepresentation: defaults.dictionary(forKey: "shortcut") ?? [:]
            ),
            shortcut()
        )
    }

    func testDeleteClearsShortcutAndEndsRecording() {
        let view = makeView()
        defer { view.recording = false }
        view.shortcutValue = shortcut()
        view.recording = true

        let disposition = view.processKeyEvent(
            keyCode: kVK_Delete,
            modifierFlags: []
        )

        XCTAssertEqual(disposition, .consume)
        XCTAssertNil(view.shortcutValue)
        XCTAssertFalse(view.isRecording)
    }

    func testEscapeCancelsWithoutChangingShortcut() {
        let view = makeView()
        defer { view.recording = false }
        let existing = shortcut()
        view.shortcutValue = existing
        view.recording = true

        let disposition = view.processKeyEvent(
            keyCode: kVK_Escape,
            modifierFlags: []
        )

        XCTAssertEqual(disposition, .consume)
        XCTAssertEqual(view.shortcutValue, existing)
        XCTAssertFalse(view.isRecording)
    }

    func testCommandWPassesThroughAndCancelsRecording() {
        let view = makeView()
        defer { view.recording = false }
        let existing = shortcut()
        view.shortcutValue = existing
        view.recording = true

        let disposition = view.processKeyEvent(
            keyCode: kVK_ANSI_W,
            modifierFlags: .command
        )

        XCTAssertEqual(disposition, .passThrough)
        XCTAssertEqual(view.shortcutValue, existing)
        XCTAssertFalse(view.isRecording)
    }

    func testTabPassesThroughWithoutEndingRecording() {
        let view = makeView()
        defer { view.recording = false }
        view.recording = true

        let disposition = view.processKeyEvent(
            keyCode: kVK_Tab,
            modifierFlags: []
        )

        XCTAssertEqual(disposition, .passThrough)
        XCTAssertTrue(view.isRecording)
    }

    func testStartingSecondRecorderStopsFirstRecorder() {
        let first = makeView()
        let second = makeView()
        defer {
            first.recording = false
            second.recording = false
        }

        first.recording = true
        second.recording = true

        XCTAssertFalse(first.isRecording)
        XCTAssertTrue(second.isRecording)
    }

    func testDisabledRecorderCannotEnterRecordingState() {
        let view = makeView()
        view.isEnabled = false

        view.recording = true

        XCTAssertFalse(view.isRecording)
    }

    func testDefaultsNotificationReloadsPersistedShortcut() {
        let suiteName = "ShortcutRecorderViewTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let view = makeView()
        let first = shortcut(kVK_ANSI_R)
        let second = shortcut(kVK_ANSI_T)
        defaults.set(first.dictionaryRepresentation, forKey: "shortcut")
        view.bind(toUserDefaultsKey: "shortcut", userDefaults: defaults)

        defaults.set(second.dictionaryRepresentation, forKey: "shortcut")
        NotificationCenter.default.post(
            name: UserDefaults.didChangeNotification,
            object: defaults
        )

        XCTAssertEqual(view.shortcutValue, second)
    }

    func testAccessibilityExposesButtonStateAndPressStartsRecording() {
        let view = makeView()
        defer { view.recording = false }

        XCTAssertTrue(view.isAccessibilityElement())
        XCTAssertEqual(view.accessibilityRole(), .button)
        XCTAssertEqual(view.accessibilityLabel(), "Empty keyboard shortcut")
        XCTAssertFalse(view.accessibilityHelp()?.isEmpty == true)
        XCTAssertTrue(view.accessibilityPerformPress())
        XCTAssertTrue(view.isRecording)
        XCTAssertFalse(view.accessibilityPerformPress())
    }
}
