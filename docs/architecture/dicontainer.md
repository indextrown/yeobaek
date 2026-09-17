---
title: iOS DI Container 패턴
description: AppDIContainer의 네 가지 객체 생성 방식, 공유 생명 주기, 사용처 주석과 MARK 배치 규칙을 설명해요.
---

# yeobaek iOS DI Container 패턴

> `AppDIContainer`의 의존성 관리 패턴을 정리해요. 즉시 생성, 지연 생성, 추가 설정이 있는 지연 생성, Factory Method와 MARK 카테고리 규칙을 다뤄요.

## AppDIContainer 패턴

`AppDIContainer`는 앱 전역의 의존성을 만들고 연결하는 중앙 컨테이너예요. 프로젝트가 다른 이름이나 조립 방식을 사용한다면 실제 구현에 맞게 이 문서를 고쳐요.

### 인스턴스 생성 패턴

| 패턴 | 사용 시점 | 특징 |
| --- | --- | --- |
| `private let` | 컨테이너를 만들 때 객체가 바로 필요해요. | 생성 즉시 한 번 만들고 컨테이너가 유지되는 동안 공유해요. |
| `private lazy var = Type(...)` | 객체를 처음 사용하는 시점까지 생성을 미뤄도 돼요. | 최초 접근 시 한 번 만들고 이후 같은 인스턴스를 공유해요. |
| `private lazy var = { ... }()` | 지연 생성하면서 생성 뒤 추가 설정도 해야 해요. | 직접 초기화하는 `lazy var`와 생명 주기는 같고, 여러 단계의 초기화 과정을 담을 수 있어요. |
| `func make...()` | 요청할 때마다 새 인스턴스가 필요해요. | 화면이나 ViewModel처럼 호출마다 독립된 상태를 가져야 하는 객체에 사용해요. |

```swift
@MainActor
final class AppDIContainer {
    // MARK: - Repository

    // makeMapBoxCrowdViewModel()
    /// 아직 서울시 API 구현이 연결되지 않아 목업 저장소를 사용해요.
    private let crowdRepository: any CrowdRepository = MockCrowdRepository()

    // MARK: - Session

    // AppRootView
    /// MapKit 지도의 카메라와 위치 요청 상태를 앱 실행 동안 유지해요.
    private(set) lazy var mapKitSession = MapFeatureSession()

    // AppRootView
    // makeMapBoxFeatureViewController()
    /// Mapbox 지도의 카메라, 자동 요청 여부와 혼잡도 결과를 앱 실행 동안 유지해요.
    private(set) lazy var mapBoxSession: MapBoxSession = {
        MapBoxSession(crowdViewModel: makeMapBoxCrowdViewModel())
    }()

    // MARK: - ViewModel

    // mapBoxSession
    /// Mapbox 화면에서 사용할 혼잡도 ViewModel을 만들어요.
    ///
    /// - Returns: 목업 경계와 목업 저장소를 연결한 혼잡도 ViewModel이에요.
    private func makeMapBoxCrowdViewModel() -> MapBoxCrowdViewModel {
        MapBoxCrowdViewModel(
            areas: CrowdMockData.areas,
            repository: crowdRepository,
            isMockData: true
        )
    }
}
```

`let`은 컨테이너와 함께 객체를 바로 만들어요. 두 `lazy var` 방식은 모두 최초 접근 시 한 번만 객체를 만들고 공유해요. 실행 클로저는 객체를 만든 뒤 프로퍼티를 설정하거나 초기화 과정을 여러 줄로 나눌 때만 사용해요. `make...()`는 호출할 때마다 새 객체를 반환해요.

Session은 지도를 전환해도 유지해야 해서 `lazy var`로 공유하고, 화면과 ViewModel은 전환할 때마다 새로 만들어야 해서 `make...()`를 사용해요. `AppDIContainer`는 `MapBoxSession` 같은 `@MainActor` 타입을 만들기 때문에 컨테이너 자체도 `@MainActor`예요.

### 사용처 주석 규칙

모든 프로퍼티와 메서드 위에는 해당 의존성을 사용하는 컴포넌트를 주석으로 적어요. 위 예시의 `// AppRootView`, `// makeMapBoxCrowdViewModel()`이 그 주석이에요. 사용처가 여러 곳이면 줄을 나눠 모두 적어요.

```swift
// AppRootView
// makeMapBoxFeatureViewController()
private(set) lazy var mapBoxSession: MapBoxSession = {
    MapBoxSession(crowdViewModel: makeMapBoxCrowdViewModel())
}()
```

사용처 주석은 다음 작업에 활용해요.

- 의존성을 사용하는 위치를 빠르게 추적해요.
- `// (unused)` 표시가 있거나 사용처 주석이 없는 코드를 미사용 후보로 찾아요. 삭제하기 전에는 실제 참조를 다시 확인해요.
- 코드를 삭제하거나 수정할 때 영향을 받는 범위를 확인해요.

### MARK 카테고리 구분

카테고리는 의존성 흐름에 따라 Infrastructure → Domain → Presentation 순서로 배치해요. 현재 컨테이너가 사용하는 카테고리는 다음 다섯 개예요. Storage, Service, UseCase는 아직 조립할 객체가 없어서 두지 않아요.

```swift
@MainActor
final class AppDIContainer {
    // MARK: - Repository

    // MARK: - Session

    // MARK: - ViewModel

    // MARK: - View

    // MARK: - ViewController
}
```

GRDB 저장소나 서울시 API 클라이언트를 연결할 때 `// MARK: - Storage`와 `// MARK: - Service`를 Repository 위에 추가해요. UseCase 계층을 도입하면 Repository와 ViewModel 사이에 `// MARK: - UseCase`를 둬요.

### ViewModel Factory 메서드

컨테이너 밖에서 호출하는 Factory만 `internal`로 열어요. 이 프로젝트에는 아직 Coordinator가 없어서 `AppRootView`가 유일한 호출자예요.

```swift
// MARK: - View

// makeMapBoxFeatureViewController()
/// Mapbox 화면의 View 구현체를 만들어요.
///
/// - Returns: 마지막 카메라를 이어받고 혼잡도 범례를 표시하는 View예요.
private func makeMapBoxScreen() -> any MapBoxFeatureScreenProtocol {
    MapBoxScreenView(
        initialCamera: mapBoxSession.camera,
        showsCrowdOverlay: true
    )
}

// MARK: - ViewController

// AppRootView
/// Mapbox 화면의 View와 ViewModel을 조립해요.
///
/// - Returns: 새로 조립한 Mapbox 화면 ViewController예요.
func makeMapBoxFeatureViewController() -> MapBoxFeatureViewController {
    let screen = makeMapBoxScreen()

    return MapBoxFeatureViewController(
        session: mapBoxSession,
        screen: screen,
        viewModel: makeMapBoxFeatureViewModel(screen: screen)
    )
}
```

View Factory는 `any MapBoxFeatureScreenProtocol`을, ViewModel Factory는 `any MapBoxFeatureViewModelProtocol`을 반환해요. ViewModel이 쓸 위치 제공자가 화면의 지도에서 나오기 때문에 View를 먼저 만들고 그 결과를 ViewModel Factory에 전달해요.

## 관련 문서

- [아키텍처 개요](architecture-overview.md)에서 현재 모듈 책임과 의존성 방향을 확인해요.
- [앱 시작 흐름](app-startup-flow.md)에서 컨테이너의 생성 위치와 Session 생명주기를 확인해요.
- [View·ViewModel 프로토콜 패턴](view-viewmodel-protocols.md)에서 화면 Factory가 프로토콜을 반환하는 예시를 확인해요.
- [프로젝트 작업 안내](../../AGENTS.md)에서 문서 적용 기준을 확인해요.
- 화면 전환을 담당하는 Coordinator는 아직 없어요. 도입할 때 이 문서의 Factory 호출자를 함께 갱신해요.
