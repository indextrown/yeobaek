/// Display labels and colors belong to the presentation layer.
public enum CongestionLevel: CaseIterable, Equatable, Sendable {
    case relaxed
    case normal
    case busy
    case crowded
    case unknown
}
