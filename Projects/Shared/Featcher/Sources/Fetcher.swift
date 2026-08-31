//
//  Fetcher.swift
//  Featcher
//
//  Created by 김동현 on 9/1/26.
//

import Foundation

public final class Fetcher<T: Sendable> {
    
    public enum Status {
        case inProgress
        case success
        case failure(Error)
    }
    
    public typealias Output = (
        status: Status,
        data: [T]
    )
    
    // 서버에서 데이터 조회
    private let onRemote: @Sendable () async throws -> [T]
    
    // 로컬 DB에서 데이터 조회
    private let onLocal: @Sendable () async throws -> [T]
    
    // 서버 데이터를 로컬 DB에 반영
    private let onLocalUpdate: @Sendable (
        _ local: [T],
        _ remote: [T]
    ) async throws -> Void
    
    public init(
        onRemote: @escaping @Sendable () async throws -> [T],
        onLocal: @escaping @Sendable () async throws -> [T],
        onLocalUpdate: @escaping @Sendable ([T], [T]) async throws -> Void
    ) {
        self.onRemote = onRemote
        self.onLocal = onLocal
        self.onLocalUpdate = onLocalUpdate
    }
    
    public func fetch() -> AsyncStream<Output> {
        AsyncStream { continuation in

            let task = _Concurrency.Task { [onRemote, onLocal, onLocalUpdate] in
                do {
                    // 1. 로컬 데이터를 먼저 가져온다.
                    let localData = try await onLocal()

                    // 2. 로컬 데이터를 즉시 방출한다.
                    continuation.yield(
                        Output(
                            status: .inProgress,
                            data: localData
                        )
                    )
                    
                    do {
                        // 3. 서버에서 최신 데이터를 가져온다.
                        let remoteData = try await onRemote()

                        // 4. 서버 데이터를 로컬 DB에 반영한다.
                        try await onLocalUpdate(
                            localData,
                            remoteData
                        )

                        // 5. 업데이트된 로컬 데이터를 다시 조회한다.
                        let updatedLocalData = try await onLocal()
                        
                        // 6. 최신 데이터를 방출한다.
                        continuation.yield(
                            Output(
                                status: .success,
                                data: updatedLocalData
                            )
                        )
                        
                    } catch {
                        // Remote 요청 또는 Local Update 실패
                        // 기존 로컬 데이터는 그대로 보여준다.
                        continuation.yield(
                            Output(
                                status: .failure(error),
                                data: localData
                            )
                        )
                    }

                    continuation.finish()

                } catch {
                    // 최초 Local 조회 자체가 실패한 경우
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
