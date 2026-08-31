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

        // Keep this formatter local instead of sharing mutable state across tasks.
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

/// Trims surrounding whitespace and treats missing or blank text as unavailable.
///
/// - Parameter value: The optional raw text to normalize.
/// - Returns: Trimmed nonempty text, or nil if the input is absent or blank.
private func nonBlank(
    _ value: String?
) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return nil
    }

    return value
}
