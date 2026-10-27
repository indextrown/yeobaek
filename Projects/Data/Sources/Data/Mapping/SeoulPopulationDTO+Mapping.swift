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
        guard let placeID = SeoulValueParsing.nonBlank(areaCode) else {
            throw SeoulPopulationMappingError.invalidPlaceID
        }
        guard let observedAt = SeoulValueParsing.date(populationTime) else {
            throw SeoulPopulationMappingError.invalidObservedAt(value: populationTime)
        }

        return CrowdSnapshot(
            placeID: placeID,
            level: SeoulValueParsing.level(congestionLevel),
            population: SeoulValueParsing.population(minimum: populationMinimum, maximum: populationMaximum),
            message: SeoulValueParsing.nonBlank(congestionMessage),
            observedAt: observedAt,
            isReplacementData: mappedReplacementFlag,
            forecasts: mappedForecasts
        )
    }

    /// 성별·연령대·비거주자 비율을 Domain 값으로 바꿉니다. 성별 비율이 없으면 `nil`입니다.
    var demographics: PlaceDemographics? {
        guard let male = SeoulValueParsing.decimal(maleRate),
              let female = SeoulValueParsing.decimal(femaleRate) else {
            return nil
        }
        let ages = ageRates.keys.sorted().compactMap { decade in
            SeoulValueParsing.decimal(ageRates[decade]).map {
                PlaceDemographics.AgeRate(decade: decade, rate: $0)
            }
        }
        return PlaceDemographics(
            maleRate: male,
            femaleRate: female,
            ageRates: ages,
            nonResidentRate: SeoulValueParsing.decimal(nonResidentRate)
        )
    }

    private var mappedReplacementFlag: Bool? {
        switch SeoulValueParsing.nonBlank(replacementYN) {
        case "Y": true
        case "N": false
        default: nil
        }
    }

    /// 시각을 읽을 수 없는 예측은 제외하고 시간 순서로 정렬합니다.
    private var mappedForecasts: [CrowdForecast] {
        (forecasts ?? [])
            .compactMap { forecast in
                SeoulValueParsing.date(forecast.time).map {
                    CrowdForecast(
                        time: $0,
                        level: SeoulValueParsing.level(forecast.congestionLevel),
                        population: SeoulValueParsing.population(
                            minimum: forecast.populationMinimum,
                            maximum: forecast.populationMaximum
                        )
                    )
                }
            }
            .sorted { $0.time < $1.time }
    }
}
