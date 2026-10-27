import Core
import CrowdFeature
import Data
import Domain
import Foundation

/// 앱 전체에서 한 번 만드는 저장소 조립입니다.
///
/// 지도(Mapbox)와 홈·목록·상세(TCA)가 같은 혼잡도 저장소를 공유해서
/// 같은 장소를 두 번 호출하지 않고 5분 캐시를 함께 씁니다.
struct AppDependencies {
    let catalog: PlaceCatalog
    let crowdClient: CrowdClient
    let crowdRepository: any CrowdRepository

    /// 실행 환경에 맞는 저장소를 조립합니다.
    ///
    /// - Parameter environment: UI 테스트 시나리오를 읽을 환경 변수입니다.
    /// - Returns: 장소 목록과 조회 의존성입니다.
    static func make(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppDependencies {
        let places = BundledPlaceRepository()
        let catalog = (try? places.loadCatalog()) ?? PlaceCatalog(places: [], areas: [])
        let repository: any CrowdRepository & PlaceDetailRepository
#if DEBUG
        if environment["UITEST_CROWD_SCENARIO"] == "sample" {
            repository = SampleCrowdRepository()
        } else {
            repository = SeoulCrowdRepository(client: SeoulOpenAPIClient(apiKey: AppConfiguration.seoulAPIKey ?? ""))
        }
#else
        repository = SeoulCrowdRepository(client: SeoulOpenAPIClient(apiKey: AppConfiguration.seoulAPIKey ?? ""))
#endif
        return AppDependencies(
            catalog: catalog,
            crowdClient: .live(places: places, crowd: repository, details: repository),
            crowdRepository: repository
        )
    }
}
