public struct PopulationRange: Equatable, Sendable {
    public let minimum: Int
    public let maximum: Int

    /// 추정 인구 범위를 생성합니다. 최소값이 음수이거나 최대값보다 크면 `nil`을 반환합니다.
    ///
    /// - Parameters:
    ///   - minimum: 명 단위의 최소 추정 인원입니다. 0 이상이어야 합니다.
    ///   - maximum: 명 단위의 최대 추정 인원입니다. 최소값 이상이어야 합니다.
    public init?(
        minimum: Int,
        maximum: Int
    ) {
        guard minimum >= 0, maximum >= minimum else {
            return nil
        }

        self.minimum = minimum
        self.maximum = maximum
    }
}
