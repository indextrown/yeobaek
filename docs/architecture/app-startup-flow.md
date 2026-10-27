---
title: 앱 시작 및 지도 화면 흐름
description: YeobaekApp 진입부터 화면 구현(SwiftUI·UIKit) 선택, 저장소 조립, 목록·상세 이동까지 설명한다.
---

# 앱 시작 및 지도 화면 흐름

## 이 문서에서 확인할 것

Yeobaek은 SwiftUI App 생명주기를 사용한다. `YeobaekApp`이 `AppDIContainer`와 `AppRootView`를 만들고, 루트 화면이 설정한 화면 구현(SwiftUI 또는 UIKit)으로 혼잡도 화면 전체를 그린다. 앱 시작, 루트 화면, 화면 구현 선택 또는 전역 초기화를 바꿀 때 이 흐름을 먼저 확인한다.

같은 화면을 두 구현으로 각각 만들었다. **SwiftUI 버전**(`CrowdSwiftUIFeature`)은 지도까지 SwiftUI + TCA이고, **UIKit 버전**(`CrowdUIKitFeature`)은 지도까지 UIKit + RxSwift이다. 한 화면 안에서 두 기술을 섞지 않는다.

## 시작 순서

| 순서 | 실행 위치 | 동작 |
| ---: | --- | --- |
| 1 | `YeobaekApp` | `@main` 진입점으로 실행되고 `AppDIContainer`를 `@State`로 한 번만 만든다. |
| 2 | `AppDIContainer.init` | `UIImplementation.resolve()`로 화면 구현을 고른다. 디버그 실행 환경 변수 `UI_IMPLEMENTATION`, Info.plist `UIImplementation`(빌드 설정 `UI_IMPLEMENTATION`), 기본값 `swiftui` 순서다. |
| 3 | `AppDIContainer.init` | 번들 GeoJSON을 읽는 `BundledPlaceRepository`와 서울 API 키로 `SeoulCrowdRepository`를 만든다. UI 테스트의 `UITEST_CROWD_SCENARIO=sample`이면 `SampleCrowdRepository`를 쓴다. |
| 4 | `AppRootView` | SwiftUI 버전이면 `CrowdHomeView(store: container.crowdHomeStore)`를 그린다. |
| 4' | `AppRootView` | UIKit 버전이면 `container.crowdUIKitCoordinator.navigationController` 하나를 `UIViewControllerRepresentableContainer`로 감싸 그린다. |

```text
YeobaekApp
├─ AppDIContainer (@State, 앱 수명 동안 하나)
└─ AppRootView
   ├─ .swiftUI ─ CrowdHomeView(StoreOf<CrowdHomeFeature>)        SwiftUI + TCA
   │             ├─ CrowdMapView (Mapbox SwiftUI Map) + 내 위치 버튼
   │             ├─ 검색 · 분류 칩 · 기준 시각 / HomeSummarySheet
   │             └─ NavigationStack path: PlaceListView / PlaceDetailView
   └─ .uiKit ─── UIViewControllerRepresentableContainer           (경계는 여기 한 곳)
                 └─ CrowdUIKitCoordinator.navigationController    UIKit + RxSwift
                    ├─ CrowdHomeViewController
                    │  ├─ 자식: MapBoxFeatureViewController (Mapbox MapView) + 내 위치 버튼
                    │  └─ CrowdHomeScreenView (위쪽 겹침, CrowdSheetView)
                    └─ push: PlaceListViewController / PlaceDetailViewController
```

## 객체별 책임

| 객체 | 책임 | 생명주기 소유자 |
| --- | --- | --- |
| `YeobaekApp` | 앱 진입, 최초 Scene 구성과 컨테이너 생성 | SwiftUI App 런타임 |
| `AppDIContainer` | 화면 구현 선택, Repository와 두 구현의 Store·상태·Session·화면 조립 | `YeobaekApp`의 `@State` |
| `AppRootView` | 고른 구현의 루트 화면 표시 | `WindowGroup` |
| `StoreOf<CrowdHomeFeature>` | SwiftUI 버전의 121곳 혼잡도, 현재 위치·카메라, 분류, 이동 경로 | `AppDIContainer`의 `lazy var` |
| `CrowdSnapshotStore` | UIKit 버전의 홈·목록·상세가 함께 보는 장소와 혼잡도 | `AppDIContainer`의 `lazy var` |
| `MapBoxSession` | UIKit 버전 지도의 마지막 카메라, 자동 위치 요청 여부, 혼잡도 ViewModel, 시트 높이만큼의 버튼 여백 | `AppDIContainer`의 `lazy var` |
| `CrowdUIKitCoordinator` | UIKit 버전의 홈·목록·상세 이동 | `AppDIContainer`의 `lazy var` |

두 구현은 같은 `SeoulCrowdRepository` 인스턴스를 받는다. 저장소가 장소별 5분 캐시와 진행 중 요청 공유를 맡으므로, 같은 구현 안에서 지도와 시트가 같은 장소를 요청해도 서울 API는 한 번만 호출된다. 컨테이너의 객체 생성 방식은 [DI Container 패턴](dicontainer.md)에서 확인한다.

## 혼잡도 불러오기

- 홈이 처음 나타나면 장소 목록을 읽고 121곳의 `citydata_ppltn`을 요청한다. 저장소는 동시에 6개까지만 보낸다.
- SwiftUI 버전은 Store가 받은 혼잡도로 지도와 시트를 함께 갱신한다. UIKit 버전은 지도(`MapBoxCrowdViewModel`)가 12곳씩 영역 색을 갱신하고, 시트는 `CrowdSnapshotStore`가 장소별 응답마다 갱신한다.
- 실패한 장소는 정보 없음(회색)으로 표시하고, 시트의 `N곳 다시 불러오기`로 다시 요청한다.
- 상세 화면은 열 때만 `citydata`를 요청한다. 상세 응답의 인구 정보는 혼잡도 캐시에도 넣는다.
- 서울 Open API는 HTTP만 제공하므로 App Info.plist의 `NSAppTransportSecurity`에 `openapi.seoul.go.kr` 예외를 둔다.
- 한 번 실행에 약 121회를 호출한다. 일 호출 한도가 있는 키라면 앱 실행 횟수에 주의하고, 한도 해제는 열린데이터광장 활용사례 등록 조건을 확인한다.

## 현재 위치 이동

`MapBoxFeatureViewController`는 기본 ViewModel을 만들 때 `MapboxPuckLocationProvider`를 주입한다. 이 제공자는 지도 위치 점과 같은 `MapView.location`의 최근 좌표와 `onLocationChange`를 사용한다. 위치 점이 뒤늦게 나타나도 진행 중인 이동 요청에 좌표가 전달되며, 별도의 Core Location 좌표 조회를 기다리지 않는다. `CoreMapboxLocationProvider`는 이 경로에서 권한 확인과 요청만 담당한다.

앱에 포함하지 않는 MapKit 화면(`MapFeature`, Demo로만 실행)은 `MapKitFeature`가 `LocationClient` 의존성으로 권한과 위치를 요청한다. `LocationClient.liveValue`가 감싼 `CoreMapLocationProvider`는 최근 좌표가 있으면 재사용하고, 없으면 `startUpdatingLocation()`으로 첫 유효한 위치를 받는다. 요청이 끝나거나 취소되면 위치 갱신을 중단한다. 일시적인 `locationUnknown`은 기존 제한 시간 안에서 다음 갱신을 기다린다.

두 제공자는 측정 후 30초가 지난 좌표를 재사용하지 않는다. 음수 정확도 같은 무효 측정은 제외하지만, 사용자가 허용한 대략적인 위치를 500m 같은 임의의 정확도 상한으로 거부하지 않는다. 카메라는 요청이 완료될 때 한 번 이동하며, 지도 위치 점이 계속 갱신된다고 카메라를 계속 따라 움직이지는 않는다.

## 앱 설정과 Bundle

`YeobaekApp` 타깃은 `Configuration.xcconfig` 값을 Info.plist의 `MBXAccessToken`과 `SeoulAPIKey`로 치환한다. 위치 사용 설명도 App 타깃의 Info.plist에 들어간다.

Feature framework 자체는 실행 Bundle이 아니다. API 키를 읽을 때는 현재 실행 중인 `YeobaekApp` 또는 Demo 앱의 Bundle 설정이 적용된다. Preview에서 키가 보이지 않으면 코드를 바꾸기 전에 활성 Scheme과 Preview 실행 호스트를 확인한다.

자세한 원리는 [Xcode Target, Scheme, Bundle, Preview 이해하기](../development/xcode-target-scheme-bundle-preview.md)에서 확인한다.

## Demo 앱의 시작 흐름

`MapFeatureDemo`, `CrowdUIKitFeatureDemo`, `FeatcherDemo`, `RxLabDemo`는 제품 앱과 별개의 실행 타깃이다. Demo Scheme을 선택하면 해당 Demo 앱이 실행 호스트가 되므로 필요한 Info.plist, xcconfig, 권한과 리소스를 Demo 타깃에도 연결해야 한다.

Demo는 Feature를 빠르게 실행하기 위한 개발 도구다. 제품 앱의 전역 상태나 다른 Feature에 의존하지 않고 대상 모듈만으로 실행되는 상태를 유지한다.

`CrowdUIKitFeatureDemo` 실행 타깃은 목업 조립을 위해 Data를 의존한다. Demo 진입점에서 App과 동일한 경계와 Repository를 주입하므로 `CrowdUIKitFeature` Scheme으로 혼잡도 폴리곤과 범례를 독립적으로 확인할 수 있다. 기본 `MapBoxSession()`은 혼잡도 주입 없이 기존 지도만 표시하므로, 목업 Preview는 App 또는 Demo 조립 코드를 사용한다.

## 아직 시작 흐름에 없는 것

- GRDB 데이터베이스 연결과 Migration 실행
- UseCase 계층
- 원격 API 클라이언트의 앱 범위 생명주기 관리
- 로그인과 사용자 세션 초기화
- 화면 전환을 담당하는 Coordinator

이 기능을 추가할 때는 `YeobaekApp`이나 `AppRootView`에서 구체 타입을 직접 만들지 않고 `AppDIContainer`에 추가한다.

## 변경 후 확인할 것

- 지도와 홈 Store가 같은 혼잡도 저장소를 공유하는가
- 목록·상세에서 돌아온 뒤 Session 상태를 유지할지 초기화할지가 명확한가
- App과 각 Demo 타깃에 필요한 xcconfig와 Info.plist 키가 연결됐는가
- 위치 권한 요청 주체와 사용자 안내가 일치하는가
- 새 전역 의존성의 생성 위치와 생명주기를 한곳에서 설명할 수 있는가

## 관련 문서

- [Yeobaek 프로젝트 아키텍처](architecture-overview.md)
- [MVVM, Clean Architecture, RxSwift 적용하기](mvvm-clean-architecture-rxswift.md)
