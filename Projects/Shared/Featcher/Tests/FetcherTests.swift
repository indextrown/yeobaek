import Featcher
import Testing

/// 로컬 우선 조회와 서버 동기화가 외부에 전달하는 결과를 검증합니다.
@Suite("Fetcher의 로컬 우선 조회", .timeLimit(.minutes(1)))
struct FetcherTests {
    @Test("서버 응답 전 로컬 데이터를 내보내고 갱신 후 다시 읽은 데이터를 반환한다")
    func emitsLocalBeforeRemoteAndReturnsPersistedData() async {
        // Given: 서버 응답을 보류하고, 저장 결과는 서버 원본과 다르게 준비합니다.
        let store = LocalStore(data: [1])
        let remoteGate = AsyncStream<Void>.makeStream()
        defer { remoteGate.continuation.finish() }

        let fetcher = Fetcher<Int>(
            onRemote: {
                for await _ in remoteGate.stream {}
                return [2]
            },
            onLocal: { try await store.read() },
            onLocalUpdate: { local, remote in
                await store.update(
                    local: local,
                    remote: remote,
                    persistedData: [1, 2]
                )
            }
        )

        // When: 첫 이벤트를 받은 뒤에만 서버 응답을 허용합니다.
        var iterator = fetcher.fetch().makeAsyncIterator()
        let firstOutput = await iterator.next()
        remoteGate.continuation.finish()

        var events: [RecordedEvent] = []
        if let firstOutput {
            events.append(RecordedEvent(output: firstOutput))
        }
        while let output = await iterator.next() {
            events.append(RecordedEvent(output: output))
        }

        // Then: 로컬 값이 먼저 나오며, 최종 값은 서버 원본이 아닌 저장 결과입니다.
        #expect(events == [
            .inProgress([1]),
            .success([1, 2]),
        ])
        let updates = await store.updates
        #expect(updates == [LocalUpdate(local: [1], remote: [2])])
    }

    @Test("서버 조회가 실패하면 기존 로컬 데이터와 오류를 전달하고 저장하지 않는다")
    func remoteFailurePreservesLocalData() async {
        // Given: 서버 조회만 실패하도록 준비합니다.
        let store = LocalStore(data: [1])
        let fetcher = Fetcher<Int>(
            onRemote: { throw StubError.remote },
            onLocal: { try await store.read() },
            onLocalUpdate: { local, remote in
                await store.update(local: local, remote: remote)
            }
        )

        // When: 조회가 끝날 때까지 모든 이벤트를 수집합니다.
        let events = await collectEvents(from: fetcher)

        // Then: 서버 오류와 기존 데이터를 전달하며 로컬 갱신은 하지 않습니다.
        #expect(events == [
            .inProgress([1]),
            .failure(.remote, [1]),
        ])
        let updates = await store.updates
        #expect(updates.isEmpty)
    }

    @Test("로컬 갱신이 실패하면 기존 로컬 데이터와 저장 오류를 전달한다")
    func localUpdateFailurePreservesLocalData() async {
        // Given: 서버 조회는 성공하지만 로컬 저장은 실패하도록 준비합니다.
        let store = LocalStore(data: [1])
        let fetcher = Fetcher<Int>(
            onRemote: { [2] },
            onLocal: { try await store.read() },
            onLocalUpdate: { _, _ in throw StubError.localUpdate }
        )

        // When: 조회가 끝날 때까지 모든 이벤트를 수집합니다.
        let events = await collectEvents(from: fetcher)

        // Then: 저장하지 못한 서버 값 대신 기존 로컬 값을 유지합니다.
        #expect(events == [
            .inProgress([1]),
            .failure(.localUpdate, [1]),
        ])
    }

    @Test("갱신 후 로컬 재조회가 실패하면 최초 로컬 데이터와 조회 오류를 전달한다")
    func localReloadFailurePreservesInitialData() async {
        // Given: 첫 조회와 저장은 성공하고 두 번째 로컬 조회만 실패합니다.
        let store = LocalStore(data: [1], failingRead: 2)
        let fetcher = Fetcher<Int>(
            onRemote: { [2] },
            onLocal: { try await store.read() },
            onLocalUpdate: { local, remote in
                await store.update(local: local, remote: remote)
            }
        )

        // When: 조회가 끝날 때까지 모든 이벤트를 수집합니다.
        let events = await collectEvents(from: fetcher)

        // Then: 재조회하지 못한 값을 성공으로 내보내지 않고 최초 값을 유지합니다.
        #expect(events == [
            .inProgress([1]),
            .failure(.localRead, [1]),
        ])
    }

    @Test("최초 로컬 조회 실패 시 이벤트 없이 종료하고 서버를 조회하지 않는다")
    func initialLocalFailureFinishesWithoutEvents() async {
        // Given: 현재 구현의 초기 로컬 조회 실패 정책을 기록합니다.
        let store = LocalStore(data: [1], failingRead: 1)
        let remoteCalls = CallCounter()
        let fetcher = Fetcher<Int>(
            onRemote: {
                await remoteCalls.increment()
                return [2]
            },
            onLocal: { try await store.read() },
            onLocalUpdate: { local, remote in
                await store.update(local: local, remote: remote)
            }
        )

        // When: 조회가 끝날 때까지 모든 이벤트를 수집합니다.
        let events = await collectEvents(from: fetcher)

        // Then: 실패 이벤트도 내보내지 않는 현재 정책을 명시적으로 검증합니다.
        #expect(events.isEmpty)
        let remoteCallCount = await remoteCalls.count
        let updates = await store.updates
        #expect(remoteCallCount == 0)
        #expect(updates.isEmpty)
    }

    @Test("로컬 데이터가 비어 있어도 서버 데이터로 갱신할 수 있다")
    func emptyLocalDataCanBeRefreshed() async {
        // Given: 로컬 캐시는 없고 서버에는 데이터가 있습니다.
        let store = LocalStore(data: [])
        let fetcher = Fetcher<Int>(
            onRemote: { [2] },
            onLocal: { try await store.read() },
            onLocalUpdate: { local, remote in
                await store.update(local: local, remote: remote)
            }
        )

        // When: 조회가 끝날 때까지 모든 이벤트를 수집합니다.
        let events = await collectEvents(from: fetcher)

        // Then: 빈 캐시도 진행 상태로 전달하고 갱신 결과를 성공으로 전달합니다.
        #expect(events == [
            .inProgress([]),
            .success([2]),
        ])
    }

    @Test("서버의 빈 응답을 저장한 결과도 정상적인 성공으로 전달한다")
    func emptyRemoteDataCanReplaceLocalData() async {
        // Given: 로컬 값이 있지만 서버의 빈 결과로 대체하는 저장 정책입니다.
        let store = LocalStore(data: [1])
        let fetcher = Fetcher<Int>(
            onRemote: { [] },
            onLocal: { try await store.read() },
            onLocalUpdate: { local, remote in
                await store.update(local: local, remote: remote)
            }
        )

        // When: 조회가 끝날 때까지 모든 이벤트를 수집합니다.
        let events = await collectEvents(from: fetcher)

        // Then: 빈 결과를 실패나 기존 값 유지로 바꾸지 않습니다.
        #expect(events == [
            .inProgress([1]),
            .success([]),
        ])
    }
}

/// 외부 통신이나 실제 DB 없이 실패 지점을 구분하기 위한 테스트 오류입니다.
private enum StubError: Error, Equatable {
    case remote
    case localUpdate
    case localRead
}

/// 실제 이벤트의 상태, 오류, 데이터를 함께 비교하기 위한 테스트 전용 값입니다.
private enum RecordedEvent: Equatable, Sendable {
    case inProgress([Int])
    case success([Int])
    case failure(StubError?, [Int])

    /// Fetcher가 방출한 이벤트를 비교 가능한 값으로 옮깁니다.
    ///
    /// - Parameter output: 상태와 데이터가 포함된 실제 Fetcher 이벤트입니다.
    init(
        output: Fetcher<Int>.Output
    ) {
        switch output.status {
        case .inProgress:
            self = .inProgress(output.data)
        case .success:
            self = .success(output.data)
        case .failure(let error):
            self = .failure(error as? StubError, output.data)
        }
    }
}

/// 스트림이 종료될 때까지 실제 Fetcher의 이벤트를 순서대로 수집합니다.
///
/// - Parameter fetcher: 주입한 조회 및 저장 동작으로 실행할 실제 Fetcher입니다.
/// - Returns: 방출 순서를 유지한 테스트용 이벤트 배열입니다.
private func collectEvents(
    from fetcher: Fetcher<Int>
) async -> [RecordedEvent] {
    var events: [RecordedEvent] = []
    for await output in fetcher.fetch() {
        events.append(RecordedEvent(output: output))
    }
    return events
}

/// 로컬 갱신에 전달된 두 데이터 집합을 기록합니다.
private struct LocalUpdate: Equatable, Sendable {
    let local: [Int]
    let remote: [Int]

    /// 로컬 갱신 호출에서 받은 인자를 기록합니다.
    ///
    /// - Parameters:
    ///   - local: 갱신 전에 조회한 로컬 데이터입니다.
    ///   - remote: 서버에서 조회한 데이터입니다.
    init(
        local: [Int],
        remote: [Int]
    ) {
        self.local = local
        self.remote = remote
    }
}

/// 테스트마다 생성하며, 비동기 접근과 변경 상태를 격리하는 메모리 저장소입니다.
private actor LocalStore {
    private var data: [Int]
    private var readCount = 0
    private let failingRead: Int?
    private(set) var updates: [LocalUpdate] = []

    /// 초기 데이터와 필요한 조회 실패 시점을 설정합니다.
    ///
    /// - Parameters:
    ///   - data: 처음 로컬 조회에서 반환할 데이터입니다.
    ///   - failingRead: 실패시킬 조회 순서입니다. 1부터 시작하며 `nil`이면 실패하지 않습니다.
    init(
        data: [Int],
        failingRead: Int? = nil
    ) {
        self.data = data
        self.failingRead = failingRead
    }

    /// 현재 데이터를 반환하며 지정한 조회 차례에는 테스트 오류를 던집니다.
    ///
    /// - Returns: 현재 저장된 데이터입니다.
    /// - Throws: 지정된 조회 차례에 `StubError.localRead`를 던집니다.
    func read() throws -> [Int] {
        readCount += 1
        if failingRead == readCount {
            throw StubError.localRead
        }
        return data
    }

    /// 갱신 인자를 기록하고 테스트에서 지정한 저장 결과를 반영합니다.
    ///
    /// - Parameters:
    ///   - local: Fetcher가 갱신 전에 조회한 로컬 데이터입니다.
    ///   - remote: Fetcher가 서버에서 조회한 데이터입니다.
    ///   - persistedData: 별도로 지정한 저장 결과입니다. `nil`이면 서버 데이터로 대체합니다.
    func update(
        local: [Int],
        remote: [Int],
        persistedData: [Int]? = nil
    ) {
        updates.append(LocalUpdate(local: local, remote: remote))
        data = persistedData ?? remote
    }
}

/// 서버 조회가 호출되지 않아야 하는 경우를 검증하는 독립적인 호출 기록입니다.
private actor CallCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
