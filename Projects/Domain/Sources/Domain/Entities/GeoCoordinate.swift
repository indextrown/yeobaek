/// A WGS84 coordinate, independent of the map SDK used for rendering.
public struct GeoCoordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    /// Stores a geographic position using WGS84 coordinates.
    ///
    /// - Parameters:
    ///   - latitude: The latitude in degrees.
    ///   - longitude: The longitude in degrees.
    public init(
        latitude: Double,
        longitude: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
