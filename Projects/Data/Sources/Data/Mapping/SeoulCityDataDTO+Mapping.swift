import Domain
import Foundation

extension SeoulCityDataResponseDTO {
    /// 통합 응답을 장소 상세로 바꿉니다.
    ///
    /// - Returns: 장소 상세 정보입니다.
    /// - Throws: API 오류이거나 실시간 인구가 없으면 `SeoulPopulationMappingError`가 발생합니다.
    public func toDomain() throws -> PlaceDetail {
        guard result.isSuccess else {
            throw SeoulPopulationMappingError.apiError(code: result.code, message: result.message)
        }
        guard let cityData, let population = cityData.populations.first else {
            throw SeoulPopulationMappingError.missingPopulation
        }

        return PlaceDetail(
            placeID: cityData.areaCode,
            snapshot: try population.toDomain(),
            demographics: population.demographics,
            transitFlow: cityData.transitFlow,
            commerce: cityData.commerceSummary,
            subwayArrivals: cityData.subwayArrivals,
            roadStatus: SeoulValueParsing.nonBlank(cityData.roadTraffic?["AVG_ROAD_DATA"]?["ROAD_TRAFFIC_IDX"]?.string),
            parkingLotCount: cityData.parkingLots?.array.count ?? 0,
            weather: cityData.weatherSummary,
            events: cityData.placeEvents
        )
    }
}

extension SeoulCityDataDTO {
    var transitFlow: TransitFlow? {
        let subway = subwayPopulation?.firstObject
        let bus = busPopulation?.firstObject
        guard subway != nil || bus != nil else { return nil }

        return TransitFlow(
            subwayStationCount: SeoulValueParsing.integer(subway?["SUB_STN_CNT"]?.string) ?? 0,
            subwayBoarding: Self.recentRange(subway, prefix: "SUB", direction: "GTON"),
            subwayAlighting: Self.recentRange(subway, prefix: "SUB", direction: "GTOFF"),
            busStopCount: SeoulValueParsing.integer(bus?["BUS_STN_CNT"]?.string) ?? 0,
            busBoarding: Self.recentRange(bus, prefix: "BUS", direction: "GTON"),
            busAlighting: Self.recentRange(bus, prefix: "BUS", direction: "GTOFF")
        )
    }

    /// 최근 30분 승차 또는 하차 인원 범위를 읽습니다.
    ///
    /// - Parameters:
    ///   - object: 지하철 또는 버스 승하차 객체입니다.
    ///   - prefix: `SUB` 또는 `BUS`입니다.
    ///   - direction: 승차는 `GTON`, 하차는 `GTOFF`입니다.
    /// - Returns: 인원 범위이며, 값이 없으면 `nil`입니다.
    private static func recentRange(
        _ object: JSONValue?,
        prefix: String,
        direction: String
    ) -> PopulationRange? {
        SeoulValueParsing.population(
            minimum: object?["\(prefix)_30WTHN_\(direction)_PPLTN_MIN"]?.string,
            maximum: object?["\(prefix)_30WTHN_\(direction)_PPLTN_MAX"]?.string
        )
    }

    var commerceSummary: CommerceSummary? {
        guard let object = commerce?.firstObject,
              let activity = SeoulValueParsing.nonBlank(object["AREA_CMRCL_LVL"]?.string) else {
            return nil
        }
        let categories = (object["CMRCL_RSB"]?.array ?? []).compactMap { item -> CommerceSummary.Category? in
            guard let name = SeoulValueParsing.nonBlank(item["RSB_MID_CTGR"]?.string),
                  let level = SeoulValueParsing.nonBlank(item["RSB_PAYMENT_LVL"]?.string) else {
                return nil
            }
            return CommerceSummary.Category(name: name, activity: level)
        }
        return CommerceSummary(activity: activity, categories: categories)
    }

    var subwayArrivals: [SubwayArrival] {
        (subwayStations?.array ?? []).flatMap { station -> [SubwayArrival] in
            guard let stationName = SeoulValueParsing.nonBlank(station["SUB_STN_NM"]?.string) else { return [] }
            return (station["SUB_DETAIL"]?.array ?? []).compactMap { detail in
                guard let line = SeoulValueParsing.nonBlank(detail["SUB_LINE"]?.string),
                      let direction = SeoulValueParsing.nonBlank(detail["SUB_ROUTE_NM"]?.string),
                      let message = SeoulValueParsing.nonBlank(detail["SUB_ARMG1"]?.string) else {
                    return nil
                }
                return SubwayArrival(stationName: stationName, line: line, direction: direction, message: message)
            }
        }
    }

    var weatherSummary: WeatherSummary? {
        guard let object = weather?.firstObject,
              let temperature = SeoulValueParsing.decimal(object["TEMP"]?.string) else {
            return nil
        }
        return WeatherSummary(
            temperature: temperature,
            sky: SeoulValueParsing.nonBlank(object["FCST24HOURS"]?.array.first?["SKY_STTS"]?.string),
            precipitationMessage: SeoulValueParsing.nonBlank(object["PCP_MSG"]?.string),
            fineDust: SeoulValueParsing.nonBlank(object["PM10_INDEX"]?.string),
            ultraFineDust: SeoulValueParsing.nonBlank(object["PM25_INDEX"]?.string)
        )
    }

    var placeEvents: [PlaceEvent] {
        (events?.array ?? []).compactMap { event in
            guard let name = SeoulValueParsing.nonBlank(event["EVENT_NM"]?.string) else { return nil }
            return PlaceEvent(
                name: name,
                period: SeoulValueParsing.nonBlank(event["EVENT_PERIOD"]?.string) ?? "",
                venue: SeoulValueParsing.nonBlank(event["EVENT_PLACE"]?.string),
                url: SeoulValueParsing.nonBlank(event["URL"]?.string).flatMap(URL.init(string:))
            )
        }
    }
}
