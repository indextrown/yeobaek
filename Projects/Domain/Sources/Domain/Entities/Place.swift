public struct Place: Identifiable, Equatable, Sendable {
    public typealias ID = String

    /// The provider's stable area code, not the display name.
    public let id: ID
    public let name: String
    public let labelCoordinate: GeoCoordinate?

    /// Creates catalog metadata for an area.
    ///
    /// - Parameters:
    ///   - id: The stable area code used to join geometry and crowd snapshots.
    ///   - name: The area's display name.
    ///   - labelCoordinate: The WGS84 label position, or nil when it is unavailable.
    public init(
        id: ID,
        name: String,
        labelCoordinate: GeoCoordinate? = nil
    ) {
        self.id = id
        self.name = name
        self.labelCoordinate = labelCoordinate
    }
}
