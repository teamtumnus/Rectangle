/// WindowHistory.swift

import Foundation

class WindowHistory {
    
    var restoreRects = [CGWindowID: CGRect]() // the last window frame that the user positioned
    
    var lastHardRectangleActions = [CGWindowID: HardRectangleAction]() // the last window frame that this app positioned
    
}
