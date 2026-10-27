---
title: Yeobaek 프로젝트 아키텍처
description: 현재 Tuist 모듈의 책임, 실제 의존 방향, 기능을 추가할 위치를 설명한다.
---

# Yeobaek 프로젝트 아키텍처

## 이 문서에서 확인할 것

Yeobaek은 Tuist로 App, Feature, Domain, Data, Shared를 분리한 iOS 멀티 모듈 프로젝트다. 목표 아키텍처가 아니라 현재 `Project.swift`와 소스 구조를 기준으로 설명한다.

혼잡도 화면은 같은 화면을 **완전 SwiftUI 버전**(SwiftUI + TCA)과 **완전 UIKit 버전**(UIKit + RxSwift + MVVM)으로 각각 구현한다. 앱은 기본으로 SwiftUI 버전을 쓰고, 설정으로 UIKit 버전을 바꿔 끼울 수 있다. GRDB는 기술 선택만 완료되고 패키지와 마이그레이션은 아직 연결되지 않았다.

## 모듈별 책임

| 영역 | 현재 책임 | 새 코드를 둘 때 |
| --- | --- | --- |
| `Projects/App` | SwiftUI `@main` 진입점, `AppDIContainer`, 화면 구현 선택(`UIImplementation`), 앱 설정과 리소스 | 앱 전체에서 한 번만 결정하는 조립과 시작 흐름을 둔다. |
| `Projects/Features/CrowdSwiftUIFeature` | **SwiftUI 버전**: Mapbox SwiftUI 지도, 현재 위치, 홈 시트, 장소 목록, 장소 상세, `NavigationStack` 이동 | SwiftUI 버전 화면과 Reducer를 둔다. 조회는 `CrowdClient`, 위치는 `LocationClient` 의존성으로 한다. |
| `Projects/Features/MapFeature` | SwiftUI + TCA + MapKit 기반 지도 화면과 독립 실행 Demo (현재 App에는 포함하지 않음) | `MapKitFeature` Reducer, `LocationClient` 의존성, MapKit 전용 UI를 둔다. |
| `Projects/Features/CrowdUIKitFeature` | **UIKit 버전**: Mapbox `MapView` 지도 화면, 홈 시트, 장소 목록, 장소 상세, `CrowdUIKitCoordinator` 이동, UIKit Demo | UIKit 버전 화면, View·ViewModel 계약, 공유 상태(`CrowdSnapshotStore`)를 둔다. SwiftUI 타입을 두지 않는다. |
| `Projects/Domain` | 장소, 좌표, 혼잡도 같은 Entity와 Repository protocol | 외부 프레임워크를 모르는 비즈니스 모델과 규칙을 둔다. |
| `Projects/Data` | 서울 Open API 클라이언트, DTO와 응답 변환, 캐시하는 `SeoulCrowdRepository`, 121곳 장소 GeoJSON(`BundledPlaceRepository`), 예시·목업 저장소 | API나 DB의 구체 타입을 Domain Entity로 변환하는 코드를 둔다. |
| `Projects/Shared/Core` | 여러 모듈에서 쓰는 기반 코드, 앱 설정 접근, 단계 색(`CongestionPalette`), UIKit-SwiftUI 연결 도구 | 특정 기능에 종속되지 않는 공통 기반 코드를 둔다. |
| `Projects/Shared/CrowdPresentation` | 두 버전이 공유하는 혼잡도 화면 규칙: 문구(`CrowdCopy`), 접근성 식별자, 정렬·집계(`CrowdRanking`), 요약 문구, 흐름·한산한 시간 판단(`PlaceInsight`), 시트·지도 수치 | 두 버전에서 똑같아야 하는 값과 규칙을 둔다. SwiftUI·UIKit·지도 SDK를 import하지 않는다. |
| `Projects/Shared/Featcher` | 네트워크 요청 실행을 실험·공유하는 모듈과 Demo·테스트 | 범용 요청 실행과 그 검증을 둔다. 기능별 API 정책은 Data에 둔다. |
| `Projects/Shared/ThirdParty` | MapboxMaps, RxSwift, RxCocoa, RxRelay, ComposableArchitecture 패키지 연결 | 외부 패키지 제품 추가와 재노출을 관리한다. Rx 모듈만 `@_exported`로 재노출하고, MapboxMaps와 ComposableArchitecture는 사용하는 모듈에서 직접 `import`한다. |
| `Projects/Shared/RxExtension` | ViewController 생명주기와 `mapToVoid` 같은 범용 Rx 확장 | 두 개 이상의 화면에서 재사용할 Rx 확장만 둔다. |
| `Projects/Shared/RxLab` | RxSwift Input/Output MVVM 학습용 Counter와 Demo | 제품 코드에 영향을 주지 않는 Rx 실험을 둔다. |

## UI 구현 기준

- 같은 화면을 SwiftUI 버전과 UIKit 버전으로 각각 만든다. 한 Feature 안에서 SwiftUI와 UIKit을 섞지 않는다.
- SwiftUI 버전(`CrowdSwiftUIFeature`)은 지도까지 Mapbox SwiftUI `Map`으로 그리고, 화면 상태는 TCA로 관리한다. 기준은 [TCA 적용하기](tca.md)를 따른다.
- UIKit 버전(`CrowdUIKitFeature`)은 Mapbox `MapView`를 쓰고, 화면은 `ViewType`·`ViewModelType` 계약과 RxSwift Input/Output으로 연결한다. 이동은 `CrowdUIKitCoordinator`가 `UINavigationController`로 맡는다.
- 두 버전은 `CrowdPresentation`의 문구, 식별자, 규칙, 수치를 함께 쓰고, 같은 UI 테스트 시나리오를 통과해야 한다.
- 화면을 바꿀 때는 두 버전을 같은 PR에서 함께 바꾼다.

## 화면 구현 선택

- `Configuration.xcconfig`의 `UI_IMPLEMENTATION`(`swiftui` 기본, `uikit`)이 Info.plist의 `UIImplementation`으로 들어간다.
- 디버그 빌드에서는 실행 환경 변수 `UI_IMPLEMENTATION`이 빌드 설정보다 우선한다. UI 테스트가 이 값으로 두 버전을 번갈아 실행한다.
- `AppRootView`는 SwiftUI 버전이면 `CrowdHomeView`를, UIKit 버전이면 `CrowdUIKitCoordinator.navigationController` 하나를 `UIViewControllerRepresentableContainer`로 감싸 보여 준다.

## 현재 의존 방향

```text
App ── UIImplementation으로 둘 중 하나를 루트에 표시
├─ Features
│  ├─ CrowdSwiftUIFeature ─> Domain, Core, CrowdPresentation, ThirdParty (TCA, MapboxMaps)
│  └─ CrowdUIKitFeature ──> Domain, Core, CrowdPresentation, RxExtension, ThirdParty (Rx, MapboxMaps)
├─ Data ──────────────> Domain
├─ CrowdPresentation ─> Domain, Core
├─ Core ──────────────> Domain, Shared/ThirdParty
├─ Domain
└─ ThirdParty

Shared/RxExtension ──> Shared/ThirdParty
Shared/RxLab ────────> Shared/Core, Shared/ThirdParty
```

`Core`는 화면 계층의 공통 계약인 `ViewType`과 `ViewModelType`을 제공하므로 `ThirdParty`를 통해 RxSwift의 `DisposeBag`을 의존한다. `MapFeature`는 TCA를 위해 `ThirdParty`만 의존하고 `Core`는 의존하지 않는다.

핵심 원칙은 구현 계층이 추상 계층을 바라보는 것이다. `Data`는 `Domain`의 Repository protocol을 구현하고, Feature는 DTO가 아닌 Domain Entity를 사용한다. 외부 패키지는 Domain으로 전파하지 않는다.

App 타깃은 Data, Domain, Core, CrowdPresentation, ThirdParty와 두 Feature를 의존한다. 구체 타입 생성은 `AppDIContainer`가 한곳에서 담당한다. 컨테이너가 `BundledPlaceRepository`와 `SeoulCrowdRepository`를 만들고, SwiftUI 버전에는 `CrowdClient.live`로, UIKit 버전에는 `CrowdSnapshotStore`·`MapBoxCrowdViewModel`·`PlaceDetailViewModel`로 같은 저장소를 넘긴다. Feature는 Data를 직접 의존하지 않는다. `CrowdUIKitFeatureDemo`만 독립 실행 조립을 위해 Data를 의존한다.

## 화면 계층 공통 계약

- `Core`의 `ViewType`은 `UIView` 제약과 `render(_:)`를, `ViewModelType`은 `Input`, `Output`과 `transform(input:disposeBag:)`을 정의한다.
- `ViewModelType`은 `@MainActor` 프로토콜이므로 채택 타입이 격리를 물려받는다. 구현체에 `@MainActor`를 다시 붙이지 않는다.
- `transform`은 전달받은 Bag에 구독을 추가할 뿐 스스로 해제하지 않는다. ViewController 하나당 한 번만 호출한다.
- UIKit 화면은 View 구현을 `UIView`로 분리하고 ViewController는 `loadView()`에서 주입받은 화면을 설치한다. 자세한 적용 범위는 [View·ViewModel 프로토콜 패턴](view-viewmodel-protocols.md)에서 확인한다.

## 실시간 혼잡도 표시

- 장소와 경계는 서울 열린데이터광장의 `서울시 주요 121장소 영역`과 `목록` 파일을 변환한 `Projects/Data/Resources/SeoulPlaces.geojson`에서 읽는다. 분류는 공식 5개(고궁·문화유산, 공원, 관광특구, 발달상권, 인구밀집지역)다.
- 혼잡도와 12시간 예측은 `citydata_ppltn`, 상세는 `citydata`에서 받는다. `SeoulCrowdRepository`가 장소별 5분 캐시, 진행 중 요청 공유, 동시 요청 6개 제한을 맡는다.
- 단계 색은 `Core`의 `CongestionPalette` 하나로 두 버전의 지도와 화면이 함께 쓴다.
- 지도 영역은 두 버전 모두 `CrowdMapStyle` 수치(24% 채움, 2px 테두리, 확대 수준 13 이상 라벨)로 그린다. 영역을 누르면 상세 화면을 연다.
- 디자인의 "영역 안 건물만 칠하기"는 Mapbox `within` 필터가 다각형 건물에 동작하지 않아 적용하지 못했다. 건물 윤곽을 미리 잘라 둔 GeoJSON을 번들에 넣는 방식이 후속 후보다.
- 데이터 도착만으로 카메라를 이동하지 않는다.

## Framework 구성

- `CrowdSwiftUIFeature`, `MapFeature`, `CrowdUIKitFeature`는 최종 앱과 Demo 앱에서 사용하는 static framework다.
- `Domain`, `Data`, `Core`, `CrowdPresentation`, `Featcher`, `ThirdParty`, `RxExtension`, `RxLab`은 dynamic framework다.
- 실행 가능한 코드는 `YeobaekApp` 또는 각 Demo 앱이 최종적으로 연결하고 필요한 dynamic framework를 임베딩한다.
- 제품 타입을 변경할 때는 기기 실행 시 중복 심볼과 `Library not loaded` 가능성을 함께 확인한다.

자세한 선택 기준은 [Static Framework와 Dynamic Framework](static-and-dynamic-frameworks.md)에서 확인한다.

## 기능을 추가할 위치

| 변경 내용 | 기본 위치 | 함께 확인할 곳 |
| --- | --- | --- |
| 혼잡도 화면(지도·시트·목록·상세) | `CrowdSwiftUIFeature`와 `CrowdUIKitFeature` **둘 다** | 공통 문구·규칙은 `CrowdPresentation`, 두 버전 UI 테스트(`CrowdHomeUITests`) |
| 두 버전이 같아야 하는 문구·식별자·규칙·수치 | `Projects/Shared/CrowdPresentation` | `CrowdPresentationTests` |
| MapKit 화면 동작 | `Projects/Features/MapFeature` | `MapFeatureDemo`, 위치 권한 |
| 공공데이터 응답 모델 | `Projects/Data` | Domain Entity 변환, Repository 구현 |
| 앱에서 사용하는 장소·혼잡도 모델 | `Projects/Domain` | Repository protocol과 UseCase |
| 공통 앱 설정·브리지 | `Projects/Shared/Core` | Bundle 값의 실제 소유자인 실행 타깃 |
| 범용 Rx 확장 | `Projects/Shared/RxExtension` | RxCocoa UI trait와 MainActor 범위 |
| 외부 라이브러리 | `Projects/Shared/ThirdParty` | 사용하는 Feature의 직접 의존 선언 |
| 독립 기술 실험 | `Projects/Shared/RxLab` 또는 별도 Lab 모듈 | 제품 모듈이 Lab을 의존하지 않는지 확인 |

## 현재 경계에서 주의할 점

- `AppRootView`가 지도 제공자 선택과 두 Session의 생명주기를 직접 관리한다.
- Domain과 Data의 기본 경계는 마련됐지만 UseCase와 앱 조립 방식은 기능 구현에 맞춰 확장해야 한다.
- GRDB는 예정 기술이다. DB 연결, Record, Migration을 추가할 때 Data가 구현을 소유하고 Domain에는 GRDB 타입을 노출하지 않는다.
- API 키는 라이브러리 모듈의 Bundle이 아니라 현재 실행 중인 App 또는 Demo Bundle에 들어간다.
- Preview 결과는 활성 Scheme의 실행 호스트와 xcconfig 적용 여부에 따라 달라진다.

## 관련 문서

- [앱 시작 및 지도 화면 흐름](app-startup-flow.md)
- [MVVM, Clean Architecture, RxSwift 적용하기](mvvm-clean-architecture-rxswift.md)
- [Static Framework와 Dynamic Framework](static-and-dynamic-frameworks.md)
- [Xcode Target, Scheme, Bundle, Preview 이해하기](../development/xcode-target-scheme-bundle-preview.md)
