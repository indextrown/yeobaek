/// 구조가 자주 바뀌는 응답 일부를 느슨하게 읽기 위한 JSON 값입니다.
public enum JSONValue: Decodable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    /// JSON의 어떤 값이든 대응하는 경우로 디코딩합니다.
    ///
    /// - Parameter decoder: 값 하나를 읽는 디코더입니다.
    /// - Throws: JSON 값이 아니면 디코딩 오류가 발생합니다.
    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    /// 객체의 키 값을 반환합니다. 객체가 아니면 `nil`입니다.
    ///
    /// - Parameter key: 읽을 키입니다.
    subscript(
        key: String
    ) -> JSONValue? {
        if case let .object(object) = self { return object[key] }
        return nil
    }

    /// 문자열 또는 숫자 값을 문자열로 반환합니다.
    var string: String? {
        switch self {
        case let .string(value): value
        case let .number(value): value.rounded() == value ? String(Int(value)) : String(value)
        default: nil
        }
    }

    /// 배열 값이며, 배열이 아니면 빈 배열입니다.
    var array: [JSONValue] {
        if case let .array(values) = self { return values }
        return []
    }

    /// 배열이면 첫 원소, 객체이면 자기 자신을 반환합니다. 응답마다 배열 여부가 다른 항목에 사용합니다.
    var firstObject: JSONValue? {
        switch self {
        case let .array(values): values.first
        case .object: self
        default: nil
        }
    }
}
