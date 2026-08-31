/// 지도 SDK에 의존하지 않는 WGS84 좌표입니다.
public struct GeoCoordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    /// WGS84 좌표계의 위도와 경도를 저장합니다.
    ///
    /// - Parameters:
    ///   - latitude: 도 단위의 위도입니다.
    ///   - longitude: 도 단위의 경도입니다.
    public init(
        latitude: Double,
        longitude: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
