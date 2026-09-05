import Foundation
import Observation

/// 기존 MapKit 화면의 표현을 보존하는 현재 위치 기능 기본 정책입니다.
public enum MapFeatureLocationPolicy {
    /// 구현 전 화면에서 사용하던 위도·경도 범위입니다.
    public static let cameraSpan = 0.18

    /// 별도 제품 수치가 정해질 때까지 양쪽 구현에 동일하게 적용하는 호환 제한 시간입니다.
    public static let compatibilityTimeoutNanoseconds: UInt64 = 10_000_000_000
}

public struct MapFeatureCameraCommand: Equatable, Sendable {
    public let coordinate: MapFeatureCoordinate
    public let commandID: UUID
}

public struct MapFeatureAlert: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case failure, timeout }
    public let id: UUID
    public let kind: Kind
    public let message: String
}

@MainActor
@Observable
public final class MapFeatureSession {
    private var didStartAutomatically = false
    public private(set) var requestCount = 0
    public private(set) var cameraIsCenteredOnCurrentLocation = false
    private(set) var cameraCoordinate = MapFeatureCoordinate(
        latitude: 37.5665,
        longitude: 126.9780
    )
    private(set) var cameraSpan = MapFeatureLocationPolicy.cameraSpan
    private var currentLocationTarget: MapFeatureCoordinate?

    public init() {}

    /// 아직 자동 실행하지 않았다면 요청 동작을 한 번 수행합니다.
    ///
    /// - Parameter request: 최초 화면 활성화 시 수행할 위치 요청입니다.
    /// - Returns: 이번 호출에서 요청을 시작했는지 여부입니다.
    @discardableResult
    func startAutomatically(
        _ request: () -> Void
    ) -> Bool {
        guard !didStartAutomatically else { return false }
        didStartAutomatically = true
        requestCount += 1
        request()
        return true
    }

    /// 사용자가 요청한 위치 이동을 실행하고 앱 실행 수명의 요청 횟수를 기록합니다.
    ///
    /// - Parameter request: 내 위치 버튼 입력으로 수행할 위치 요청입니다.
    func startManually(
        _ request: () -> Void
    ) {
        requestCount += 1
        request()
    }

    /// 현재 위치 카메라 명령의 목표 좌표를 기록합니다.
    ///
    /// - Parameter coordinate: 실제 카메라 callback에서 확인할 목표 좌표입니다.
    func expectCurrentLocationCamera(
        _ coordinate: MapFeatureCoordinate
    ) {
        currentLocationTarget = coordinate
        cameraIsCenteredOnCurrentLocation = isCameraCentered(on: coordinate)
    }

    /// MapKit이 실제로 표시한 카메라를 앱 실행 수명 동안 보관합니다.
    ///
    /// - Parameters:
    ///   - coordinate: MapKit 카메라 callback이 보고한 중심 좌표입니다.
    ///   - span: MapKit 카메라 callback이 보고한 위도 범위입니다.
    func recordCamera(
        coordinate: MapFeatureCoordinate,
        span: Double
    ) {
        cameraCoordinate = coordinate
        cameraSpan = span
        let isCentered = currentLocationTarget.map {
            abs($0.latitude - coordinate.latitude) <= 0.000_1
                && abs($0.longitude - coordinate.longitude) <= 0.000_1
        } ?? false
        if cameraIsCenteredOnCurrentLocation != isCentered {
            cameraIsCenteredOnCurrentLocation = isCentered
        }
    }

    /// 마지막 MapKit callback의 중심이 목표 좌표와 일치하는지 확인합니다.
    ///
    /// - Parameter coordinate: 현재 위치 이동 명령의 목표 좌표입니다.
    /// - Returns: 실제로 기록된 카메라가 목표 좌표의 허용 오차 안에 있으면 `true`입니다.
    private func isCameraCentered(
        on coordinate: MapFeatureCoordinate
    ) -> Bool {
        abs(coordinate.latitude - cameraCoordinate.latitude) <= 0.000_1
            && abs(coordinate.longitude - cameraCoordinate.longitude) <= 0.000_1
    }
}

@MainActor
@Observable
public final class MapFeatureViewModel {
    public enum State: Equatable { case idle, requestingAuthorization, locating, located, authorizationDenied, failed }

    public private(set) var state: State = .idle
    public private(set) var cameraCommand: MapFeatureCameraCommand?
    public private(set) var alert: MapFeatureAlert?
    public private(set) var requestCount = 0
    public var authorizationMessage: String? {
        state == .authorizationDenied ? "위치 권한이 없어 현재 위치를 확인할 수 없습니다." : nil
    }
    public var isLoading: Bool { state == .requestingAuthorization || state == .locating }

    @ObservationIgnored private let provider: any MapLocationProviding
    @ObservationIgnored private let timeoutNanoseconds: UInt64
    @ObservationIgnored private var requestTask: Task<Void, Never>?
    @ObservationIgnored private var activeRequestID: UUID?

    /// MapKit 위치 흐름을 관리하는 ViewModel을 만듭니다.
    ///
    /// - Parameters:
    ///   - provider: 비동기 권한과 위치를 제공할 객체입니다.
    ///   - timeoutNanoseconds: 위치 조회 제한 시간입니다.
    public init(
        provider: any MapLocationProviding,
        timeoutNanoseconds: UInt64 = MapFeatureLocationPolicy.compatibilityTimeoutNanoseconds
    ) {
        self.provider = provider
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    /// Core Location 제공자와 제품 수치 확정 전 임시 제한 시간으로 ViewModel을 만듭니다.
    public convenience init() {
#if DEBUG
        if ProcessInfo.processInfo.environment["UITEST_LOCATION_SCENARIO"] == "success" {
            self.init(provider: MapFeatureUITestLocationProvider())
            return
        }
#endif
        self.init(provider: CoreMapLocationProvider())
    }

    public func moveToCurrentLocation() {
        guard requestTask == nil else { return }
        requestCount += 1
        alert = nil
        let requestID = UUID()
        activeRequestID = requestID
        let provider = provider
        let timeoutNanoseconds = timeoutNanoseconds
        requestTask = Task { [weak self] in
            do {
                var authorization = provider.authorizationStatus()
                if authorization == .notDetermined {
                    guard self?.transitionToAuthorizationRequest(requestID: requestID) == true else {
                        provider.cancel()
                        return
                    }
                    authorization = try await provider.requestAuthorization()
                }
                try Task.checkCancellation()
                guard self?.transitionToLocationRequest(
                    authorization: authorization,
                    requestID: requestID
                ) == true else {
                    return
                }
                let coordinate = try await Self.locationWithTimeout(
                    provider: provider,
                    timeoutNanoseconds: timeoutNanoseconds
                )
                try Task.checkCancellation()
                self?.finishRequest(
                    coordinate: coordinate,
                    requestID: requestID
                )
            } catch {
                self?.finishRequest(
                    error: error,
                    requestID: requestID
                )
            }
        }
    }

    public func cancel() {
        requestTask?.cancel()
        requestTask = nil
        activeRequestID = nil
        provider.cancel()
        if isLoading { state = .idle }
    }

    public func dismissAlert() {
        alert = nil
    }

    deinit {
        requestTask?.cancel()
    }

    /// 활성 요청을 권한 대기 상태로 전환합니다.
    ///
    /// - Parameter requestID: 이전 취소 작업과 새 요청을 구분하는 식별자입니다.
    /// - Returns: 요청이 여전히 활성 상태이면 `true`입니다.
    private func transitionToAuthorizationRequest(
        requestID: UUID
    ) -> Bool {
        guard activeRequestID == requestID else { return false }
        state = .requestingAuthorization
        return true
    }

    /// 권한 결과를 반영하고 위치 조회를 시작할지 결정합니다.
    ///
    /// - Parameters:
    ///   - authorization: 위치 제공자가 반환한 최신 권한 상태입니다.
    ///   - requestID: 이전 취소 작업과 새 요청을 구분하는 식별자입니다.
    /// - Returns: 위치 조회를 계속해야 하면 `true`입니다.
    private func transitionToLocationRequest(
        authorization: MapFeatureAuthorization,
        requestID: UUID
    ) -> Bool {
        guard activeRequestID == requestID else { return false }
        guard authorization == .authorized else {
            requestTask = nil
            activeRequestID = nil
            state = .authorizationDenied
            return false
        }
        state = .locating
        return true
    }

    /// 성공한 위치 요청을 카메라 명령으로 반영합니다.
    ///
    /// - Parameters:
    ///   - coordinate: 제공자가 반환한 현재 위치입니다.
    ///   - requestID: 이전 취소 작업과 새 요청을 구분하는 식별자입니다.
    private func finishRequest(
        coordinate: MapFeatureCoordinate,
        requestID: UUID
    ) {
        guard activeRequestID == requestID else { return }
        guard coordinate.isValid else {
            finishRequest(error: MapFeatureLocationError.invalidCoordinate, requestID: requestID)
            return
        }
        cameraCommand = MapFeatureCameraCommand(coordinate: coordinate, commandID: UUID())
        requestTask = nil
        activeRequestID = nil
        state = .located
    }

    /// 실패하거나 취소된 위치 요청을 화면 상태로 정리합니다.
    ///
    /// - Parameters:
    ///   - error: 요청을 종료한 오류입니다.
    ///   - requestID: 이전 취소 작업과 새 요청을 구분하는 식별자입니다.
    private func finishRequest(
        error: Error,
        requestID: UUID
    ) {
        guard activeRequestID == requestID else { return }
        requestTask = nil
        activeRequestID = nil
        if error is CancellationError {
            state = .idle
        } else if error as? MapFeatureLocationError == .timedOut {
            state = .failed
            alert = MapFeatureAlert(id: UUID(), kind: .timeout, message: "현재 위치를 확인하는 데 시간이 오래 걸립니다. 다시 시도해 주세요.")
        } else {
            state = .failed
            alert = MapFeatureAlert(id: UUID(), kind: .failure, message: "현재 위치를 확인하지 못했습니다. 다시 시도해 주세요.")
        }
    }

    /// 단일 위치 요청과 제한 시간을 경쟁시킵니다.
    ///
    /// - Parameters:
    ///   - provider: 현재 위치를 반환할 제공자입니다.
    ///   - timeoutNanoseconds: 요청을 기다릴 최대 나노초입니다.
    /// - Returns: 제한 시간 안에 반환된 현재 위치입니다.
    /// - Throws: 위치 제공, 제한 시간 또는 취소 과정에서 발생한 오류입니다.
    private static func locationWithTimeout(
        provider: any MapLocationProviding,
        timeoutNanoseconds: UInt64
    ) async throws -> MapFeatureCoordinate {
        try await withThrowingTaskGroup(of: MapFeatureCoordinate.self) { group in
            group.addTask { [provider] in try await provider.requestLocation() }
            group.addTask { [timeoutNanoseconds] in
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw MapFeatureLocationError.timedOut
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

#if DEBUG
@MainActor
private final class MapFeatureUITestLocationProvider: MapLocationProviding {
    func authorizationStatus() -> MapFeatureAuthorization { .authorized }

    func requestAuthorization() async throws -> MapFeatureAuthorization { .authorized }

    func requestLocation() async throws -> MapFeatureCoordinate {
        try await Task.sleep(for: .milliseconds(300))
        return MapFeatureCoordinate(latitude: 37.5547, longitude: 126.9707)
    }

    func cancel() {}
}
#endif
