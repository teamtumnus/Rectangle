import AppKit
import Carbon.HIToolbox
import XCTest
@testable import RectangleShortcuts

final class KeyboardShortcutTests: XCTestCase {
    func testDictionaryRepresentationUsesExistingRectangleFormat() throws {
        let shortcut = KeyboardShortcut(
            keyCode: kVK_ANSI_R,
            modifierFlags: [.control, .option, .command]
        )

        let dictionary = shortcut.dictionaryRepresentation

        XCTAssertEqual((dictionary["keyCode"] as? NSNumber)?.intValue, kVK_ANSI_R)
        XCTAssertEqual(
            (dictionary["modifierFlags"] as? NSNumber)?.uintValue,
            NSEvent.ModifierFlags([.control, .option, .command]).rawValue
        )
        XCTAssertEqual(KeyboardShortcut(dictionaryRepresentation: dictionary), shortcut)
    }

    func testDictionaryRepresentationAcceptsNumericStringsForCompatibility() {
        let dictionary: [String: Any] = [
            "keyCode": NSString(string: "15"),
            "modifierFlags": NSString(string: "\(NSEvent.ModifierFlags.command.rawValue)")
        ]

        let shortcut = KeyboardShortcut(dictionaryRepresentation: dictionary)

        XCTAssertEqual(shortcut?.keyCode, 15)
        XCTAssertEqual(shortcut?.modifierFlags, .command)
    }

    func testMalformedDictionaryValuesAreRejected() {
        XCTAssertNil(KeyboardShortcut(dictionaryRepresentation: [:]))
        XCTAssertNil(KeyboardShortcut(dictionaryRepresentation: ["keyCode": 1]))
        XCTAssertNil(KeyboardShortcut(dictionaryRepresentation: ["modifierFlags": 1]))
        XCTAssertNil(KeyboardShortcut(dictionaryRepresentation: [
            "keyCode": -1,
            "modifierFlags": NSEvent.ModifierFlags.command.rawValue
        ]))
        XCTAssertNil(KeyboardShortcut(dictionaryRepresentation: [
            "keyCode": Int(UInt16.max) + 1,
            "modifierFlags": NSEvent.ModifierFlags.command.rawValue
        ]))
        XCTAssertNil(KeyboardShortcut(dictionaryRepresentation: [
            "keyCode": NSObject(),
            "modifierFlags": NSEvent.ModifierFlags.command.rawValue
        ]))
    }

    func testUnsupportedModifierBitsAreRemoved() {
        let shortcut = KeyboardShortcut(
            keyCode: kVK_ANSI_R,
            modifierFlags: [.capsLock, .function, .command]
        )

        XCTAssertEqual(shortcut.modifierFlags, .command)
    }

    func testCarbonModifierConversionRoundTripsSupportedModifiers() {
        let cocoaFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

        let carbonFlags = KeyboardShortcut.carbonModifierFlags(from: cocoaFlags)

        XCTAssertEqual(carbonFlags, UInt32(cmdKey | optionKey | controlKey | shiftKey))
        XCTAssertEqual(KeyboardShortcut.cocoaModifierFlags(fromCarbon: carbonFlags), cocoaFlags)
    }

    func testDescriptionUsesMenuOrderAndStableSpecialKeyNames() {
        let shortcut = KeyboardShortcut(
            keyCode: kVK_LeftArrow,
            modifierFlags: [.command, .option, .control, .shift]
        )

        XCTAssertEqual(shortcut.modifierFlagsString, "⌃⌥⇧⌘")
        XCTAssertEqual(shortcut.keyCodeString, "←")
        XCTAssertEqual(shortcut.description, "⌃⌥⇧⌘←")
    }

    func testFunctionAndKeypadDisplayStringsAreStable() {
        XCTAssertEqual(KeyboardShortcut(keyCode: kVK_F14, modifierFlags: []).keyCodeString, "F14")
        XCTAssertEqual(KeyboardShortcut(keyCode: kVK_ANSI_KeypadEnter, modifierFlags: []).keyCodeString, "⌅")
        XCTAssertEqual(KeyboardShortcut(keyCode: kVK_Space, modifierFlags: []).keyCodeStringForKeyEquivalent, " ")
    }

    func testHashingUsesKeyCodeAndNormalizedModifiers() {
        let first = KeyboardShortcut(keyCode: kVK_ANSI_R, modifierFlags: [.command, .capsLock])
        let second = KeyboardShortcut(keyCode: kVK_ANSI_R, modifierFlags: .command)
        let different = KeyboardShortcut(keyCode: kVK_ANSI_T, modifierFlags: .command)

        XCTAssertEqual(first, second)
        XCTAssertEqual(Set([first, second, different]).count, 2)
    }
}
