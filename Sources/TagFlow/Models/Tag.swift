import AppKit
import Foundation

struct Tag: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var color: TagColor
    var createdAt: Date

    init(id: UUID = UUID(), name: String, color: TagColor = .none, createdAt: Date = Date()) {
        self.id = id
        self.name = name.replacingOccurrences(of: "\n", with: "")
        self.color = color
        self.createdAt = createdAt
    }

    // Finder xattr format: "TagName" or "TagName\nN" where N = color index 1-7
    var finderString: String {
        color == .none ? name : "\(name)\n\(color.rawValue)"
    }

    enum TagColor: Int, Codable, CaseIterable {
        case none   = 0
        case gray   = 1
        case green  = 2
        case purple = 3
        case blue   = 4
        case yellow = 5
        case red    = 6
        case orange = 7

        var nsColor: NSColor {
            switch self {
            case .none:   return .labelColor
            case .gray:   return .systemGray
            case .green:  return .systemGreen
            case .purple: return .systemPurple
            case .blue:   return .systemBlue
            case .yellow: return .systemYellow
            case .red:    return .systemRed
            case .orange: return .systemOrange
            }
        }
    }
}
