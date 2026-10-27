import CrowdPresentation
import Domain
import Foundation
import ThirdParty

/// UIKit 버전의 홈·목록·상세가 함께 보는 장소와 혼잡도 상태입니다.
///
/// SwiftUI 버전의 `CrowdHomeFeature.State`와 같은 역할입니다. 장소 목록을 한 번 읽고 121곳의 혼잡도를
/// 받으면서 상태를 갱신하고, 화면들은 같은 상태를 구독합니다.
@MainActor
public final class CrowdSnapshotStore {
    /// 화면이 구독하는 장소와 혼잡도 상태입니다.
    public struct State: Equatable {
        public var places: [Place] = []
        public var areas: [AreaGeometry] = []
        public var snapshots: [Place.ID: CrowdSnapshot] = [:]
        public var failedPlaceIDs: Set<Place.ID> = []
        public var didStartLoading = false
        public var catalogErrorMessage: String?

        /// 아직 응답이 오지 않은 장소가 있으면 `true`입니다.
        public var isLoading: Bool {
            didStartLoading && catalogErrorMessage == nil
                && snapshots.count + failedPlaceIDs.count < places.count
        }

        /// 받은 혼잡도 중 가장 최근 원천 데이터 기준 시각입니다.
        public var latestObservedAt: Date? {
            snapshots.values.map(\.observedAt).max()
        }
    }

    private let placeRepository: any PlaceRepository
    private let crowdRepository: any CrowdRepository
    private let relay = BehaviorRelay(value: State())

    /// 장소와 혼잡도 저장소로 상태 저장소를 만듭니다.
    ///
    /// - Parameters:
    ///   - placeRepository: 장소 목록과 경계를 주는 저장소입니다.
    ///   - crowdRepository: 장소별 혼잡도를 주는 저장소입니다.
    public init(
        placeRepository: any PlaceRepository,
        crowdRepository: any CrowdRepository
    ) {
        self.placeRepository = placeRepository
        self.crowdRepository = crowdRepository
    }

    /// 마지막 상태를 다시 내보내는 상태 스트림입니다.
    public var state: Observable<State> {
        relay.asObservable()
    }

    /// 지금 상태입니다.
    public var currentState: State {
        relay.value
    }

    /// 처음 한 번만 장소 목록과 모든 장소의 혼잡도를 불러옵니다.
    public func loadIfNeeded() {
        guard !relay.value.didStartLoading else { return }
        update { $0.didStartLoading = true }
        Task { [weak self, placeRepository] in
            do {
                let catalog = try await placeRepository.fetchCatalog()
                self?.update {
                    $0.places = catalog.places
                    $0.areas = catalog.areas
                }
                self?.loadSnapshots(for: catalog.places.map(\.id))
            } catch {
                self?.update { $0.catalogErrorMessage = CrowdCopy.catalogFailed }
            }
        }
    }

    /// 실패한 장소의 혼잡도를 다시 요청합니다.
    public func retryFailed() {
        let failed = Array(relay.value.failedPlaceIDs)
        update { $0.failedPlaceIDs = [] }
        loadSnapshots(for: failed)
    }

    /// 상세에서 받은 최신 혼잡도를 상태에 반영합니다.
    ///
    /// - Parameter snapshot: 상세 응답에 들어 있던 혼잡도입니다.
    public func record(
        _ snapshot: CrowdSnapshot
    ) {
        update {
            $0.snapshots[snapshot.placeID] = snapshot
            $0.failedPlaceIDs.remove(snapshot.placeID)
        }
    }

    /// 장소마다 혼잡도를 요청합니다. 동시 요청 수와 캐시는 저장소가 관리합니다.
    ///
    /// - Parameter placeIDs: 요청할 장소 코드입니다.
    private func loadSnapshots(
        for placeIDs: [Place.ID]
    ) {
        for placeID in placeIDs {
            Task { [weak self, crowdRepository] in
                do {
                    let snapshot = try await crowdRepository.fetchSnapshot(for: placeID)
                    self?.record(snapshot)
                } catch {
                    self?.update { $0.failedPlaceIDs.insert(placeID) }
                }
            }
        }
    }

    /// 상태를 바꿔 구독자에게 알립니다.
    ///
    /// - Parameter change: 상태를 바꾸는 클로저입니다.
    private func update(
        _ change: (inout State) -> Void
    ) {
        var state = relay.value
        change(&state)
        relay.accept(state)
    }
}
