public struct Place: Identifiable, Equatable, Sendable {
    public typealias ID = String

    /// 표시 이름이 아닌, 데이터 제공 기관의 고유 장소 코드입니다.
    public let id: ID
    public let name: String
    public let labelCoordinate: GeoCoordinate?

    /// 장소 목록에서 사용할 기본 정보를 생성합니다.
    ///
    /// - Parameters:
    ///   - id: 장소 경계와 혼잡도 정보를 연결하는 고유 코드입니다.
    ///   - name: 화면에 표시할 장소 이름입니다.
    ///   - labelCoordinate: 라벨을 표시할 WGS84 좌표입니다. 좌표가 없으면 `nil`입니다.
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
