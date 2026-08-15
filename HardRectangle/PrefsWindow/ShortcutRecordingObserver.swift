/// ShortcutRecordingObserver.swift

import Cocoa
import HardRectangleShortcuts

class ShortcutRecordingObserver {

    private var observedViews = [ObjectIdentifier: ShortcutRecorderView]()
    private var recordingViews = Set<ObjectIdentifier>()

    func observe(_ views: [ShortcutRecorderView]) {
        for view in views {
            let viewId = ObjectIdentifier(view)
            guard observedViews[viewId] == nil else { continue }

            observedViews[viewId] = view
            view.onRecordingChanged = { [weak self, weak view] isRecording in
                guard let self, let view else { return }
                self.recordingChanged(for: view, isRecording: isRecording)
            }
        }
    }

    deinit {
        for view in observedViews.values {
            view.onRecordingChanged = nil
        }
    }

    func recordingChanged(for view: ShortcutRecorderView, isRecording: Bool) {
        let wasRecording = !recordingViews.isEmpty
        let viewId = ObjectIdentifier(view)
        if isRecording {
            recordingViews.insert(viewId)
        } else {
            recordingViews.remove(viewId)
        }

        let isRecordingAnyView = !recordingViews.isEmpty
        guard wasRecording != isRecordingAnyView else { return }
        Notification.Name.shortcutRecording.post(object: isRecordingAnyView)
    }

}
