import Domain
import Foundation

/// Synthetic fixtures only. These IDs must never be sent to the Seoul API.
public enum CrowdMockData {
    public static let places: [Place] = [
        Place(id: "MOCK001", name: "목업 장소 1"),
        Place(id: "MOCK002", name: "목업 장소 2"),
        Place(id: "MOCK003", name: "목업 장소 3"),
        Place(id: "MOCK004", name: "목업 장소 4"),
        Place(id: "MOCK005", name: "목업 장소 5"),
    ]

    /// Creates synthetic crowd readings relative to a reference date.
    ///
    /// - Parameter referenceDate: The timestamp baseline. Defaults to now; inject a fixed date for repeatability.
    /// - Returns: Four known congestion levels and an unknown reading, including an older crowded reading.
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
