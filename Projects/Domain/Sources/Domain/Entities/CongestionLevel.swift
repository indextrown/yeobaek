/// 혼잡도 단계입니다. 표시 문구와 색상은 화면 계층에서 정의합니다.
public enum CongestionLevel: CaseIterable, Equatable, Sendable {
    case relaxed
    case normal
    case busy
    case crowded
    case unknown
}
