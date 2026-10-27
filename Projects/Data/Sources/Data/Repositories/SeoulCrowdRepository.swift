import Domain
import Foundation

/// 서울 실시간 인구(`citydata_ppltn`)와 실시간 통합(`citydata`) API로 혼잡도와 상세를 조회합니다.
///
/// 원천 데이터는 5분 단위로 갱신되므로 같은 장소는 5분 동안 캐시를 재사용하고,
/// 같은 장소를 동시에 요청하면 진행 중인 요청 하나를 함께 기다립니다.
/// 하루 호출 한도를 아끼기 위해 동시에 보내는 요청 수도 제한합니다.
public actor SeoulCrowdRepository: CrowdRepository, PlaceDetailRepository {
    private let client: SeoulOpenAPIClient
    private let cacheDuration: TimeInterval
    private let maxConcurrentRequests: Int
    private let now: @Sendable () -> Date

    private var snapshots: [Place.ID: (value: CrowdSnapshot, fetchedAt: Date)] = [:]
    private var details: [Place.ID: (value: PlaceDetail, fetchedAt: Date)] = [:]
    private var snapshotTasks: [Place.ID: Task<CrowdSnapshot, Error>] = [:]
    private var detailTasks: [Place.ID: Task<PlaceDetail, Error>] = [:]
    private var runningRequests = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// 클라이언트와 캐시 정책을 지정해 저장소를 만듭니다.
    ///
    /// - Parameters:
    ///   - client: 서울 Open API 클라이언트입니다.
    ///   - cacheDuration: 같은 장소 결과를 재사용할 시간입니다. 기본값은 5분입니다.
    ///   - maxConcurrentRequests: 동시에 보낼 최대 요청 수입니다. 기본값은 6입니다.
    ///   - now: 캐시 만료를 판단할 현재 시각입니다.
    public init(
        client: SeoulOpenAPIClient,
        cacheDuration: TimeInterval = 5 * 60,
        maxConcurrentRequests: Int = 6,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.client = client
        self.cacheDuration = cacheDuration
        self.maxConcurrentRequests = max(1, maxConcurrentRequests)
        self.now = now
    }

    /// 장소 하나의 현재 혼잡도와 예측을 조회합니다.
    ///
    /// - Parameter placeID: 조회할 장소 코드입니다.
    /// - Returns: 혼잡도, 추정 인구와 12시간 예측입니다.
    /// - Throws: 네트워크·API·응답 형식 오류 또는 요청 취소 시 발생하는 오류입니다.
    public func fetchSnapshot(
        for placeID: Place.ID
    ) async throws -> CrowdSnapshot {
        if let cached = snapshots[placeID], now().timeIntervalSince(cached.fetchedAt) < cacheDuration {
            return cached.value
        }
        // 상세를 먼저 받았다면 그 안의 인구 정보로 별도 호출을 아낍니다.
        if let cached = details[placeID], now().timeIntervalSince(cached.fetchedAt) < cacheDuration {
            return cached.value.snapshot
        }
        if let task = snapshotTasks[placeID] {
            return try await task.value
        }

        let task = Task { [client] in
            try await self.limited {
                let data = try await client.fetch(service: "citydata_ppltn", placeID: placeID)
                let response = try JSONDecoder().decode(SeoulPopulationResponseDTO.self, from: data)
                guard let snapshot = try response.toDomain().first(where: { $0.placeID == placeID }) else {
                    throw CrowdRepositoryError.snapshotNotFound(placeID: placeID)
                }
                return snapshot
            }
        }
        snapshotTasks[placeID] = task
        defer { snapshotTasks[placeID] = nil }
        let snapshot = try await task.value
        snapshots[placeID] = (snapshot, now())
        return snapshot
    }

    /// 장소 상세 화면에 필요한 통합 정보를 조회합니다.
    ///
    /// - Parameter placeID: 조회할 장소 코드입니다.
    /// - Returns: 혼잡도, 교통, 상권, 날씨, 행사를 포함한 상세입니다.
    /// - Throws: 네트워크·API·응답 형식 오류 또는 요청 취소 시 발생하는 오류입니다.
    public func fetchDetail(
        for placeID: Place.ID
    ) async throws -> PlaceDetail {
        if let cached = details[placeID], now().timeIntervalSince(cached.fetchedAt) < cacheDuration {
            return cached.value
        }
        if let task = detailTasks[placeID] {
            return try await task.value
        }

        let task = Task { [client] in
            try await self.limited {
                let data = try await client.fetch(service: "citydata", placeID: placeID)
                return try JSONDecoder().decode(SeoulCityDataResponseDTO.self, from: data).toDomain()
            }
        }
        detailTasks[placeID] = task
        defer { detailTasks[placeID] = nil }
        let detail = try await task.value
        let fetchedAt = now()
        details[placeID] = (detail, fetchedAt)
        snapshots[placeID] = (detail.snapshot, fetchedAt)
        return detail
    }

    /// 동시 요청 수 제한 안에서 작업을 실행합니다.
    ///
    /// - Parameter operation: 실행할 네트워크 작업입니다.
    /// - Returns: 작업 결과입니다.
    /// - Throws: 작업이 던진 오류입니다.
    private func limited<Value: Sendable>(
        _ operation: @Sendable () async throws -> Value
    ) async throws -> Value {
        if runningRequests >= maxConcurrentRequests {
            // 끝난 요청이 자리를 그대로 넘겨주므로 깨어난 뒤에는 수를 늘리지 않습니다.
            await withCheckedContinuation { waiters.append($0) }
        } else {
            runningRequests += 1
        }
        defer {
            if waiters.isEmpty {
                runningRequests -= 1
            } else {
                waiters.removeFirst().resume()
            }
        }
        try Task.checkCancellation()
        return try await operation()
    }
}
