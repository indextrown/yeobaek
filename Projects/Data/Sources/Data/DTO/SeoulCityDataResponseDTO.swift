/// `citydata` 실시간 통합 응답입니다. 인구는 엄격하게, 나머지 묶음은 느슨하게 읽습니다.
/// 출처: https://data.seoul.go.kr/dataList/OA-21285/A/1/datasetView.do
public struct SeoulCityDataResponseDTO: Decodable, Sendable {
    public let result: SeoulAPIResultDTO
    public let cityData: SeoulCityDataDTO?

    /// 장소 객체와 처리 결과를 디코딩합니다. 오류 응답의 최상위 `RESULT.CODE`도 읽습니다.
    ///
    /// - Parameter decoder: 응답 전체를 읽는 디코더입니다.
    /// - Throws: 처리 결과를 읽지 못하거나 장소 객체 형식이 올바르지 않으면 디코딩 오류가 발생합니다.
    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cityData = try container.decodeIfPresent(SeoulCityDataDTO.self, forKey: .cityData)
        result = try container.decodeIfPresent(SeoulAPIResultDTO.self, forKey: .result)
            ?? SeoulAPIResultDTO(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case result = "RESULT"
        case cityData = "CITYDATA"
    }
}

public struct SeoulCityDataDTO: Decodable, Sendable {
    public let areaCode: String
    public let populations: [SeoulPopulationDTO]
    public let subwayPopulation: JSONValue?
    public let busPopulation: JSONValue?
    public let commerce: JSONValue?
    public let subwayStations: JSONValue?
    public let roadTraffic: JSONValue?
    public let parkingLots: JSONValue?
    public let weather: JSONValue?
    public let events: JSONValue?

    /// 통합 응답의 장소 객체를 디코딩합니다.
    ///
    /// - Parameter decoder: `CITYDATA` 객체를 읽는 디코더입니다.
    /// - Throws: 장소 코드나 실시간 인구 형식이 올바르지 않으면 디코딩 오류가 발생합니다.
    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        areaCode = try container.decode(String.self, forKey: .areaCode)
        populations = try container.decodeIfPresent([SeoulPopulationDTO].self, forKey: .populations) ?? []
        subwayPopulation = try? container.decodeIfPresent(JSONValue.self, forKey: .subwayPopulation)
        busPopulation = try? container.decodeIfPresent(JSONValue.self, forKey: .busPopulation)
        commerce = try? container.decodeIfPresent(JSONValue.self, forKey: .commerce)
        subwayStations = try? container.decodeIfPresent(JSONValue.self, forKey: .subwayStations)
        roadTraffic = try? container.decodeIfPresent(JSONValue.self, forKey: .roadTraffic)
        parkingLots = try? container.decodeIfPresent(JSONValue.self, forKey: .parkingLots)
        weather = try? container.decodeIfPresent(JSONValue.self, forKey: .weather)
        events = try? container.decodeIfPresent(JSONValue.self, forKey: .events)
    }

    private enum CodingKeys: String, CodingKey {
        case areaCode = "AREA_CD"
        case populations = "LIVE_PPLTN_STTS"
        case subwayPopulation = "LIVE_SUB_PPLTN"
        case busPopulation = "LIVE_BUS_PPLTN"
        case commerce = "LIVE_CMRCL_STTS"
        case subwayStations = "SUB_STTS"
        case roadTraffic = "ROAD_TRAFFIC_STTS"
        case parkingLots = "PRK_STTS"
        case weather = "WEATHER_STTS"
        case events = "EVENT_STTS"
    }
}
