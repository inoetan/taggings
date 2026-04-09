import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Width of the invisible hot-zone strip at each screen edge (points)
    @Published var edgeHotZoneWidth: CGFloat = 20

    // Width of the tag panel that slides in
    @Published var tagPanelWidth: CGFloat = 280

    private init() {}
}
