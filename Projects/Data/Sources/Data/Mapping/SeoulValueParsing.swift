import Domain
import Foundation

/// 서울시 응답 문자열을 Domain 값으로 바꾸는 공통 규칙입니다.
enum SeoulValueParsing {
    /// 문자열 앞뒤의 공백과 개행을 제거하고, 값이 없거나 비어 있으면 `nil`로 처리합니다.
    ///
    /// - Parameter value: 정리할 원본 문자열입니다.
    /// - Returns: 정리한 문자열이며, 비어 있거나 `None`이면 `nil`입니다.
    static func nonBlank(
        _ value: String?
    ) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              value != "None" else {
            return nil
        }
        return value
    }

    /// 서울시 혼잡도 문구를 Domain 단계로 바꿉니다.
    ///
    /// - Parameter value: `여유`, `보통`, `약간 붐빔`, `붐빔` 중 하나의 문구입니다.
    /// - Returns: 대응하는 단계이며, 알 수 없는 문구는 `.unknown`입니다.
    static func level(
        _ value: String?
    ) -> CongestionLevel {
        switch nonBlank(value) {
        case "여유": .relaxed
        case "보통": .normal
        case "약간 붐빔": .busy
        case "붐빔": .crowded
        default: .unknown
        }
    }

    /// 최소·최대 문자열을 인구 범위로 바꿉니다.
    ///
    /// - Parameters:
    ///   - minimum: 최소 인원 문자열입니다.
    ///   - maximum: 최대 인원 문자열입니다.
    /// - Returns: 유효한 범위이며, 숫자가 아니거나 범위가 맞지 않으면 `nil`입니다.
    static func population(
        minimum: String?,
        maximum: String?
    ) -> PopulationRange? {
        guard let minimum = integer(minimum), let maximum = integer(maximum) else { return nil }
        return PopulationRange(minimum: minimum, maximum: maximum)
    }

    /// 정수 문자열을 읽습니다. `12.0`처럼 소수점이 붙은 정수도 허용합니다.
    ///
    /// - Parameter value: 읽을 문자열입니다.
    /// - Returns: 정수 값이며, 숫자가 아니면 `nil`입니다.
    static func integer(
        _ value: String?
    ) -> Int? {
        guard let text = nonBlank(value) else { return nil }
        if let number = Int(text) { return number }
        if let number = Double(text), number.rounded() == number { return Int(number) }
        return nil
    }

    /// 실수 문자열을 읽습니다.
    ///
    /// - Parameter value: 읽을 문자열입니다.
    /// - Returns: 실수 값이며, 숫자가 아니면 `nil`입니다.
    static func decimal(
        _ value: String?
    ) -> Double? {
        nonBlank(value).flatMap(Double.init)
    }

    /// 한국 표준시 기준의 시각 문자열을 읽습니다.
    ///
    /// - Parameters:
    ///   - value: 읽을 시각 문자열입니다.
    ///   - format: 문자열 형식입니다. 기본값은 `yyyy-MM-dd HH:mm`입니다.
    /// - Returns: 읽은 시각이며, 형식이 맞지 않으면 `nil`입니다.
    static func date(
        _ value: String?,
        format: String = "yyyy-MM-dd HH:mm"
    ) -> Date? {
        guard let value = nonBlank(value) else { return nil }
        // 여러 작업이 변경 가능한 상태를 공유하지 않도록 포매터를 함수 안에서 생성합니다.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60)
        formatter.dateFormat = format
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
            return nil
        }
        return date
    }
}
