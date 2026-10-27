---
title: Yeobaek 프로젝트 아키텍처
description: 현재 Tuist 모듈의 책임, 실제 의존 방향, 기능을 추가할 위치를 설명한다.
---

# Yeobaek 프로젝트 아키텍처

## 이 문서에서 확인할 것

Yeobaek은 Tuist로 App, Feature, Domain, Data, Shared를 분리한 iOS 멀티 모듈 프로젝트다. 목표 아키텍처가 아니라 현재 `Project.swift`와 소스 구조를 기준으로 설명한다.

아키텍처 방향은 MVVM, Clean Architecture, RxSwift 조합이다. 다만 모든 계층이 완성된 상태는 아니다. 앱은 현재 두 지도 Feature와 세션을 직접 조립하고 있으며, GRDB는 기술 선택만 완료되고 패키지와 마이그레이션은 아직 연결되지 않았다.

## 모듈별 책임

| 영역 | 현재 책임 | 새 코드를 둘 때 |
| --- | --- | --- |
| `Projects/App` | `@main` 진입점, 루트 화면, 지도 제공자 전환, 앱 설정과 리소스 | 앱 전체에서 한 번만 결정하는 조립과 시작 흐름을 둔다. |
| `Projects/Features/CrowdFeature` | SwiftUI + TCA 기반 혼잡도 홈 시트, 장소 목록, 장소 상세 | 지도 위 요약과 정보 화면을 둔다. 지도는 App이 `CrowdHomeView`에 주입하고, 조회는 `CrowdClient` 의존성으로 한다. |
| `Projects/Features/MapFeature` | SwiftUI + TCA + MapKit 기반 지도 화면과 독립 실행 Demo (현재 App에는 포함하지 않음) | 프로젝트에서 유일하게 SwiftUI + TCA로 구현하는 Feature이며 `MapKitFeature` Reducer, `LocationClient` 의존성, MapKit 전용 UI를 둔다. |
| `Projects/Features/MapBoxFeature` | UIKit + RxSwift + MVVM 기반 Mapbox 바탕 지도, 121곳 혼잡도 영역·라벨·탭, App 연결용 SwiftUI 래퍼, 독립 실행 Demo | 위치 조회와 혼잡도 조회를 분리하고 Domain 경계를 Mapbox 표현으로 변환한다. |
| `Projects/Domain` | 장소, 좌표, 혼잡도 같은 Entity와 Repository protocol | 외부 프레임워크를 모르는 비즈니스 모델과 규칙을 둔다. |
| `Projects/Data` | 서울 Open API 클라이언트, DTO와 응답 변환, 캐시하는 `SeoulCrowdRepository`, 121곳 장소 GeoJSON(`BundledPlaceRepository`), 예시·목업 저장소 | API나 DB의 구체 타입을 Domain Entity로 변환하는 코드를 둔다. |
| `Projects/Shared/Core` | 여러 모듈에서 쓰는 기반 코드, 앱 설정 접근, UIKit-SwiftUI 연결 도구 | 특정 기능에 종속되지 않는 공통 기반 코드를 둔다. |
| `Projects/Shared/Featcher` | 네트워크 요청 실행을 실험·공유하는 모듈과 Demo·테스트 | 범용 요청 실행과 그 검증을 둔다. 기능별 API 정책은 Data에 둔다. |
| `Projects/Shared/ThirdParty` | MapboxMaps, RxSwift, RxCocoa, RxRelay, ComposableArchitecture 패키지 연결 | 외부 패키지 제품 추가와 재노출을 관리한다. Rx 모듈만 `@_exported`로 재노출하고, MapboxMaps와 ComposableArchitecture는 사용하는 모듈에서 직접 `import`한다. |
| `Projects/Shared/RxExtension` | ViewController 생명주기와 `mapToVoid` 같은 범용 Rx 확장 | 두 개 이상의 화면에서 재사용할 Rx 확장만 둔다. |
| `Projects/Shared/RxLab` | RxSwift Input/Output MVVM 학습용 Counter와 Demo | 제품 코드에 영향을 주지 않는 Rx 실험을 둔다. |

## UI 구현 기준

- `MapBoxFeature`의 실제 화면은 UIKit ViewController로 구현하고 RxSwift와 RxCocoa로 ViewModel Input/Output을 연결한다.
- `CrowdFeature`와 `MapFeature`는 SwiftUI + TCA로 구현한다. 기준은 [TCA 적용하기](tca.md)를 따른다.
- 지도 홈은 Mapbox(UIKit) 위에 CrowdFeature(SwiftUI) 시트를 겹친다. 두 화면은 App이 조립하고 서로 직접 의존하지 않는다.
- `MapBoxFeatureView` 같은 SwiftUI 타입은 UIKit 화면을 현재 App 진입점이나 Preview에 연결하는 어댑터다. Mapbox 화면의 주 UI 기술을 SwiftUI로 판단하지 않는다.
- 새로운 제품 Feature는 별도 결정이 없다면 UIKit + RxSwift + MVVM을 기본으로 한다.

## 현재 의존 방향

```text
App
├─ Features
│  ├─ CrowdFeature ─> Domain, Core, Shared/ThirdParty (ComposableArchitecture)
│  └─ MapBoxFeature ──> Domain, 필요한 Shared 모듈
├─ Data ──────────────> Domain
├─ Core ──────────────> Domain, Shared/ThirdParty
├─ Domain
└─ ThirdParty

Shared/RxExtension ──> Shared/ThirdParty
Shared/RxLab ────────> Shared/Core, Shared/ThirdParty
```

`Core`는 화면 계층의 공통 계약인 `ViewType`과 `ViewModelType`을 제공하므로 `ThirdParty`를 통해 RxSwift의 `DisposeBag`을 의존한다. `MapFeature`는 의존성이 없는 SwiftUI 모듈이라 이 의존이 전파되지 않는다.

핵심 원칙은 구현 계층이 추상 계층을 바라보는 것이다. `Data`는 `Domain`의 Repository protocol을 구현하고, Feature는 DTO가 아닌 Domain Entity를 사용한다. 외부 패키지는 Domain으로 전파하지 않는다.

현재 App 타깃은 Data, Domain, Core, ThirdParty, MapBoxFeature, CrowdFeature를 의존한다. 구체 타입 생성은 `AppDIContainer`가 한곳에서 담당한다. 컨테이너가 `BundledPlaceRepository`와 `SeoulCrowdRepository`를 만들고, 같은 저장소를 `CrowdClient`(TCA)와 `MapBoxCrowdViewModel`(Rx)에 함께 넘긴다. `AppRootView`는 컨테이너에서 Store, Session과 화면만 전달받는다. Feature는 Data를 직접 의존하지 않는다. `MapBoxFeatureDemo`만 목업 조립을 위해 Data를 의존한다.

## 화면 계층 공통 계약

- `Core`의 `ViewType`은 `UIView` 제약과 `render(_:)`를, `ViewModelType`은 `Input`, `Output`과 `transform(input:disposeBag:)`을 정의한다.
- `ViewModelType`은 `@MainActor` 프로토콜이므로 채택 타입이 격리를 물려받는다. 구현체에 `@MainActor`를 다시 붙이지 않는다.
- `transform`은 전달받은 Bag에 구독을 추가할 뿐 스스로 해제하지 않는다. ViewController 하나당 한 번만 호출한다.
- UIKit 화면은 View 구현을 `UIView`로 분리하고 ViewController는 `loadView()`에서 주입받은 화면을 설치한다. 자세한 적용 범위는 [View·ViewModel 프로토콜 패턴](view-viewmodel-protocols.md)에서 확인한다.

## 실시간 혼잡도 표시

- 장소와 경계는 서울 열린데이터광장의 `서울시 주요 121장소 영역`과 `목록` 파일을 변환한 `Projects/Data/Resources/SeoulPlaces.geojson`에서 읽는다. 분류는 공식 5개(고궁·문화유산, 공원, 관광특구, 발달상권, 인구밀집지역)다.
- 혼잡도와 12시간 예측은 `citydata_ppltn`, 상세는 `citydata`에서 받는다. `SeoulCrowdRepository`가 장소별 5분 캐시, 진행 중 요청 공유, 동시 요청 6개 제한을 맡는다.
- 단계 색은 `Core`의 `CongestionPalette` 하나로 지도와 SwiftUI 화면이 함께 쓴다.
- 지도 영역은 24% 채움과 2px 테두리로 그리고, 확대 수준 13 이상에서만 장소 이름 라벨을 표시한다. 영역을 누르면 상세 화면을 연다.
- 디자인의 "영역 안 건물만 칠하기"는 Mapbox `within` 필터가 다각형 건물에 동작하지 않아 적용하지 못했다. 건물 윤곽을 미리 잘라 둔 GeoJSON을 번들에 넣는 방식이 후속 후보다.
- 데이터 도착만으로 카메라를 이동하지 않는다.

## Framework 구성

- `CrowdFeature`, `MapFeature`, `MapBoxFeature`는 최종 앱과 Demo 앱에서 사용하는 static framework다.
- `Domain`, `Data`, `Core`, `Featcher`, `ThirdParty`, `RxExtension`, `RxLab`은 dynamic framework다.
- 실행 가능한 코드는 `YeobaekApp` 또는 각 Demo 앱이 최종적으로 연결하고 필요한 dynamic framework를 임베딩한다.
- 제품 타입을 변경할 때는 기기 실행 시 중복 심볼과 `Library not loaded` 가능성을 함께 확인한다.

자세한 선택 기준은 [Static Framework와 Dynamic Framework](static-and-dynamic-frameworks.md)에서 확인한다.

## 기능을 추가할 위치

| 변경 내용 | 기본 위치 | 함께 확인할 곳 |
| --- | --- | --- |
| 홈 시트·목록·상세 | `Projects/Features/CrowdFeature` | `CrowdClient`, TestStore 테스트 |
| MapKit 화면 동작 | `Projects/Features/MapFeature` | `MapFeatureDemo`, 위치 권한 |
| Mapbox 화면 동작 | `Projects/Features/MapBoxFeature` | ViewModel Input/Output, `MapBoxSession`, `MapBoxFeatureDemo` |
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
