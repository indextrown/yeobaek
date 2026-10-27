import Domain
import Foundation
import Testing
@testable import Data

@Suite("서울 혼잡도 저장소")
struct SeoulCrowdRepositoryTests {
    @Test("요청 주소는 인증키와 장소 이름을 경로에 인코딩한다")
    func requestEncodesPathComponents() throws {
        let request = try #require(SeoulOpenAPIClient.request(
            apiKey: "test-key",
            service: "citydata_ppltn",
            placeID: "광화문·덕수궁"
        ))

        #expect(request.url?.host == "openapi.seoul.go.kr")
        #expect(request.url?.port == 8088)
        #expect(request.url?.absoluteString.hasSuffix("/test-key/json/citydata_ppltn/1/5/%EA%B4%91%ED%99%94%EB%AC%B8%C2%B7%EB%8D%95%EC%88%98%EA%B6%81") == true)
    }

    @Test("인증키가 없으면 요청하지 않는다")
    func missingKeyFailsWithoutRequest() async {
        let calls = Counter()
        let client = SeoulOpenAPIClient(apiKey: "") { _ in
            await calls.increment()
            return (Data(), URLResponse())
        }

        await #expect(throws: SeoulOpenAPIError.missingAPIKey) {
            try await client.fetch(service: "citydata_ppltn", placeID: "POI001")
        }
        #expect(await calls.value == 0)
    }

    @Test("같은 장소는 캐시 시간 동안 다시 호출하지 않는다")
    func snapshotIsCachedUntilExpiry() async throws {
        let calls = Counter()
        let clock = MutableClock()
        let repository = SeoulCrowdRepository(
            client: SeoulOpenAPIClient(apiKey: "key") { request in
                await calls.increment()
                return (try Self.body(for: request), Self.ok(request))
            },
            now: { clock.now }
        )

        _ = try await repository.fetchSnapshot(for: "POI001")
        _ = try await repository.fetchSnapshot(for: "POI001")
        #expect(await calls.value == 1)

        clock.advance(by: 5 * 60)
        _ = try await repository.fetchSnapshot(for: "POI001")
        #expect(await calls.value == 2)
    }

    @Test("동시에 같은 장소를 요청하면 한 번만 호출한다")
    func concurrentRequestsShareOneCall() async throws {
        let calls = Counter()
        let repository = SeoulCrowdRepository(
            client: SeoulOpenAPIClient(apiKey: "key") { request in
                await calls.increment()
                try await Task.sleep(for: .milliseconds(50))
                return (try Self.body(for: request), Self.ok(request))
            }
        )

        async let first = repository.fetchSnapshot(for: "POI001")
        async let second = repository.fetchSnapshot(for: "POI001")
        _ = try await (first, second)

        #expect(await calls.value == 1)
    }

    @Test("상세를 받은 장소는 혼잡도를 따로 호출하지 않는다")
    func detailFillsSnapshotCache() async throws {
        let calls = Counter()
        let repository = SeoulCrowdRepository(
            client: SeoulOpenAPIClient(apiKey: "key") { request in
                await calls.increment()
                return (try Self.body(for: request), Self.ok(request))
            }
        )

        let detail = try await repository.fetchDetail(for: "POI009")
        let snapshot = try await repository.fetchSnapshot(for: "POI009")

        #expect(snapshot == detail.snapshot)
        #expect(await calls.value == 1)
    }

    @Test("동시에 보내는 요청 수를 제한한다")
    func concurrentRequestsAreLimited() async throws {
        let gauge = Gauge()
        let repository = SeoulCrowdRepository(
            client: SeoulOpenAPIClient(apiKey: "key") { request in
                await gauge.enter()
                try await Task.sleep(for: .milliseconds(30))
                await gauge.leave()
                return (try Self.body(for: request), Self.ok(request))
            },
            maxConcurrentRequests: 2
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 1...6 {
                group.addTask { _ = try? await repository.fetchSnapshot(for: String(format: "POI%03d", index)) }
            }
            try await group.waitForAll()
        }

        #expect(await gauge.peak <= 2)
        #expect(await gauge.peak >= 1)
    }

    /// 요청 서비스에 맞는 실제 응답 파일을 반환합니다.
    ///
    /// - Parameter request: 저장소가 보낸 요청입니다.
    /// - Returns: 서비스에 대응하는 응답 본문입니다.
    /// - Throws: 응답 파일이 없으면 오류가 발생합니다.
    private static func body(
        for request: URLRequest
    ) throws -> Data {
        let path = request.url?.path ?? ""
        return try Fixture.data(path.contains("/citydata_ppltn/") ? "citydata_ppltn-POI001" : "citydata-POI009")
    }

    /// 요청에 대한 200 응답을 만듭니다.
    ///
    /// - Parameter request: 응답할 요청입니다.
    /// - Returns: 상태 코드 200의 HTTP 응답입니다.
    private static func ok(
        _ request: URLRequest
    ) -> URLResponse {
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
}

private actor Counter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private actor Gauge {
    private var current = 0
    private(set) var peak = 0

    func enter() {
        current += 1
        peak = max(peak, current)
    }

    func leave() {
        current -= 1
    }
}

private final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 0)

    var now: Date {
        lock.withLock { current }
    }

    /// 현재 시각을 앞으로 옮깁니다.
    ///
    /// - Parameter seconds: 옮길 초입니다.
    func advance(
        by seconds: TimeInterval
    ) {
        lock.withLock { current += seconds }
    }
}
