---
title: 앱 시작 및 지도 화면 흐름
description: YeobaekApp 진입부터 MapKit과 Mapbox 화면을 선택하고 세션을 유지하는 과정까지 설명한다.
---

# 앱 시작 및 지도 화면 흐름

## 이 문서에서 확인할 것

Yeobaek은 SwiftUI App 생명주기를 사용한다. `YeobaekApp`이 `AppRootView`를 만들고, 루트 화면이 지도 제공자 선택과 두 지도 Session의 생명주기를 관리한다. 앱 시작, 루트 화면, 지도 전환 또는 전역 초기화를 바꿀 때 이 흐름을 먼저 확인한다.

현재 App 진입점과 지도 전환 컨테이너는 SwiftUI지만 제품 Feature의 UI 기준과는 구분한다. `MapFeature`만 SwiftUI 화면이며, `MapBoxFeature`의 실제 화면은 UIKit + RxSwift + MVVM으로 구현한다. `MapBoxFeatureView`는 UIKit 화면을 현재 SwiftUI App 계층에 연결하는 래퍼다.

## 시작 순서

| 순서 | 실행 위치 | 동작 |
| ---: | --- | --- |
| 1 | `YeobaekApp` | `@main` 진입점으로 실행된다. |
| 2 | `WindowGroup` | 앱 윈도에 `AppRootView`를 생성한다. |
| 3 | `AppRootView` | 기본 지도 제공자를 `MapKit`으로 설정한다. |
| 4 | `AppRootView` | `MapFeatureSession`과 `MapBoxSession`을 `@State`로 생성해 화면 갱신 중에도 유지한다. |
| 5 | 지도 선택 switch | 선택값에 따라 `MapFeatureView` 또는 `MapBoxFeatureView`를 표시한다. |
| 6 | 상단 Picker | 사용자가 MapKit과 Mapbox를 바꾸면 같은 루트 안에서 표시할 Feature를 전환한다. |

```text
UIApplication
└─ YeobaekApp
   └─ WindowGroup
      └─ AppRootView
         ├─ MapProvider.mapKit ──> MapFeatureView(MapFeatureSession)
         ├─ MapProvider.mapbox ──> MapBoxFeatureView(MapBoxSession)
         └─ Segmented Picker
```

## 객체별 책임

| 객체 | 책임 | 생명주기 소유자 |
| --- | --- | --- |
| `YeobaekApp` | 앱 진입과 최초 Scene 구성 | SwiftUI App 런타임 |
| `AppRootView` | 지도 제공자 선택, Feature 전환, Session 보관 | `WindowGroup` |
| `MapFeatureSession` | MapKit 화면에서 유지해야 하는 상태와 동작 | `AppRootView`의 `@State` |
| `MapBoxSession` | Mapbox 화면에서 유지해야 하는 상태와 동작 | `AppRootView`의 `@State` |
| `MapFeatureView` | 유일한 SwiftUI Feature인 MapKit 지도 UI | `AppRootView` |
| `MapBoxFeatureView` | UIKit + RxSwift 기반 Mapbox 화면을 SwiftUI App 계층에 연결하는 래퍼 | `AppRootView` |

지도 제공자를 전환해도 두 Session 인스턴스는 `AppRootView`에 남는다. 화면 내부 상태를 전환할 때마다 새로 시작해야 한다면 Session의 소유 위치와 초기화 시점을 함께 변경해야 한다.

## 현재 위치 이동

`MapBoxFeatureViewController`는 기본 ViewModel을 만들 때 `MapboxPuckLocationProvider`를 주입한다. 이 제공자는 지도 위치 점과 같은 `MapView.location`의 최근 좌표와 `onLocationChange`를 사용한다. 위치 점이 뒤늦게 나타나도 진행 중인 이동 요청에 좌표가 전달되며, 별도의 Core Location 좌표 조회를 기다리지 않는다. `CoreMapboxLocationProvider`는 이 경로에서 권한 확인과 요청만 담당한다.

MapKit의 `CoreMapLocationProvider`는 최근 좌표가 있으면 재사용하고, 없으면 `startUpdatingLocation()`으로 첫 유효한 위치를 받는다. 요청이 끝나거나 취소되면 위치 갱신을 중단한다. 일시적인 `locationUnknown`은 기존 제한 시간 안에서 다음 갱신을 기다린다.

두 제공자는 측정 후 30초가 지난 좌표를 재사용하지 않는다. 음수 정확도 같은 무효 측정은 제외하지만, 사용자가 허용한 대략적인 위치를 500m 같은 임의의 정확도 상한으로 거부하지 않는다. 카메라는 요청이 완료될 때 한 번 이동하며, 지도 위치 점이 계속 갱신된다고 카메라를 계속 따라 움직이지는 않는다.

## 앱 설정과 Bundle

`YeobaekApp` 타깃은 `Configuration.xcconfig` 값을 Info.plist의 `MBXAccessToken`과 `SeoulAPIKey`로 치환한다. 위치 사용 설명도 App 타깃의 Info.plist에 들어간다.

Feature framework 자체는 실행 Bundle이 아니다. API 키를 읽을 때는 현재 실행 중인 `YeobaekApp` 또는 Demo 앱의 Bundle 설정이 적용된다. Preview에서 키가 보이지 않으면 코드를 바꾸기 전에 활성 Scheme과 Preview 실행 호스트를 확인한다.

자세한 원리는 [Xcode Target, Scheme, Bundle, Preview 이해하기](../development/xcode-target-scheme-bundle-preview.md)에서 확인한다.

## Demo 앱의 시작 흐름

`MapFeatureDemo`, `MapBoxFeatureDemo`, `FeatcherDemo`, `RxLabDemo`는 제품 앱과 별개의 실행 타깃이다. Demo Scheme을 선택하면 해당 Demo 앱이 실행 호스트가 되므로 필요한 Info.plist, xcconfig, 권한과 리소스를 Demo 타깃에도 연결해야 한다.

Demo는 Feature를 빠르게 실행하기 위한 개발 도구다. 제품 앱의 전역 상태나 다른 Feature에 의존하지 않고 대상 모듈만으로 실행되는 상태를 유지한다.

## 아직 시작 흐름에 없는 것

- GRDB 데이터베이스 연결과 Migration 실행
- Repository 구현과 UseCase를 조립하는 App DI Container
- 원격 API 클라이언트의 앱 범위 생명주기 관리
- 로그인과 사용자 세션 초기화

이 기능을 추가할 때는 `YeobaekApp` 또는 `AppRootView`에서 구체 타입을 계속 직접 만들기보다 App 조립 전용 객체를 두는 방식을 먼저 검토한다.

## 변경 후 확인할 것

- 기본 지도 제공자가 의도한 값인가
- 지도 전환 후 Session 상태를 유지할지 초기화할지가 명확한가
- App과 각 Demo 타깃에 필요한 xcconfig와 Info.plist 키가 연결됐는가
- 위치 권한 요청 주체와 사용자 안내가 일치하는가
- 새 전역 의존성의 생성 위치와 생명주기를 한곳에서 설명할 수 있는가

## 관련 문서

- [Yeobaek 프로젝트 아키텍처](architecture-overview.md)
- [MVVM, Clean Architecture, RxSwift 적용하기](mvvm-clean-architecture-rxswift.md)
