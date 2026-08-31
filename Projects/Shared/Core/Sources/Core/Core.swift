import Foundation
import Domain

public struct CoreService {
    public init() {}

    public static var isReady: Bool {
        Domain.Marker.ready
    }
}
