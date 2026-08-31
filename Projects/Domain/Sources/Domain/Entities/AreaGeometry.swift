public struct AreaGeometry: Equatable, Sendable {
    public let placeID: Place.ID
    public let polygons: [GeoPolygon]

    /// Associates an area with the polygons that define its boundaries.
    ///
    /// - Parameters:
    ///   - placeID: The stable code of the area represented by the geometry.
    ///   - polygons: The area's component polygons, including any disjoint parts.
    public init(
        placeID: Place.ID,
        polygons: [GeoPolygon]
    ) {
        self.placeID = placeID
        self.polygons = polygons
    }
}

/// Closed rings from the area catalog. Interior rings represent holes.
public struct GeoPolygon: Equatable, Sendable {
    public let exteriorRing: [GeoCoordinate]
    public let interiorRings: [[GeoCoordinate]]

    /// Stores a polygon's exterior boundary and optional holes.
    ///
    /// - Parameters:
    ///   - exteriorRing: The ordered coordinates of the closed exterior boundary.
    ///   - interiorRings: Closed boundaries of holes. An empty array means no holes.
    public init(
        exteriorRing: [GeoCoordinate],
        interiorRings: [[GeoCoordinate]] = []
    ) {
        self.exteriorRing = exteriorRing
        self.interiorRings = interiorRings
    }
}
