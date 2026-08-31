import Domain
import Foundation

/// 실제 관측값이 아닌 목업 데이터입니다. 목업 장소 코드는 서울시 API 요청에 사용하지 않습니다.
public enum CrowdMockData {
    public static let places: [Place] = [
        Place(id: "MOCK001", name: "목업 장소 1"),
        Place(id: "MOCK002", name: "목업 장소 2"),
        Place(id: "MOCK003", name: "목업 장소 3"),
        Place(id: "MOCK004", name: "목업 장소 4"),
        Place(id: "MOCK005", name: "목업 장소 5"),
    ]

    /// 기준 시각을 바탕으로 목업 혼잡도 정보를 생성합니다.
    ///
    /// - Parameter referenceDate: 시각 계산의 기준입니다. 기본값은 현재 시각이며, 고정값을 전달하면 같은 시각을 재현할 수 있습니다.
    /// - Returns: 네 단계 혼잡도와 알 수 없음 상태의 목업 목록입니다. 붐빔 항목은 오래된 데이터 상황을 표현합니다.
    public static func snapshots(
        referenceDate: Date = Date()
    ) -> [CrowdSnapshot] {
        let levels: [CongestionLevel] = [.relaxed, .normal, .busy, .crowded, .unknown]

        return zip(places, levels).enumerated().map { index, pair in
            let (place, level) = pair
            let minimum = (index + 1) * 1_000

            return CrowdSnapshot(
                placeID: place.id,
                level: level,
                population: level == .unknown
                    ? nil
                    : PopulationRange(minimum: minimum, maximum: minimum + 500),
                message: "목업 데이터이며 실제 혼잡도가 아닙니다.",
                observedAt: referenceDate.addingTimeInterval(level == .crowded ? -3_600 : -900),
                isReplacementData: false
            )
        }
    }
}
