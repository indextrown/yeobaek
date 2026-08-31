import Domain

public struct MockCrowdRepository: CrowdRepository {
    private let snapshotsByPlaceID: [Place.ID: CrowdSnapshot]
    private let failure: CrowdRepositoryError?

    /// 메모리에서 혼잡도를 조회하고, 필요하면 조회 실패를 재현하는 저장소를 생성합니다.
    ///
    /// - Parameters:
    ///   - snapshots: 저장할 혼잡도 목록입니다. 기본값은 목업 데이터이며, 장소 코드가 중복되면 마지막 항목을 사용합니다.
    ///   - failure: 조회 시 재현할 오류입니다. `nil`이면 저장된 정보를 정상 조회합니다.
    public init(
        snapshots: [CrowdSnapshot] = CrowdMockData.snapshots(),
        failure: CrowdRepositoryError? = nil
    ) {
        var snapshotsByPlaceID: [Place.ID: CrowdSnapshot] = [:]
        for snapshot in snapshots {
            snapshotsByPlaceID[snapshot.placeID] = snapshot
        }

        self.snapshotsByPlaceID = snapshotsByPlaceID
        self.failure = failure
    }

    /// 네트워크 요청 없이 메모리에 저장된 혼잡도 정보를 조회합니다.
    ///
    /// - Parameter placeID: 조회할 장소의 고유 코드입니다.
    /// - Returns: 해당 장소 코드에 저장된 혼잡도 정보입니다.
    /// - Throws: 요청 취소 시 `CancellationError`, 설정된 조회 실패 오류, 또는 정보가 없을 때 `CrowdRepositoryError.snapshotNotFound`가 발생합니다.
    public func fetchSnapshot(
        for placeID: Place.ID
    ) async throws -> CrowdSnapshot {
        try Task.checkCancellation()

        if let failure {
            throw failure
        }
        guard let snapshot = snapshotsByPlaceID[placeID] else {
            throw CrowdRepositoryError.snapshotNotFound(placeID: placeID)
        }

        return snapshot
    }
}
