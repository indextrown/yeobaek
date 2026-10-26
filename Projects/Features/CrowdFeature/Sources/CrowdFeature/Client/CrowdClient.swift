import ComposableArchitecture
import Domain
import Foundation

/// 혼잡도 화면이 사용하는 장소·혼잡도·상세 조회 의존성입니다.
///
/// 실제 구현은 App이 Data 저장소로 조립해 `withDependencies`로 주입합니다.
@DependencyClient
public struct CrowdClient: Sendable {
    /// 장소 목록과 경계를 조회합니다.
    public var catalog: @Sendable () async throws -> PlaceCatalog
    /// 장소 하나의 현재 혼잡도와 예측을 조회합니다.
    public var snapshot: @Sendable (_ placeID: Place.ID) async throws -> CrowdSnapshot
    /// 장소 상세 화면 정보를 조회합니다.
    public var detail: @Sendable (_ placeID: Place.ID) async throws -> PlaceDetail
}

extension CrowdClient {
    /// Domain 저장소로 의존성을 만듭니다.
    ///
    /// - Parameters:
    ///   - places: 장소와 경계를 주는 저장소입니다.
    ///   - crowd: 혼잡도를 주는 저장소입니다.
    ///   - details: 장소 상세를 주는 저장소입니다.
    /// - Returns: 저장소를 호출하는 의존성입니다.
    public static func live(
        places: any PlaceRepository,
        crowd: any CrowdRepository,
        details: any PlaceDetailRepository
    ) -> Self {
        Self(
            catalog: { try await places.fetchCatalog() },
            snapshot: { try await crowd.fetchSnapshot(for: $0) },
            detail: { try await details.fetchDetail(for: $0) }
        )
    }
}

extension CrowdClient: TestDependencyKey {
    public static let testValue = Self()

    public static let previewValue = Self(
        catalog: { CrowdPreviewData.catalog },
        snapshot: { placeID in
            CrowdPreviewData.snapshots[placeID] ?? CrowdSnapshot(
                placeID: placeID,
                level: .relaxed,
                population: PopulationRange(minimum: 3_000, maximum: 3_500),
                observedAt: CrowdPreviewData.observedAt
            )
        },
        detail: { _ in CrowdPreviewData.detail }
    )
}

extension DependencyValues {
    /// 혼잡도 화면의 조회 의존성입니다.
    public var crowdClient: CrowdClient {
        get { self[CrowdClient.self] }
        set { self[CrowdClient.self] = newValue }
    }
}
