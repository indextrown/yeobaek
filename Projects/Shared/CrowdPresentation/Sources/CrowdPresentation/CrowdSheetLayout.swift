import CoreGraphics

/// 홈 시트 단계와 지도 버튼 배치를 맞추는 크기입니다. 높이는 안전 영역을 뺀 값입니다.
public enum CrowdSheetLayout {
    /// 제목과 요약만 보이는 접힌 높이입니다.
    public static let collapsedHeight: CGFloat = 116

    /// 분포와 붐비는 순 세 곳이 보이는 기본 높이입니다.
    public static let mediumHeight: CGFloat = 330

    /// 펼친 높이의 화면 대비 비율입니다.
    public static let largeRatio: CGFloat = 0.82

    /// 시작할 때 지도의 내 위치 버튼을 시트 위에 띄우기 위한 아래 여백입니다.
    public static var mapControlsBottomInset: CGFloat { controlsInset(forSheetHeight: mediumHeight) }

    /// 시트 높이에 맞는 내 위치 버튼 여백입니다. 시트를 펼치면 버튼은 기본 높이에 머물러 시트 아래로 가려집니다.
    ///
    /// - Parameter height: 현재 시트 높이입니다.
    /// - Returns: 화면 아래 안전 영역에서 버튼까지의 거리입니다.
    public static func controlsInset(
        forSheetHeight height: CGFloat
    ) -> CGFloat {
        min(height, mediumHeight) + 16
    }
}
