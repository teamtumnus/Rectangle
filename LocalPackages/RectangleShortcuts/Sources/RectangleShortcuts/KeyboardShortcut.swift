import AppKit
import Carbon.HIToolbox
import Foundation

public struct KeyboardShortcut: Hashable, CustomStringConvertible {
    public static let keyCodeKey = "keyCode"
    public static let modifierFlagsKey = "modifierFlags"

    public let keyCode: Int
    public let modifierFlags: NSEvent.ModifierFlags

    public init(keyCode: Int, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags.intersection(Self.supportedModifiers)
    }

    public init?(event: NSEvent) {
        self.init(keyCode: Int(event.keyCode), modifierFlags: event.modifierFlags)
    }

    public init?(dictionaryRepresentation dictionary: [String: Any]) {
        guard !dictionary.isEmpty,
              let keyCode = Self.integerValue(dictionary[Self.keyCodeKey]),
              let modifierFlags = Self.unsignedIntegerValue(dictionary[Self.modifierFlagsKey]),
              keyCode >= 0,
              keyCode <= Int(UInt16.max)
        else { return nil }

        self.init(
            keyCode: keyCode,
            modifierFlags: NSEvent.ModifierFlags(rawValue: modifierFlags)
        )
    }

    public var dictionaryRepresentation: [String: Any] {
        [
            Self.keyCodeKey: NSNumber(value: keyCode),
            Self.modifierFlagsKey: NSNumber(value: modifierFlags.rawValue)
        ]
    }

    public var carbonKeyCode: UInt32 {
        UInt32(keyCode)
    }

    public var carbonModifierFlags: UInt32 {
        Self.carbonModifierFlags(from: modifierFlags)
    }

    public static func carbonModifierFlags(from modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    public static func cocoaModifierFlags(fromCarbon modifiers: UInt32) -> NSEvent.ModifierFlags {
        var result: NSEvent.ModifierFlags = []
        if modifiers & UInt32(cmdKey) != 0 { result.insert(.command) }
        if modifiers & UInt32(optionKey) != 0 { result.insert(.option) }
        if modifiers & UInt32(controlKey) != 0 { result.insert(.control) }
        if modifiers & UInt32(shiftKey) != 0 { result.insert(.shift) }
        return result
    }

    public var modifierFlagsString: String {
        var result = ""
        if modifierFlags.contains(.control) { result.append("⌃") }
        if modifierFlags.contains(.option) { result.append("⌥") }
        if modifierFlags.contains(.shift) { result.append("⇧") }
        if modifierFlags.contains(.command) { result.append("⌘") }
        return result
    }

    public var keyCodeString: String? {
        switch keyCode {
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        case kVK_Space: return localizedShortcutString("Space")
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Help: return "?"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_Tab: return "⇥"
        case kVK_Return: return "↩"
        case kVK_ANSI_Keypad0: return "0"
        case kVK_ANSI_Keypad1: return "1"
        case kVK_ANSI_Keypad2: return "2"
        case kVK_ANSI_Keypad3: return "3"
        case kVK_ANSI_Keypad4: return "4"
        case kVK_ANSI_Keypad5: return "5"
        case kVK_ANSI_Keypad6: return "6"
        case kVK_ANSI_Keypad7: return "7"
        case kVK_ANSI_Keypad8: return "8"
        case kVK_ANSI_Keypad9: return "9"
        case kVK_ANSI_KeypadDecimal: return "."
        case kVK_ANSI_KeypadMultiply: return "*"
        case kVK_ANSI_KeypadPlus: return "+"
        case kVK_ANSI_KeypadClear: return "⌧"
        case kVK_ANSI_KeypadDivide: return "/"
        case kVK_ANSI_KeypadEnter: return "⌅"
        case kVK_ANSI_KeypadMinus: return "-"
        case kVK_ANSI_KeypadEquals: return "="
        default:
            return Self.currentKeyboardLayoutString(for: keyCode)
        }
    }

    public var keyCodeStringForKeyEquivalent: String? {
        switch keyCode {
        case kVK_F1: return Self.string(from: NSF1FunctionKey)
        case kVK_F2: return Self.string(from: NSF2FunctionKey)
        case kVK_F3: return Self.string(from: NSF3FunctionKey)
        case kVK_F4: return Self.string(from: NSF4FunctionKey)
        case kVK_F5: return Self.string(from: NSF5FunctionKey)
        case kVK_F6: return Self.string(from: NSF6FunctionKey)
        case kVK_F7: return Self.string(from: NSF7FunctionKey)
        case kVK_F8: return Self.string(from: NSF8FunctionKey)
        case kVK_F9: return Self.string(from: NSF9FunctionKey)
        case kVK_F10: return Self.string(from: NSF10FunctionKey)
        case kVK_F11: return Self.string(from: NSF11FunctionKey)
        case kVK_F12: return Self.string(from: NSF12FunctionKey)
        case kVK_F13: return Self.string(from: NSF13FunctionKey)
        case kVK_F14: return Self.string(from: NSF14FunctionKey)
        case kVK_F15: return Self.string(from: NSF15FunctionKey)
        case kVK_F16: return Self.string(from: NSF16FunctionKey)
        case kVK_F17: return Self.string(from: NSF17FunctionKey)
        case kVK_F18: return Self.string(from: NSF18FunctionKey)
        case kVK_F19: return Self.string(from: NSF19FunctionKey)
        case kVK_F20: return Self.string(from: NSF20FunctionKey)
        case kVK_Space: return " "
        case kVK_Escape: return "\u{1b}"
        case kVK_Delete: return Self.string(from: NSBackspaceCharacter)
        case kVK_ForwardDelete: return Self.string(from: NSDeleteFunctionKey)
        case kVK_LeftArrow: return Self.string(from: NSLeftArrowFunctionKey)
        case kVK_RightArrow: return Self.string(from: NSRightArrowFunctionKey)
        case kVK_UpArrow: return Self.string(from: NSUpArrowFunctionKey)
        case kVK_DownArrow: return Self.string(from: NSDownArrowFunctionKey)
        case kVK_Help: return Self.string(from: NSHelpFunctionKey)
        case kVK_Home: return Self.string(from: NSHomeFunctionKey)
        case kVK_End: return Self.string(from: NSEndFunctionKey)
        case kVK_PageUp: return Self.string(from: NSPageUpFunctionKey)
        case kVK_PageDown: return Self.string(from: NSPageDownFunctionKey)
        case kVK_Tab: return "\t"
        case kVK_Return: return "\r"
        default: return keyCodeString?.lowercased()
        }
    }

    public var description: String {
        modifierFlagsString + (keyCodeString ?? "")
    }

    public static func == (lhs: KeyboardShortcut, rhs: KeyboardShortcut) -> Bool {
        lhs.keyCode == rhs.keyCode
            && lhs.modifierFlags.rawValue == rhs.modifierFlags.rawValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifierFlags.rawValue)
    }

    private static let supportedModifiers: NSEvent.ModifierFlags = [
        .command, .option, .control, .shift
    ]

    private static func integerValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? NSString { return string.integerValue }
        return nil
    }

    private static func unsignedIntegerValue(_ value: Any?) -> UInt? {
        if let number = value as? NSNumber { return number.uintValue }
        if let string = value as? NSString { return UInt(string as String) }
        return nil
    }

    private static func string(from character: Int) -> String {
        String(UnicodeScalar(character)!)
    }

    private static func currentKeyboardLayoutString(for keyCode: Int) -> String? {
        guard keyCode >= 0, keyCode <= Int(UInt16.max),
              let unmanagedInputSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()
        else { return nil }

        let inputSource = unmanagedInputSource.takeRetainedValue()
        guard let rawLayoutData = TISGetInputSourceProperty(
            inputSource,
            kTISPropertyUnicodeKeyLayoutData
        ) else { return nil }

        let layoutData = unsafeBitCast(rawLayoutData, to: CFData.self) as Data
        let translated: String? = layoutData.withUnsafeBytes { bytes in
            guard let keyboardLayout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self)
            else { return nil }

            var deadKeyState: UInt32 = 0
            var characters = [UniChar](repeating: 0, count: 16)
            var actualLength = 0
            let status = UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysMask),
                &deadKeyState,
                characters.count,
                &actualLength,
                &characters
            )

            guard status == noErr, actualLength > 0 else { return nil }
            return String(utf16CodeUnits: characters, count: Int(actualLength))
        }

        guard let translated, !translated.isEmpty else { return nil }
        let allowed = CharacterSet.alphanumerics
            .union(.punctuationCharacters)
            .union(.symbols)
        guard translated.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return translated.uppercased()
    }
}

func localizedShortcutString(_ key: String) -> String {
    Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
}
