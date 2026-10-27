/// `citydata_ppltn`과 `citydata`의 실시간 인구 항목을 담는 DTO입니다.
/// 출처: https://data.seoul.go.kr/dataList/OA-21778/A/1/datasetView.do
public struct SeoulPopulationDTO: Decodable, Sendable {
    public let areaName: String
    public let areaCode: String
    public let congestionLevel: String?
    public let congestionMessage: String?
    public let populationMinimum: String?
    public let populationMaximum: String?
    public let populationTime: String?
    public let replacementYN: String?
    public let maleRate: String?
    public let femaleRate: String?
    /// 10세 단위 연령대 비율입니다. 키는 0, 10, …, 70입니다.
    public let ageRates: [Int: String]
    public let nonResidentRate: String?
    public let forecasts: [SeoulForecastDTO]?

    /// 실시간 인구 항목을 디코딩합니다. 숫자가 문자열로 오지 않아도 읽습니다.
    ///
    /// - Parameter decoder: 실시간 인구 객체를 읽는 디코더입니다.
    /// - Throws: 장소 이름이나 코드가 없으면 디코딩 오류가 발생합니다.
    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        areaName = try container.decode(String.self, forKey: .areaName)
        areaCode = try container.decode(String.self, forKey: .areaCode)
        congestionLevel = container.decodeLossyString(forKey: .congestionLevel)
        congestionMessage = container.decodeLossyString(forKey: .congestionMessage)
        populationMinimum = container.decodeLossyString(forKey: .populationMinimum)
        populationMaximum = container.decodeLossyString(forKey: .populationMaximum)
        populationTime = container.decodeLossyString(forKey: .populationTime)
        replacementYN = container.decodeLossyString(forKey: .replacementYN)
        maleRate = container.decodeLossyString(forKey: .maleRate)
        femaleRate = container.decodeLossyString(forKey: .femaleRate)
        nonResidentRate = container.decodeLossyString(forKey: .nonResidentRate)
        forecasts = try? container.decodeIfPresent([SeoulForecastDTO].self, forKey: .forecasts)

        let ageContainer = try decoder.container(keyedBy: AgeKey.self)
        var ageRates: [Int: String] = [:]
        for decade in stride(from: 0, through: 70, by: 10) {
            if let key = AgeKey(stringValue: "PPLTN_RATE_\(decade)"),
               let value = ageContainer.decodeLossyString(forKey: key) {
                ageRates[decade] = value
            }
        }
        self.ageRates = ageRates
    }

    private enum CodingKeys: String, CodingKey {
        case areaName = "AREA_NM"
        case areaCode = "AREA_CD"
        case congestionLevel = "AREA_CONGEST_LVL"
        case congestionMessage = "AREA_CONGEST_MSG"
        case populationMinimum = "AREA_PPLTN_MIN"
        case populationMaximum = "AREA_PPLTN_MAX"
        case populationTime = "PPLTN_TIME"
        case replacementYN = "REPLACE_YN"
        case maleRate = "MALE_PPLTN_RATE"
        case femaleRate = "FEMALE_PPLTN_RATE"
        case nonResidentRate = "NON_RESNT_PPLTN_RATE"
        case forecasts = "FCST_PPLTN"
    }

    private struct AgeKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }

        /// 연령대 비율 키를 만듭니다.
        ///
        /// - Parameter stringValue: `PPLTN_RATE_20` 형태의 응답 키입니다.
        init?(
            stringValue: String
        ) {
            self.stringValue = stringValue
        }

        /// 정수 키는 사용하지 않습니다.
        ///
        /// - Parameter intValue: 사용하지 않는 정수 키입니다.
        init?(
            intValue: Int
        ) {
            nil
        }
    }
}

/// 실시간 인구의 시간대별 예측 항목입니다.
public struct SeoulForecastDTO: Decodable, Sendable {
    public let time: String?
    public let congestionLevel: String?
    public let populationMinimum: String?
    public let populationMaximum: String?

    /// 예측 항목을 디코딩합니다.
    ///
    /// - Parameter decoder: 예측 객체를 읽는 디코더입니다.
    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = container.decodeLossyString(forKey: .time)
        congestionLevel = container.decodeLossyString(forKey: .congestionLevel)
        populationMinimum = container.decodeLossyString(forKey: .populationMinimum)
        populationMaximum = container.decodeLossyString(forKey: .populationMaximum)
    }

    private enum CodingKeys: String, CodingKey {
        case time = "FCST_TIME"
        case congestionLevel = "FCST_CONGEST_LVL"
        case populationMinimum = "FCST_PPLTN_MIN"
        case populationMaximum = "FCST_PPLTN_MAX"
    }
}
