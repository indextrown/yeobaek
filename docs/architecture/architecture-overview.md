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
| `Projects/Features/MapFeature` | SwiftUI + MapKit 기반 지도 화면과 독립 실행 Demo | 프로젝트에서 유일하게 SwiftUI로 구현하는 Feature이며 MapKit 전용 UI와 지도 상호작용을 둔다. |
| `Projects/Features/MapBoxFeature` | UIKit + RxSwift + MVVM 기반 Mapbox 화면, 목업 혼잡도 폴리곤과 범례, App 연결용 SwiftUI 래퍼, 독립 실행 Demo | 위치 조회와 혼잡도 조회를 분리하고 Domain 경계를 Mapbox 표현으로 변환한다. |
| `Projects/Domain` | 장소, 좌표, 혼잡도 같은 Entity와 Repository protocol | 외부 프레임워크를 모르는 비즈니스 모델과 규칙을 둔다. |
| `Projects/Data` | DTO, 응답 변환, Repository 구현, 테스트용 장소 경계와 혼잡도 목업 | API나 DB의 구체 타입을 Domain Entity로 변환하는 코드를 둔다. |
| `Projects/Shared/Core` | 여러 모듈에서 쓰는 기반 코드, 앱 설정 접근, UIKit-SwiftUI 연결 도구 | 특정 기능에 종속되지 않는 공통 기반 코드를 둔다. |
| `Projects/Shared/Featcher` | 네트워크 요청 실행을 실험·공유하는 모듈과 Demo·테스트 | 범용 요청 실행과 그 검증을 둔다. 기능별 API 정책은 Data에 둔다. |
| `Projects/Shared/ThirdParty` | MapboxMaps, RxSwift, RxCocoa, RxRelay 패키지 연결 | 외부 패키지 제품 추가와 재노출을 관리한다. |
| `Projects/Shared/RxExtension` | ViewController 생명주기와 `mapToVoid` 같은 범용 Rx 확장 | 두 개 이상의 화면에서 재사용할 Rx 확장만 둔다. |
| `Projects/Shared/RxLab` | RxSwift Input/Output MVVM 학습용 Counter와 Demo | 제품 코드에 영향을 주지 않는 Rx 실험을 둔다. |

## UI 구현 기준

- `MapBoxFeature`의 실제 화면은 UIKit ViewController로 구현하고 RxSwift와 RxCocoa로 ViewModel Input/Output을 연결한다.
- `MapFeature`는 프로젝트에서 유일하게 SwiftUI로 구현하는 Feature다.
- `MapBoxFeatureView` 같은 SwiftUI 타입은 UIKit 화면을 현재 App 진입점이나 Preview에 연결하는 어댑터다. Mapbox 화면의 주 UI 기술을 SwiftUI로 판단하지 않는다.
- 새로운 제품 Feature는 별도 결정이 없다면 UIKit + RxSwift + MVVM을 기본으로 한다.

## 현재 의존 방향

```text
App
├─ Features
│  ├─ MapFeature
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

현재 App 타깃은 Data, Domain, Core, ThirdParty와 두 지도 Feature를 직접 의존한다. 구체 타입 생성은 `AppDIContainer`가 한곳에서 담당하며, `AppRootView`는 컨테이너에서 Session과 화면만 전달받는다. `MockCrowdRepository`를 실제 API 구현으로 바꿀 때 컨테이너의 Repository 프로퍼티만 교체하면 된다. Demo 실행 타깃만 Data를 추가로 의존하며, MapBoxFeature framework는 Data를 직접 의존하지 않는다.

## 화면 계층 공통 계약

- `Core`의 `ViewType`은 `UIView` 제약과 `render(_:)`를, `ViewModelType`은 `Input`, `Output`과 `transform(input:disposeBag:)`을 정의한다.
- `ViewModelType`은 `@MainActor` 프로토콜이므로 채택 타입이 격리를 물려받는다. 구현체에 `@MainActor`를 다시 붙이지 않는다.
- `transform`은 전달받은 Bag에 구독을 추가할 뿐 스스로 해제하지 않는다. ViewController 하나당 한 번만 호출한다.
- UIKit 화면은 View 구현을 `UIView`로 분리하고 ViewController는 `loadView()`에서 주입받은 화면을 설치한다. 자세한 적용 범위는 [View·ViewModel 프로토콜 패턴](view-viewmodel-protocols.md)에서 확인한다.

## 목업 혼잡도 표시

- `MapBoxCrowdViewModel`은 `CrowdRepository`로 장소별 정보를 조회하고 `placeID`로 `AreaGeometry`와 연결한다. 위치 요청 ViewModel과 별도의 Input/Output을 사용한다.
- `MapBoxCrowdRenderer`는 다중 폴리곤과 내부 빈 영역을 보존하고 반투명 채움과 독립된 테두리를 그린다. 조회 실패나 정보 없음은 회색으로 표시한다.
- `CrowdMockData`의 다섯 영역은 서울 도심에 임의로 배치한 테스트용 경계다. 공식 영역이 아니며 `MOCK` 장소 코드는 실제 API 요청에 사용하지 않는다.
- 목업 안내와 다섯 단계 범례를 항상 표시한다. 데이터 도착만으로 카메라를 이동하지 않으며, 사용자가 `목업 지역 보기` 버튼을 누르면 전체 영역을 보여준다.
- 혼잡도는 현재 Mapbox에만 연결됐다. MapKit 폴리곤, 장소 선택 카드, 실제 서울시 API, 최신성 정책과 GRDB는 후속 작업이다.

## Framework 구성

- `MapFeature`와 `MapBoxFeature`는 최종 앱과 Demo 앱에서 사용하는 static framework다.
- `Domain`, `Data`, `Core`, `Featcher`, `ThirdParty`, `RxExtension`, `RxLab`은 dynamic framework다.
- 실행 가능한 코드는 `YeobaekApp` 또는 각 Demo 앱이 최종적으로 연결하고 필요한 dynamic framework를 임베딩한다.
- 제품 타입을 변경할 때는 기기 실행 시 중복 심볼과 `Library not loaded` 가능성을 함께 확인한다.

자세한 선택 기준은 [Static Framework와 Dynamic Framework](static-and-dynamic-frameworks.md)에서 확인한다.

## 기능을 추가할 위치

| 변경 내용 | 기본 위치 | 함께 확인할 곳 |
| --- | --- | --- |
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
