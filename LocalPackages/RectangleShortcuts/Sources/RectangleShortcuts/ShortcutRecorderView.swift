import AppKit
import Carbon.HIToolbox
import Foundation

enum RecorderEventDisposition: Equatable {
    case consume
    case passThrough
}

@IBDesignable
public final class ShortcutRecorderView: NSView {
    private static weak var activeRecorder: ShortcutRecorderView?

    public var shortcutValidator: ShortcutValidator = .shared
    public var onRecordingChanged: ((Bool) -> Void)?
    public var onShortcutChanged: ((KeyboardShortcut?) -> Void)?

    public var shortcutValue: KeyboardShortcut? {
        didSet {
            guard shortcutValue != oldValue else { return }
            persistShortcutValue()
            onShortcutChanged?(shortcutValue)
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    @IBInspectable public var isEnabled = true {
        didSet {
            if !isEnabled { recording = false }
            needsDisplay = true
        }
    }

    @objc dynamic public var recording: Bool {
        get { recordingStorage }
        set { setRecording(newValue) }
    }

    public var isRecording: Bool { recordingStorage }
    public private(set) var associatedUserDefaultsKey: String?

    private var recordingStorage = false
    private var shortcutPlaceholder: String?
    private var eventMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private weak var boundUserDefaults: UserDefaults?
    private var isLoadingDefaults = false
    private let buttonCell = NSButtonCell()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        stopMonitoringEvents()
        stopObservingWindow()
        stopObservingDefaults()
    }

    private func commonInit() {
        buttonCell.setButtonType(.pushOnPushOff)
        buttonCell.bezelStyle = .rounded
        buttonCell.font = NSFont.systemFont(ofSize: 11)
        buttonCell.alignment = .center
        focusRingType = .exterior
        toolTip = localizedShortcutString(
            "To record a new shortcut, click this button, and then type the new shortcut, or press delete to clear an existing shortcut."
        )
    }

    public func bind(
        toUserDefaultsKey key: String?,
        userDefaults: UserDefaults = .standard
    ) {
        stopObservingDefaults()
        associatedUserDefaultsKey = key
        boundUserDefaults = key == nil ? nil : userDefaults

        guard key != nil else { return }
        loadShortcutValueFromDefaults()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: .main
        ) { [weak self] _ in
            self?.loadShortcutValueFromDefaults()
        }
    }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: 120, height: max(19, buttonCell.cellSize.height))
    }

    public override var isFlipped: Bool { true }
    public override var allowsVibrancy: Bool { true }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        buttonCell.isEnabled = isEnabled
        buttonCell.state = recording ? .on : .off
        buttonCell.title = displayedTitle
        buttonCell.draw(withFrame: bounds, in: self)
    }

    public override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            super.mouseDown(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let clearArea = NSRect(
            x: max(bounds.minX, bounds.maxX - 24),
            y: bounds.minY,
            width: min(24, bounds.width),
            height: bounds.height
        )

        if recording {
            if clearArea.contains(point) { recording = false }
        } else if shortcutValue != nil, clearArea.contains(point) {
            shortcutValue = nil
        } else {
            recording = true
        }
    }

    @discardableResult
    func processKeyEvent(
        keyCode: Int,
        modifierFlags: NSEvent.ModifierFlags,
        isFlagsChanged: Bool = false
    ) -> RecorderEventDisposition {
        let shortcut = KeyboardShortcut(keyCode: keyCode, modifierFlags: modifierFlags)

        if keyCode == kVK_Tab { return .passThrough }

        if isFlagsChanged {
            shortcutPlaceholder = shortcut.modifierFlagsString
            needsDisplay = true
            return .consume
        }

        if shortcut.modifierFlags.isEmpty,
           keyCode == kVK_Delete || keyCode == kVK_ForwardDelete {
            shortcutValue = nil
            recording = false
            return .consume
        }

        if shortcut.modifierFlags.isEmpty, keyCode == kVK_Escape {
            recording = false
            return .consume
        }

        if shortcut.modifierFlags == .command,
           keyCode == kVK_ANSI_W || keyCode == kVK_ANSI_Q {
            recording = false
            return .passThrough
        }

        guard let keyString = shortcut.keyCodeString, !keyString.isEmpty else {
            shortcutPlaceholder = shortcut.modifierFlagsString
            needsDisplay = true
            return .consume
        }

        guard shortcutValidator.isShortcutValid(shortcut) else {
            NSSound.beep()
            return .consume
        }

        if let explanation = shortcutValidator.conflict(for: shortcut) {
            showConflictAlert(shortcut: shortcut, explanation: explanation)
            return .consume
        }

        shortcutValue = shortcut
        recording = false
        return .consume
    }

    private var displayedTitle: String {
        if recording {
            if let shortcutPlaceholder, !shortcutPlaceholder.isEmpty {
                return shortcutPlaceholder
            }
            return shortcutValue == nil
                ? localizedShortcutString("Type Shortcut")
                : localizedShortcutString("Type New Shortcut")
        }
        if let shortcutValue {
            return "\(shortcutValue.description)  ×"
        }
        return localizedShortcutString("Record Shortcut")
    }

    private func setRecording(_ newValue: Bool) {
        if newValue {
            guard isEnabled else { return }
            if Self.activeRecorder !== self {
                Self.activeRecorder?.recording = false
                Self.activeRecorder = self
            }
        }

        guard recordingStorage != newValue else { return }
        recordingStorage = newValue
        shortcutPlaceholder = nil

        if newValue {
            startMonitoringEvents()
            startObservingWindow()
        } else {
            stopMonitoringEvents()
            stopObservingWindow()
            if Self.activeRecorder === self { Self.activeRecorder = nil }
            announceRecordingResult()
        }

        invalidateIntrinsicContentSize()
        needsDisplay = true
        onRecordingChanged?(newValue)
    }

    private func startMonitoringEvents() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            guard let self else { return event }
            let disposition = self.processKeyEvent(
                keyCode: Int(event.keyCode),
                modifierFlags: event.modifierFlags,
                isFlagsChanged: event.type == .flagsChanged
            )
            return disposition == .passThrough ? event : nil
        }
    }

    private func stopMonitoringEvents() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func startObservingWindow() {
        guard resignObserver == nil, let window else { return }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.recording = false
        }
    }

    private func stopObservingWindow() {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }

    private func stopObservingDefaults() {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
    }

    private func loadShortcutValueFromDefaults() {
        guard let key = associatedUserDefaultsKey,
              let userDefaults = boundUserDefaults
        else { return }

        let shortcut = (userDefaults.object(forKey: key) as? [String: Any])
            .flatMap(KeyboardShortcut.init(dictionaryRepresentation:))
        guard shortcut != shortcutValue else { return }
        isLoadingDefaults = true
        shortcutValue = shortcut
        isLoadingDefaults = false
    }

    private func persistShortcutValue() {
        guard !isLoadingDefaults,
              let key = associatedUserDefaultsKey,
              let userDefaults = boundUserDefaults
        else { return }
        userDefaults.set(shortcutValue?.dictionaryRepresentation ?? [:], forKey: key)
    }

    private func showConflictAlert(shortcut: KeyboardShortcut, explanation: String) {
        stopMonitoringEvents()
        stopObservingWindow()

        let format = localizedShortcutString("The key combination %@ cannot be used")
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.informativeText = explanation
        alert.messageText = String(format: format, shortcut.description)
        alert.addButton(withTitle: localizedShortcutString("OK"))
        alert.runModal()

        shortcutPlaceholder = nil
        if recording {
            startMonitoringEvents()
            startObservingWindow()
        }
    }

    private func announceRecordingResult() {
        let announcement = shortcutValue == nil
            ? localizedShortcutString("Shortcut cleared")
            : localizedShortcutString("Shortcut set")
        NSAccessibility.post(
            element: self,
            notification: .announcementRequested,
            userInfo: [
                .announcement: announcement,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }

    public override func isAccessibilityElement() -> Bool { true }

    public override func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }

    public override func accessibilityLabel() -> String? {
        let title = shortcutValue?.description ?? "Empty"
        return "\(title) \(localizedShortcutString("keyboard shortcut"))"
    }

    public override func accessibilityHelp() -> String? {
        localizedShortcutString(
            "To record a new shortcut, click this button, and then type the new shortcut, or press delete to clear an existing shortcut."
        )
    }

    public override func accessibilityPerformPress() -> Bool {
        guard !recording else { return false }
        recording = true
        return recording
    }
}
