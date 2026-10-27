import Core
import Domain
import Foundation

/// 혼잡도 화면의 숫자와 시각 표시 규칙입니다. SwiftUI와 UIKit 버전이 함께 씁니다.
public enum CrowdFormat {
    /// 인구 범위를 `16,000~18,000명` 형태로 표시합니다.
    ///
    /// - Parameter range: 표시할 인구 범위입니다.
    /// - Returns: 범위 문구이며, 범위가 없으면 `정보 없음`입니다.
    public static func population(
        _ range: PopulationRange?
    ) -> String {
        guard let range else { return "정보 없음" }
        return "\(number(range.minimum))~\(number(range.maximum))명"
    }

    /// 정수를 천 단위 쉼표로 표시합니다.
    ///
    /// - Parameter value: 표시할 정수입니다.
    /// - Returns: 쉼표를 넣은 문자열입니다.
    public static func number(
        _ value: Int
    ) -> String {
        value.formatted(.number.locale(Locale(identifier: "ko_KR")))
    }

    /// 한국 시각 기준 `22:45`를 표시합니다.
    ///
    /// - Parameter date: 표시할 시각입니다.
    /// - Returns: 시와 분입니다.
    public static func time(
        _ date: Date
    ) -> String {
        date.formatted(Date.FormatStyle(timeZone: seoul).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// 한국 시각 기준 시만 `03시` 형태로 표시합니다.
    ///
    /// - Parameter date: 표시할 시각입니다.
    /// - Returns: 두 자리 시와 `시`입니다.
    public static func hour(
        _ date: Date
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoul
        return String(format: "%02d시", calendar.component(.hour, from: date))
    }

    /// 범위의 가운데 값을 계산합니다. 정렬과 비교에 사용합니다.
    ///
    /// - Parameter range: 인구 범위입니다.
    /// - Returns: 최소·최대의 평균이며, 범위가 없으면 0입니다.
    public static func midpoint(
        _ range: PopulationRange?
    ) -> Double {
        guard let range else { return 0 }
        return Double(range.minimum + range.maximum) / 2
    }

    private static let seoul = TimeZone(identifier: "Asia/Seoul") ?? .current
}
