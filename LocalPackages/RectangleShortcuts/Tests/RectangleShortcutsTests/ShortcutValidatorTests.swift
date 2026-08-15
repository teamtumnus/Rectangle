import AppKit
import Carbon.HIToolbox
import XCTest
@testable import RectangleShortcuts

private final class FakeConflictBackend: ShortcutConflictBackend {
    var hasSystemConflict = false
    var menuConflictExplanation: String?
    var serviceOverrideValues = [Bool]()

    func systemConflict(for shortcut: KeyboardShortcut) -> Bool {
        hasSystemConflict
    }

    func menuConflict(
        for shortcut: KeyboardShortcut,
        allowOverridingServicesShortcut: Bool
    ) -> String? {
        serviceOverrideValues.append(allowOverridingServicesShortcut)
        return menuConflictExplanation
    }
}

final class ShortcutValidatorTests: XCTestCase {
    private func shortcut(
        _ keyCode: Int = kVK_ANSI_R,
        _ modifiers: NSEvent.ModifierFlags
    ) -> KeyboardShortcut {
        KeyboardShortcut(keyCode: keyCode, modifierFlags: modifiers)
    }

    func testModifierRulesMatchRecorderBehavior() {
        let validator = ShortcutValidator(conflictBackend: FakeConflictBackend())

        XCTAssertFalse(validator.isShortcutValid(shortcut(kVK_ANSI_R, [])))
        XCTAssertFalse(validator.isShortcutValid(shortcut(kVK_ANSI_R, .shift)))
        XCTAssertFalse(validator.isShortcutValid(shortcut(kVK_ANSI_R, .option)))
        XCTAssertTrue(validator.isShortcutValid(shortcut(kVK_ANSI_R, .command)))
        XCTAssertTrue(validator.isShortcutValid(shortcut(kVK_ANSI_R, .control)))
        XCTAssertTrue(validator.isShortcutValid(shortcut(kVK_Space, .option)))
        XCTAssertTrue(validator.isShortcutValid(shortcut(kVK_Escape, .option)))
        XCTAssertTrue(validator.isShortcutValid(shortcut(kVK_F12, [])))
    }

    func testOptionOnlyCanBeEnabledForAnyKey() {
        let validator = ShortcutValidator(conflictBackend: FakeConflictBackend())
        validator.allowAnyShortcutWithOptionModifier = true

        XCTAssertTrue(validator.isShortcutValid(shortcut(kVK_ANSI_R, .option)))
    }

    func testSystemConflictReturnsExplanationBeforeMenuConflict() {
        let backend = FakeConflictBackend()
        backend.hasSystemConflict = true
        backend.menuConflictExplanation = "menu conflict"
        let validator = ShortcutValidator(conflictBackend: backend)

        let conflict = validator.conflict(for: shortcut(kVK_ANSI_R, .command))

        XCTAssertNotNil(conflict)
        XCTAssertTrue(conflict?.contains("system-wide keyboard shortcut") == true)
        XCTAssertTrue(backend.serviceOverrideValues.isEmpty)
    }

    func testMenuConflictExplanationIsReturned() {
        let backend = FakeConflictBackend()
        backend.menuConflictExplanation = "menu conflict"
        let validator = ShortcutValidator(conflictBackend: backend)

        XCTAssertEqual(
            validator.conflict(for: shortcut(kVK_ANSI_R, .command)),
            "menu conflict"
        )
        XCTAssertEqual(backend.serviceOverrideValues, [false])
    }

    func testServicesOverrideSettingIsPassedToConflictBackend() {
        let backend = FakeConflictBackend()
        let validator = ShortcutValidator(conflictBackend: backend)
        validator.allowOverridingServicesShortcut = true

        XCTAssertNil(validator.conflict(for: shortcut(kVK_ANSI_R, .command)))
        XCTAssertEqual(backend.serviceOverrideValues, [true])
    }

    func testCompatibilityConflictMethodSetsAndClearsExplanation() {
        let backend = FakeConflictBackend()
        backend.menuConflictExplanation = "menu conflict"
        let validator = ShortcutValidator(conflictBackend: backend)
        var explanation: NSString?

        XCTAssertTrue(validator.isShortcutAlreadyTaken(
            bySystem: shortcut(kVK_ANSI_R, .command),
            explanation: &explanation
        ))
        XCTAssertEqual(explanation, "menu conflict")

        backend.menuConflictExplanation = nil
        XCTAssertFalse(validator.isShortcutAlreadyTaken(
            bySystem: shortcut(kVK_ANSI_R, .command),
            explanation: &explanation
        ))
        XCTAssertNil(explanation)
    }
}
