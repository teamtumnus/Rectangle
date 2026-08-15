// Modified Swift adaptation of MASShortcut. See MASShortcut-LICENSE.txt.

import AppKit
import Carbon.HIToolbox
import Foundation

protocol ShortcutConflictBackend {
    func systemConflict(for shortcut: KeyboardShortcut) -> Bool
    func menuConflict(
        for shortcut: KeyboardShortcut,
        allowOverridingServicesShortcut: Bool
    ) -> String?
}

open class ShortcutValidator {
    public static let shared = ShortcutValidator()

    public var allowAnyShortcutWithOptionModifier = false
    public var allowOverridingServicesShortcut = false

    private let conflictBackend: ShortcutConflictBackend

    public init() {
        self.conflictBackend = SystemShortcutConflictBackend()
    }

    init(conflictBackend: ShortcutConflictBackend) {
        self.conflictBackend = conflictBackend
    }

    open func isShortcutValid(_ shortcut: KeyboardShortcut) -> Bool {
        if Self.functionKeyCodes.contains(shortcut.keyCode) {
            return true
        }

        let modifiers = shortcut.modifierFlags
        guard !modifiers.isEmpty else { return false }
        if modifiers.contains(.command) || modifiers.contains(.control) {
            return true
        }
        if modifiers.contains(.option) {
            if shortcut.keyCode == kVK_Space || shortcut.keyCode == kVK_Escape {
                return true
            }
            return allowAnyShortcutWithOptionModifier
        }
        return false
    }

    open func conflict(for shortcut: KeyboardShortcut) -> String? {
        if conflictBackend.systemConflict(for: shortcut) {
            return localizedShortcutString(
                "This combination cannot be used because it is already used by a system-wide keyboard shortcut.\nIf you really want to use this key combination, most shortcuts can be changed in the Keyboard & Mouse panel in System Preferences."
            )
        }
        return conflictBackend.menuConflict(
            for: shortcut,
            allowOverridingServicesShortcut: allowOverridingServicesShortcut
        )
    }

    open func isShortcutAlreadyTaken(
        bySystem shortcut: KeyboardShortcut,
        explanation: UnsafeMutablePointer<NSString?>?
    ) -> Bool {
        guard let conflict = conflict(for: shortcut) else {
            explanation?.pointee = nil
            return false
        }
        explanation?.pointee = conflict as NSString
        return true
    }

    private static let functionKeyCodes: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5,
        kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15,
        kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20
    ]
}

private struct SystemShortcutConflictBackend: ShortcutConflictBackend {
    func systemConflict(for shortcut: KeyboardShortcut) -> Bool {
        var unmanagedHotKeys: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanagedHotKeys) == noErr,
              let hotKeys = unmanagedHotKeys?.takeRetainedValue() as? [[String: Any]]
        else { return false }

        for hotKey in hotKeys {
            guard let keyCode = (hotKey[kHISymbolicHotKeyCode as String] as? NSNumber)?.intValue,
                  let modifiers = (hotKey[kHISymbolicHotKeyModifiers as String] as? NSNumber)?.uint32Value,
                  let enabled = (hotKey[kHISymbolicHotKeyEnabled as String] as? NSNumber)?.boolValue
            else { continue }

            if enabled,
               keyCode == shortcut.keyCode,
               modifiers == shortcut.carbonModifierFlags {
                return true
            }
        }
        return false
    }

    func menuConflict(
        for shortcut: KeyboardShortcut,
        allowOverridingServicesShortcut: Bool
    ) -> String? {
        guard let menu = NSApp.mainMenu else { return nil }
        return menuConflict(
            for: shortcut,
            in: menu,
            allowOverridingServicesShortcut: allowOverridingServicesShortcut
        )
    }

    private func menuConflict(
        for shortcut: KeyboardShortcut,
        in menu: NSMenu,
        allowOverridingServicesShortcut: Bool
    ) -> String? {
        if allowOverridingServicesShortcut, menu === NSApp.servicesMenu {
            return nil
        }
        guard let keyEquivalent = shortcut.keyCodeStringForKeyEquivalent else { return nil }
        for item in menu.items {
            if let submenu = item.submenu,
               let conflict = menuConflict(
                   for: shortcut,
                   in: submenu,
                   allowOverridingServicesShortcut: allowOverridingServicesShortcut
               ) {
                return conflict
            }

            var menuModifiers = item.keyEquivalentModifierMask.intersection([
                .command, .option, .control, .shift, .function
            ])
            let itemKey = item.keyEquivalent.lowercased()
            if itemKey == keyEquivalent,
               item.keyEquivalent != keyEquivalent {
                menuModifiers.insert(.shift)
            }

            if menuModifiers == shortcut.modifierFlags,
               itemKey == keyEquivalent {
                let format = localizedShortcutString(
                    "This shortcut cannot be used because it is already used by the menu item ‘%@’."
                )
                return String(format: format, item.title)
            }
        }
        return nil
    }
}
