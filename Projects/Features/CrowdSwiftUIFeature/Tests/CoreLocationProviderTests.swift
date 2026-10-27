import CoreLocation
import Foundation
import Testing
@testable import CrowdSwiftUIFeature

@MainActor
@Suite("Core Location 위치 제공자")
struct CoreLocationProviderTests {
    @Test("Core Location 권한 상태를 빠짐없이 Feature 권한으로 변환한다")
    func coreLocationAuthorizationMappingCoversEveryKnownStatus() {
        #expect(CoreLocationProvider.authorization(from: .notDetermined) == .notDetermined)
        #expect(CoreLocationProvider.authorization(from: .authorizedWhenInUse) == .authorized)
        #expect(CoreLocationProvider.authorization(from: .authorizedAlways) == .authorized)
        #expect(CoreLocationProvider.authorization(from: .denied) == .denied)
        #expect(CoreLocationProvider.authorization(from: .restricted) == .denied)
    }

    @Test("continuation 설치 전에 취소된 Core Location 요청은 즉시 종료된다")
    func cancellationBeforeContinuationInstallationFinishesImmediately() async {
        let provider = CoreLocationProvider()
        let task = Task { @MainActor in
            try await provider.requestAuthorization()
        }

        task.cancel()

        do {
            _ = try await task.value
            Issue.record("취소된 요청이 권한 상태를 반환했습니다.")
        } catch is CancellationError {
            // 예상한 취소 종료입니다.
        } catch {
            Issue.record("예상하지 못한 오류로 종료했습니다: \(error)")
        }
    }
}
