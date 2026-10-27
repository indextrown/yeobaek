extension KeyedDecodingContainer {
    /// 문자열, 숫자, `null`이 섞여 오는 서울시 응답 값을 문자열로 읽습니다.
    ///
    /// - Parameter key: 읽을 응답 키입니다.
    /// - Returns: 값을 문자열로 바꾼 결과입니다. 키가 없거나 `null`이면 `nil`입니다.
    func decodeLossyString(
        forKey key: Key
    ) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        return nil
    }
}
