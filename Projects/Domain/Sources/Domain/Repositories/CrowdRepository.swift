public protocol CrowdRepository: Sendable {
    /// API 응답 DTO를 노출하지 않고 한 장소의 혼잡도 정보를 조회합니다.
    ///
    /// - Parameter placeID: 조회할 장소의 고유 코드입니다.
    /// - Returns: 장소의 혼잡도, 추정 인구, 원천 데이터의 기준 시각입니다.
    /// - Throws: 정보가 없거나 조회에 실패한 경우, 또는 요청이 취소된 경우 발생하는 오류입니다.
    func fetchSnapshot(
        for placeID: Place.ID
    ) async throws -> CrowdSnapshot
}

public enum CrowdRepositoryError: Error, Equatable, Sendable {
    case snapshotNotFound(placeID: Place.ID)
    case unavailable
}
