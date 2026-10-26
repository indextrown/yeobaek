/// 서울시 실시간 도시데이터가 장소를 나누는 공식 분류입니다.
public enum PlaceCategory: String, CaseIterable, Equatable, Sendable {
    case heritage = "고궁·문화유산"
    case park = "공원"
    case touristZone = "관광특구"
    case commercialDistrict = "발달상권"
    case denselyPopulated = "인구밀집지역"
}
