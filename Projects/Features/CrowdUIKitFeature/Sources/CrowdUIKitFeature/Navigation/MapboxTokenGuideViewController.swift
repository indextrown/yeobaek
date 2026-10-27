import Core
import CrowdPresentation
import MapboxMaps
import UIKit

/// Mapbox 공개 토큰을 확인하고 SDK에 설정합니다.
public enum MapboxAccess {
    /// 공개 토큰이 있으면 Mapbox에 설정합니다.
    ///
    /// - Returns: `pk.`로 시작하는 토큰을 설정했으면 `true`입니다.
    @MainActor
    public static func configure() -> Bool {
        guard let token = AppConfiguration.mapboxAccessToken, token.hasPrefix("pk.") else { return false }
        if MapboxOptions.accessToken != token {
            MapboxOptions.accessToken = token
        }
        return true
    }
}

/// Mapbox 토큰이 없을 때 지도 자리에 보여 주는 안내 화면입니다. SwiftUI 버전의 `ContentUnavailableView`와 같은 문구입니다.
public final class MapboxTokenGuideViewController: UIViewController {
    /// 토큰 안내를 표시합니다.
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "key.horizontal")
        configuration.text = CrowdCopy.tokenMissingTitle
        configuration.secondaryText = CrowdCopy.tokenMissingDescription
        contentUnavailableConfiguration = configuration
    }
}
