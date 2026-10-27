import Domain
import SwiftUI
import UIKit

/// 지도와 화면이 함께 쓰는 혼잡도 단계별 색과 표시 문구입니다.
///
/// 디자인 기준: 여유 초록 → 보통 노랑 → 약간 붐빔 주황 → 붐빔 빨강으로 밝기도 함께 달라집니다.
/// 색만으로 구분하지 않도록 항상 `title`을 함께 표시합니다.
public enum CongestionPalette {
    /// 지도 영역과 막대에 쓰는 채움색입니다.
    ///
    /// - Parameter level: 혼잡도 단계입니다.
    /// - Returns: 단계의 채움색입니다.
    public static func fill(
        _ level: CongestionLevel
    ) -> UIColor {
        UIColor(hex: hexes(level).fill)
    }

    /// 배지 배경에 쓰는 옅은 색입니다. 다크 모드에서는 채움색을 반투명하게 씁니다.
    ///
    /// - Parameter level: 혼잡도 단계입니다.
    /// - Returns: 단계의 배경색입니다.
    public static func tint(
        _ level: CongestionLevel
    ) -> UIColor {
        let values = hexes(level)
        return UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: values.fill).withAlphaComponent(0.24)
                : UIColor(hex: values.tint)
        }
    }

    /// 배지 글자에 쓰는 진한 색입니다. 다크 모드에서는 채움색을 그대로 씁니다.
    ///
    /// - Parameter level: 혼잡도 단계입니다.
    /// - Returns: 단계의 글자색입니다.
    public static func text(
        _ level: CongestionLevel
    ) -> UIColor {
        let values = hexes(level)
        return UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? values.fill : values.text)
        }
    }

    /// 단계의 한국어 표시 문구를 반환합니다.
    ///
    /// - Parameter level: 혼잡도 단계입니다.
    /// - Returns: 여유, 보통, 약간 붐빔, 붐빔, 정보 없음 중 하나입니다.
    public static func title(
        _ level: CongestionLevel
    ) -> String {
        switch level {
        case .relaxed: "여유"
        case .normal: "보통"
        case .busy: "약간 붐빔"
        case .crowded: "붐빔"
        case .unknown: "정보 없음"
        }
    }

    /// 범례와 분포에 쓰는 표시 순서입니다. 정보 없음은 마지막입니다.
    public static let orderedLevels: [CongestionLevel] = [.relaxed, .normal, .busy, .crowded, .unknown]

    /// 단계의 채움·배경·글자 색 값입니다.
    ///
    /// - Parameter level: 혼잡도 단계입니다.
    /// - Returns: 24비트 RGB 값 세 개입니다.
    private static func hexes(
        _ level: CongestionLevel
    ) -> (fill: UInt32, tint: UInt32, text: UInt32) {
        switch level {
        case .relaxed: (0x2E9E7A, 0xE3F4EC, 0x17694F)
        case .normal: (0xE8B33A, 0xFBF1D6, 0x6E510A)
        case .busy: (0xEE8433, 0xFDE7D5, 0x8F430B)
        case .crowded: (0xD6402B, 0xFADBD6, 0x922214)
        case .unknown: (0x9AA2A8, 0xEEF0EF, 0x4A5258)
        }
    }
}

extension CongestionLevel {
    /// 정렬에 쓰는 붐빔 정도입니다. 정보 없음은 가장 낮습니다.
    public var crowdingRank: Int {
        switch self {
        case .unknown: -1
        case .relaxed: 0
        case .normal: 1
        case .busy: 2
        case .crowded: 3
        }
    }
}

extension UIColor {
    /// 24비트 RGB 값으로 색을 만듭니다.
    ///
    /// - Parameter hex: `0xRRGGBB` 형태의 값입니다.
    convenience init(
        hex: UInt32
    ) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
