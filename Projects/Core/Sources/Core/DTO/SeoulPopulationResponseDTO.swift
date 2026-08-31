public struct SeoulPopulationResponseDTO: Decodable, Sendable {
    /// Error responses may omit the population array.
    public let populations: [SeoulPopulationDTO]?
    public let result: SeoulAPIResultDTO

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

    /// Decodes an API result using dotted response keys or plain error keys.
    ///
    /// - Parameter decoder: The decoder positioned at the response's RESULT object.
    /// - Throws: A decoding error if the result object or its required string fields are invalid.
    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // The citydata response uses dotted keys; common API errors may use plain keys.
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
