import CoreLocation
import Foundation
import Testing
@testable import MapFeature

@Suite("MapKit 첫 위치 측정 선택")
struct MapFeatureLocationSampleTests {
    @Test("정확도가 낮아도 최근의 대략적인 위치를 사용할 수 있다")
    func approximateLocationIsUsable() {
        let now = Date()
        let location = makeLocation(timestamp: now, accuracy: 2_000)

        let coordinate = CoreMapLocationProvider.usableCoordinate(from: location, at: now)

        #expect(coordinate == MapFeatureCoordinate(latitude: 37.5, longitude: 127))
    }

    @Test("이전 세션의 오래된 위치는 즉시 이동에 쓰지 않는다")
    func staleLocationIsRejected() {
        let now = Date()
        let location = makeLocation(timestamp: now.addingTimeInterval(-60), accuracy: 10)

        #expect(CoreMapLocationProvider.usableCoordinate(from: location, at: now) == nil)
    }

    @Test("음수 정확도의 무효 측정은 사용하지 않는다")
    func invalidAccuracyIsRejected() {
        let now = Date()
        let location = makeLocation(timestamp: now, accuracy: -1)

        #expect(CoreMapLocationProvider.usableCoordinate(from: location, at: now) == nil)
    }

    /// 현재 시각과 정확도를 제어하는 Core Location 측정값을 만듭니다.
    ///
    /// - Parameters:
    ///   - timestamp: 위치의 측정 시각입니다.
    ///   - accuracy: 미터 단위 수평 정확도입니다.
    /// - Returns: 테스트할 Core Location 측정값입니다.
    private func makeLocation(
        timestamp: Date,
        accuracy: CLLocationAccuracy
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.5, longitude: 127),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
    }
}
