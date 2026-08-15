/// PrefsViewController.swift

import Cocoa
import HardRectangleShortcuts
import ServiceManagement

class PrefsViewController: NSViewController {

    var actionsToViews = [WindowAction: ShortcutRecorderView]()
    private let shortcutRecordingObserver = ShortcutRecordingObserver()

    @IBOutlet weak var leftHalfShortcutView: ShortcutRecorderView!
    @IBOutlet weak var rightHalfShortcutView: ShortcutRecorderView!
    @IBOutlet weak var centerHalfShortcutView: ShortcutRecorderView!
    @IBOutlet weak var topHalfShortcutView: ShortcutRecorderView!
    @IBOutlet weak var bottomHalfShortcutView: ShortcutRecorderView!

    @IBOutlet weak var topLeftShortcutView: ShortcutRecorderView!
    @IBOutlet weak var topRightShortcutView: ShortcutRecorderView!
    @IBOutlet weak var bottomLeftShortcutView: ShortcutRecorderView!
    @IBOutlet weak var bottomRightShortcutView: ShortcutRecorderView!
    
    @IBOutlet weak var nextDisplayShortcutView: ShortcutRecorderView!
    @IBOutlet weak var previousDisplayShortcutView: ShortcutRecorderView!
    
    @IBOutlet weak var makeLargerShortcutView: ShortcutRecorderView!
    @IBOutlet weak var makeSmallerShortcutView: ShortcutRecorderView!
    
    @IBOutlet weak var maximizeShortcutView: ShortcutRecorderView!
    @IBOutlet weak var almostMaximizeShortcutView: ShortcutRecorderView!
    @IBOutlet weak var maximizeHeightShortcutView: ShortcutRecorderView!
    @IBOutlet weak var centerShortcutView: ShortcutRecorderView!
    @IBOutlet weak var restoreShortcutView: ShortcutRecorderView!
    
    // Additional
    @IBOutlet weak var firstThirdShortcutView: ShortcutRecorderView!
    @IBOutlet weak var firstTwoThirdsShortcutView: ShortcutRecorderView!
    @IBOutlet weak var centerThirdShortcutView: ShortcutRecorderView!
    @IBOutlet weak var centerTwoThirdsShortcutView: ShortcutRecorderView!
    @IBOutlet weak var lastTwoThirdsShortcutView: ShortcutRecorderView!
    @IBOutlet weak var lastThirdShortcutView: ShortcutRecorderView!

    @IBOutlet weak var moveLeftShortcutView: ShortcutRecorderView!
    @IBOutlet weak var moveRightShortcutView: ShortcutRecorderView!
    @IBOutlet weak var moveUpShortcutView: ShortcutRecorderView!
    @IBOutlet weak var moveDownShortcutView: ShortcutRecorderView!

    @IBOutlet weak var firstFourthShortcutView: ShortcutRecorderView!
    @IBOutlet weak var secondFourthShortcutView: ShortcutRecorderView!
    @IBOutlet weak var thirdFourthShortcutView: ShortcutRecorderView!
    @IBOutlet weak var lastFourthShortcutView: ShortcutRecorderView!
    @IBOutlet weak var firstThreeFourthsShortcutView: ShortcutRecorderView!
    @IBOutlet weak var centerThreeFourthsShortcutView: ShortcutRecorderView!
    @IBOutlet weak var lastThreeFourthsShortcutView: ShortcutRecorderView!

    @IBOutlet weak var topLeftSixthShortcutView: ShortcutRecorderView!
    @IBOutlet weak var topCenterSixthShortcutView: ShortcutRecorderView!
    @IBOutlet weak var topRightSixthShortcutView: ShortcutRecorderView!
    @IBOutlet weak var bottomLeftSixthShortcutView: ShortcutRecorderView!
    @IBOutlet weak var bottomCenterSixthShortcutView: ShortcutRecorderView!
    @IBOutlet weak var bottomRightSixthShortcutView: ShortcutRecorderView!

    
    @IBOutlet weak var showMoreButton: NSButton!
    @IBOutlet weak var additionalShortcutsStackView: NSStackView!
    
    // Settings
    override func awakeFromNib() {
        
        actionsToViews = [
            .leftHalf: leftHalfShortcutView,
            .rightHalf: rightHalfShortcutView,
            .centerHalf: centerHalfShortcutView,
            .topHalf: topHalfShortcutView,
            .bottomHalf: bottomHalfShortcutView,
            .topLeft: topLeftShortcutView,
            .topRight: topRightShortcutView,
            .bottomLeft: bottomLeftShortcutView,
            .bottomRight: bottomRightShortcutView,
            .nextDisplay: nextDisplayShortcutView,
            .previousDisplay: previousDisplayShortcutView,
            .maximize: maximizeShortcutView,
            .almostMaximize: almostMaximizeShortcutView,
            .maximizeHeight: maximizeHeightShortcutView,
            .center: centerShortcutView,
            .larger: makeLargerShortcutView,
            .smaller: makeSmallerShortcutView,
            .restore: restoreShortcutView,
            .firstThird: firstThirdShortcutView,
            .firstTwoThirds: firstTwoThirdsShortcutView,
            .centerThird: centerThirdShortcutView,
            .centerTwoThirds: centerTwoThirdsShortcutView,
            .lastTwoThirds: lastTwoThirdsShortcutView,
            .lastThird: lastThirdShortcutView,
            .moveLeft: moveLeftShortcutView,
            .moveRight: moveRightShortcutView,
            .moveUp: moveUpShortcutView,
            .moveDown: moveDownShortcutView,
            .firstFourth: firstFourthShortcutView,
            .secondFourth: secondFourthShortcutView,
            .thirdFourth: thirdFourthShortcutView,
            .lastFourth: lastFourthShortcutView,
            .firstThreeFourths: firstThreeFourthsShortcutView,
            .centerThreeFourths: centerThreeFourthsShortcutView,
            .lastThreeFourths: lastThreeFourthsShortcutView,
            .topLeftSixth: topLeftSixthShortcutView,
            .topCenterSixth: topCenterSixthShortcutView,
            .topRightSixth: topRightSixthShortcutView,
            .bottomLeftSixth: bottomLeftSixthShortcutView,
            .bottomCenterSixth: bottomCenterSixthShortcutView,
            .bottomRightSixth: bottomRightSixthShortcutView
        ]
        
        for (action, view) in actionsToViews {
            view.bind(toUserDefaultsKey: action.name)
        }
        shortcutRecordingObserver.observe(Array(actionsToViews.values))
        
        if Defaults.allowAnyShortcut.enabled {
            let passThroughValidator = PassthroughShortcutValidator()
            actionsToViews.values.forEach { $0.shortcutValidator = passThroughValidator }
        }
        
        subscribeToAllowAnyShortcutToggle()
        
        additionalShortcutsStackView.isHidden = true
    }
    
    @IBAction func toggleShowMore(_ sender: NSButton) {
        additionalShortcutsStackView.isHidden = !additionalShortcutsStackView.isHidden
        showMoreButton.title = additionalShortcutsStackView.isHidden
            ? "▶︎ ⋯" : "▼"
    }
    
    private func subscribeToAllowAnyShortcutToggle() {
        Notification.Name.allowAnyShortcut.onPost { notification in
            guard let enabled = notification.object as? Bool else { return }
            let validator = enabled ? PassthroughShortcutValidator() : ShortcutValidator()
            self.actionsToViews.values.forEach { $0.shortcutValidator = validator }
        }
    }
    
}

class PassthroughShortcutValidator: ShortcutValidator {
    
    override func isShortcutValid(_ shortcut: KeyboardShortcut) -> Bool {
        return true
    }
    
    override func conflict(for shortcut: KeyboardShortcut) -> String? {
        nil
    }
    
}
