import Carbon.HIToolbox
import Foundation

public protocol HotKeyMonitoring: AnyObject {
    @discardableResult
    func registerShortcut(_ shortcut: KeyboardShortcut, action: @escaping () -> Void) -> Bool
    func unregisterShortcut(_ shortcut: KeyboardShortcut)
    func unregisterAllShortcuts()
    func isShortcutRegistered(_ shortcut: KeyboardShortcut) -> Bool
}

protocol HotKeyRegistrationBackend: AnyObject {
    func start(handler: @escaping (UInt32) -> Void) -> Bool
    func register(keyCode: UInt32, modifiers: UInt32, identifier: UInt32) -> AnyObject?
    func unregister(_ token: AnyObject)
    func stop()
}

public final class HotKeyMonitor: HotKeyMonitoring {
    public static let shared = HotKeyMonitor()

    private struct Registration {
        let identifier: UInt32
        let token: AnyObject
        let action: () -> Void
    }

    private let backend: HotKeyRegistrationBackend
    private var registrations = [KeyboardShortcut: Registration]()
    private var shortcutsByIdentifier = [UInt32: KeyboardShortcut]()
    private var nextIdentifier: UInt32 = 1
    private var started = false

    public convenience init() {
        self.init(backend: SystemHotKeyRegistrationBackend())
    }

    init(backend: HotKeyRegistrationBackend) {
        self.backend = backend
        self.started = backend.start { [weak self] identifier in
            self?.handle(identifier: identifier)
        }
    }

    deinit {
        unregisterAllShortcuts()
        backend.stop()
    }

    @discardableResult
    public func registerShortcut(
        _ shortcut: KeyboardShortcut,
        action: @escaping () -> Void
    ) -> Bool {
        guard started else { return false }
        unregisterShortcut(shortcut)

        let identifier = nextIdentifier
        nextIdentifier &+= 1
        if nextIdentifier == 0 { nextIdentifier = 1 }

        guard let token = backend.register(
            keyCode: shortcut.carbonKeyCode,
            modifiers: shortcut.carbonModifierFlags,
            identifier: identifier
        ) else { return false }

        registrations[shortcut] = Registration(
            identifier: identifier,
            token: token,
            action: action
        )
        shortcutsByIdentifier[identifier] = shortcut
        return true
    }

    public func unregisterShortcut(_ shortcut: KeyboardShortcut) {
        guard let registration = registrations.removeValue(forKey: shortcut) else { return }
        shortcutsByIdentifier.removeValue(forKey: registration.identifier)
        backend.unregister(registration.token)
    }

    public func unregisterAllShortcuts() {
        for registration in registrations.values {
            backend.unregister(registration.token)
        }
        registrations.removeAll()
        shortcutsByIdentifier.removeAll()
    }

    public func isShortcutRegistered(_ shortcut: KeyboardShortcut) -> Bool {
        registrations[shortcut] != nil
    }

    func handle(identifier: UInt32) {
        guard let shortcut = shortcutsByIdentifier[identifier],
              let action = registrations[shortcut]?.action
        else { return }
        DispatchQueue.main.async(execute: action)
    }
}

private final class SystemHotKeyRegistrationToken: NSObject {
    let reference: EventHotKeyRef

    init(reference: EventHotKeyRef) {
        self.reference = reference
    }
}

private final class SystemHotKeyRegistrationBackend: HotKeyRegistrationBackend {
    private static let signature: OSType = 0x52656374 // 'Rect'

    private var eventHandler: EventHandlerRef?
    private var handler: ((UInt32) -> Void)?

    func start(handler: @escaping (UInt32) -> Void) -> Bool {
        guard eventHandler == nil else {
            self.handler = handler
            return true
        }

        self.handler = handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            systemHotKeyEventCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        return status == noErr
    }

    func register(keyCode: UInt32, modifiers: UInt32, identifier: UInt32) -> AnyObject? {
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else { return nil }
        return SystemHotKeyRegistrationToken(reference: reference)
    }

    func unregister(_ token: AnyObject) {
        guard let token = token as? SystemHotKeyRegistrationToken else { return }
        UnregisterEventHotKey(token.reference)
    }

    func stop() {
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        handler = nil
    }

    fileprivate func handle(event: EventRef?) {
        guard let event,
              GetEventClass(event) == OSType(kEventClassKeyboard)
        else { return }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, hotKeyID.signature == Self.signature else { return }
        handler?(hotKeyID.id)
    }
}

private func systemHotKeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let backend = Unmanaged<SystemHotKeyRegistrationBackend>
        .fromOpaque(userData)
        .takeUnretainedValue()
    backend.handle(event: event)
    return noErr
}
