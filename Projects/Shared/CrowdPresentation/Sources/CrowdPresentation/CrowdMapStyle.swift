/// SwiftUI와 UIKit 버전 지도가 같은 모양으로 영역과 라벨을 그리도록 공유하는 수치입니다.
public enum CrowdMapStyle {
    /// 영역 채움 투명도입니다. 아래 지도와 건물이 비쳐 보이게 합니다.
    public static let fillOpacity = 0.24

    /// 영역 테두리 두께(pt)입니다.
    public static let lineWidth = 2.0

    /// 라벨 글자 크기(pt)입니다.
    public static let labelTextSize = 11.0

    /// 라벨 글자 테두리 두께(pt)입니다.
    public static let labelHaloWidth = 1.5

    /// 장소 이름 라벨을 보여 줄 최소 확대 수준입니다. 더 넓게 보면 기본 지도 라벨과 겹쳐 숨깁니다.
    public static let labelMinimumZoom = 13.0
}
