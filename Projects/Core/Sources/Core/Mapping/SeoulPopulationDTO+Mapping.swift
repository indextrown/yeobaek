import Domain
import Foundation

public enum SeoulPopulationMappingError: Error, Equatable, Sendable {
    case apiError(code: String, message: String)
    case missingPopulation
    case invalidPlaceID
    case invalidObservedAt(value: String?)
}

extension SeoulPopulationResponseDTO {
    public func toDomain() throws -> [CrowdSnapshot] {
        guard result.isSuccess else {
            throw SeoulPopulationMappingError.apiError(code: result.code, message: result.message)
        }
        guard let populations, !populations.isEmpty else {
            throw SeoulPopulationMappingError.missingPopulation
        }

        return try populations.map { try $0.toDomain() }
    }
}

extension SeoulPopulationDTO {
    public func toDomain() throws -> CrowdSnapshot {
        guard let placeID = nonBlank(areaCode) else {
            throw SeoulPopulationMappingError.invalidPlaceID
        }

        return CrowdSnapshot(
            placeID: placeID,
            level: mappedLevel,
            population: mappedPopulation,
            message: nonBlank(congestionMessage),
            observedAt: try mappedObservedAt(),
            isReplacementData: mappedReplacementFlag
        )
    }

    private var mappedLevel: CongestionLevel {
        switch nonBlank(congestionLevel) {
        case "여유": return .relaxed
        case "보통": return .normal
        case "약간 붐빔": return .busy
        case "붐빔": return .crowded
        default: return .unknown
        }
    }

    private var mappedPopulation: PopulationRange? {
        guard
            let minimumText = nonBlank(populationMinimum),
            let maximumText = nonBlank(populationMaximum),
            let minimum = Int(minimumText),
            let maximum = Int(maximumText)
        else {
            return nil
        }

        return PopulationRange(minimum: minimum, maximum: maximum)
    }

    private var mappedReplacementFlag: Bool? {
        switch nonBlank(replacementYN) {
        case "Y": return true
        case "N": return false
        default: return nil
        }
    }

    private func mappedObservedAt() throws -> Date {
        guard let value = nonBlank(populationTime) else {
            throw SeoulPopulationMappingError.invalidObservedAt(value: populationTime)
        }

        // 여러 작업이 변경 가능한 상태를 공유하지 않도록 포매터를 함수 안에서 생성합니다.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.isLenient = false

        guard
            let date = formatter.date(from: value),
            formatter.string(from: date) == value
        else {
            throw SeoulPopulationMappingError.invalidObservedAt(value: populationTime)
        }

        return date
    }
}

/// 문자열 앞뒤의 공백과 개행을 제거하고, 값이 없거나 비어 있으면 `nil`로 처리합니다.
///
/// - Parameter value: 정리할 원본 문자열입니다. 값이 없으면 `nil`을 전달합니다.
/// - Returns: 앞뒤 공백과 개행을 제거한 문자열입니다. 입력이 없거나 정리 후 비어 있으면 `nil`입니다.
private func nonBlank(
    _ value: String?
) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return nil
    }

    return value
}
