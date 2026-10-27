import Domain

/// 홈 시트 제목 아래 요약 문구를 만듭니다.
public enum CrowdSummaryText {
    /// 분포와 불러오기 상태로 한 줄 요약을 만듭니다.
    ///
    /// - Parameters:
    ///   - counts: 단계별 장소 수입니다.
    ///   - isLoading: 아직 받는 중인 장소가 있는지 여부입니다.
    ///   - loadedCount: 받은 장소 수입니다.
    ///   - totalCount: 전체 장소 수입니다.
    ///   - catalogError: 장소 목록 오류 문구입니다. 없으면 `nil`입니다.
    /// - Returns: 시트에 보여 줄 요약 문구입니다.
    public static func make(
        counts: [CrowdRanking.LevelCount],
        isLoading: Bool,
        loadedCount: Int,
        totalCount: Int,
        catalogError: String?
    ) -> String {
        if let catalogError { return catalogError }
        if isLoading { return "혼잡도를 불러오는 중이에요 (\(loadedCount)/\(totalCount))" }
        let count = { (level: CongestionLevel) in counts.first { $0.level == level }?.count ?? 0 }
        if count(.crowded) > 0 { return "붐비는 곳이 \(count(.crowded))곳 있어요." }
        if count(.busy) > 0 { return "대부분 한산해요. \(count(.busy))곳이 약간 붐벼요." }
        if count(.normal) > 0 { return "붐비는 곳은 없고 \(count(.normal))곳이 보통이에요." }
        if count(.relaxed) > 0 { return "모두 한산해요." }
        return "혼잡도 정보를 받지 못했어요."
    }
}
