import Foundation

struct DragSession {
    let urls: [URL]
    let sourceEdge: ScreenEdge
}

enum ScreenEdge: CaseIterable {
    case top, bottom, leading, trailing

    var opposite: ScreenEdge {
        switch self {
        case .top:      return .bottom
        case .bottom:   return .top
        case .leading:  return .trailing
        case .trailing: return .leading
        }
    }
}
