public struct SeoulPopulationResponseDTO: Decodable, Sendable {
    /// 오류 응답에서는 인구 정보 배열이 생략될 수 있습니다.
    public let populations: [SeoulPopulationDTO]?
    public let result: SeoulAPIResultDTO

    /// 인구 배열과 처리 결과를 디코딩합니다.
    ///
    /// 오류 응답은 `RESULT` 객체 없이 `RESULT.CODE`가 최상위에 올 수 있어 두 형태를 모두 읽습니다.
    ///
    /// - Parameter decoder: 응답 전체를 읽는 디코더입니다.
    /// - Throws: 처리 결과를 어느 형태로도 읽지 못하면 디코딩 오류가 발생합니다.
    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        populations = try container.decodeIfPresent([SeoulPopulationDTO].self, forKey: .populations)
        result = try container.decodeIfPresent(SeoulAPIResultDTO.self, forKey: .result)
            ?? SeoulAPIResultDTO(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case populations = "SeoulRtd.citydata_ppltn"
        case result = "RESULT"
    }
}

public struct SeoulAPIResultDTO: Decodable, Sendable {
    public let code: String
    public let message: String

    public var isSuccess: Bool {
        code == "INFO-000"
    }

    /// 점이 포함된 응답 키 또는 일반 오류 응답 키를 사용해 API 처리 결과를 디코딩합니다.
    ///
    /// - Parameter decoder: 응답의 `RESULT` 객체를 읽는 디코더입니다.
    /// - Throws: 결과 객체나 필수 문자열 필드가 올바르지 않으면 디코딩 오류가 발생합니다.
    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 도시데이터 응답은 점이 포함된 키를 사용하며, 공통 API 오류는 일반 키를 사용할 수 있습니다.
        code = try container.decodeIfPresent(String.self, forKey: .resultCode)
            ?? container.decode(String.self, forKey: .code)
        message = try container.decodeIfPresent(String.self, forKey: .resultMessage)
            ?? container.decode(String.self, forKey: .message)
    }

    private enum CodingKeys: String, CodingKey {
        case resultCode = "RESULT.CODE"
        case resultMessage = "RESULT.MESSAGE"
        case code = "CODE"
        case message = "MESSAGE"
    }
}
