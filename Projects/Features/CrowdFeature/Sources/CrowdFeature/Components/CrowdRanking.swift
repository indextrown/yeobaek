import Core
import Domain

/// 장소 목록과 혼잡도로 화면에 쓸 순서와 분포를 계산합니다.
enum CrowdRanking {
    /// 목록 정렬 기준입니다.
    enum Sort: Equatable, Sendable {
        /// 혼잡도 단계가 높은 순, 같으면 인구가 많은 순입니다.
        case crowding
        /// 추정 인구가 많은 순입니다.
        case population
    }

    /// 장소를 정렬합니다. 혼잡도를 받지 못한 장소는 맨 뒤에 둡니다.
    ///
    /// - Parameters:
    ///   - places: 정렬할 장소입니다.
    ///   - snapshots: 장소 코드별 혼잡도입니다.
    ///   - sort: 정렬 기준입니다.
    /// - Returns: 정렬한 장소입니다. 기준이 같으면 장소 코드 순서입니다.
    static func sorted(
        _ places: [Place],
        snapshots: [Place.ID: CrowdSnapshot],
        by sort: Sort
    ) -> [Place] {
        places.sorted { lhs, rhs in
            let left = snapshots[lhs.id]
            let right = snapshots[rhs.id]
            if (left == nil) != (right == nil) { return left != nil }
            let leftPopulation = CrowdFormat.midpoint(left?.population)
            let rightPopulation = CrowdFormat.midpoint(right?.population)
            if sort == .crowding {
                let leftRank = left?.level.crowdingRank ?? -1
                let rightRank = right?.level.crowdingRank ?? -1
                if leftRank != rightRank { return leftRank > rightRank }
            }
            if leftPopulation != rightPopulation { return leftPopulation > rightPopulation }
            return lhs.id < rhs.id
        }
    }

    /// 단계별 장소 수를 셉니다. 아직 받지 못했거나 실패한 장소는 정보 없음으로 셉니다.
    ///
    /// - Parameters:
    ///   - places: 셀 장소입니다.
    ///   - snapshots: 장소 코드별 혼잡도입니다.
    /// - Returns: 표시 순서의 단계와 장소 수입니다.
    static func counts(
        _ places: [Place],
        snapshots: [Place.ID: CrowdSnapshot]
    ) -> [LevelCount] {
        var counts: [CongestionLevel: Int] = [:]
        for place in places {
            counts[snapshots[place.id]?.level ?? .unknown, default: 0] += 1
        }
        return CongestionPalette.orderedLevels.map { LevelCount(level: $0, count: counts[$0] ?? 0) }
    }

    /// 단계 하나의 장소 수입니다.
    struct LevelCount: Equatable, Sendable {
        let level: CongestionLevel
        let count: Int
    }
}
