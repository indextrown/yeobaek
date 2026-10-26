import Foundation

/// 특정 시각에 예상되는 장소의 혼잡도와 추정 인구입니다.
public struct CrowdForecast: Equatable, Sendable {
    public let time: Date
    public let level: CongestionLevel
    /// `nil`은 예측 인구를 제공받지 못했다는 뜻입니다.
    public let population: PopulationRange?

    /// 예측 시각의 혼잡도와 인구 범위를 저장합니다.
    ///
    /// - Parameters:
    ///   - time: 예측이 가리키는 시각입니다.
    ///   - level: 예상 혼잡도 단계입니다.
    ///   - population: 예상 인구 범위입니다. 제공되지 않으면 `nil`입니다.
    public init(
        time: Date,
        level: CongestionLevel,
        population: PopulationRange?
    ) {
        self.time = time
        self.level = level
        self.population = population
    }
}
