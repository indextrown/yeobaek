/// `citydata_ppltn` 응답 중 현재 인구 정보를 담는 DTO입니다.
/// 성별·연령대별 인구 구성과 예측 정보는 아직 모델링하지 않았습니다.
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

    private enum CodingKeys: String, CodingKey {
        case areaName = "AREA_NM"
        case areaCode = "AREA_CD"
        case congestionLevel = "AREA_CONGEST_LVL"
        case congestionMessage = "AREA_CONGEST_MSG"
        case populationMinimum = "AREA_PPLTN_MIN"
        case populationMaximum = "AREA_PPLTN_MAX"
        case populationTime = "PPLTN_TIME"
        case replacementYN = "REPLACE_YN"
    }
}
