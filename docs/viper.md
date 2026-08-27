---
title: "VIPER 아키텍처 이해와 여백 앱 적용"
description: "VIPER의 구성 요소와 데이터 흐름, 장단점을 살펴보고 여백의 SwiftUI 앱에 적용하는 방향을 정리해요."
---

# VIPER 아키텍처 이해와 여백 앱 적용

## 개요

여백의 지도 화면에는 혼잡도 조회, 실시간 갱신, 로컬 저장, 장소 상세 이동이 함께 들어가요. 이 일을 화면 코드 한곳에 모으면 데이터 처리 규칙을 바꿀 때 지도와 화면 전환까지 확인해야 해요. 이 문서는 각 책임을 어디에 둘지 판단하는 기준을 제안해요.

Swift의 타입과 프로토콜, SwiftUI의 기본 상태 관리를 아는 개발자를 위한 **설명 문서**예요. 설치 방법보다 VIPER의 역할 분리와 설계 이유에 집중해요. 읽고 나면 혼잡도 기능의 책임을 나누고, 화면 없이 검증할 테스트를 정할 수 있어요.

- 자료 확인일: 2026-08-28
- 프로젝트 상태: 기획 및 API 검토 단계
- 문서 범위: VIPER의 원리, 자료별 차이, SwiftUI 적용안, 테스트 기준
- 구현 상태: 아래 모듈명과 인터페이스는 제안이며, 앱에 구현된 코드는 아니에요.

## VIPER는 무엇을 나누나요?

VIPER는 View, Interactor, Presenter, Entity, Routing의 약자예요. Jeff Gilbert와 Conrad Stoll은 2014년 objc.io 글에서 iOS 앱에 Clean Architecture를 적용하는 접근법으로 소개했어요. 화면 컨트롤러에 쏠린 책임을 나누고 테스트하기 쉽게 만드는 것이 출발점이에요. Apple이 배포하는 프레임워크가 아니라 앱을 설계하는 방식이에요. [VIPER 원전](https://www.objc.io/issues/13-architecture/viper/)

| 구성 요소 | 기본 책임 | 여백에 적용할 예 |
| --- | --- | --- |
| View | 화면 표시와 사용자 입력 전달 | Mapbox 지도, 혼잡도 범례, 장소 선택 이벤트 |
| Interactor | 유스케이스의 비즈니스 규칙 실행 | 조회할 장소 결정, 데이터 최신성 판단 |
| Presenter | 입력에 반응하고 결과를 표시용 데이터로 변환 | 로딩·오류 상태, 혼잡도 문구, 기준 시각 표시 |
| Entity | Interactor가 다루는 기본 모델 | 장소 식별자와 혼잡도 관측값 |
| Router | 화면 전환 수행 | 장소 식별자로 상세 화면 열기 |

기본 책임은 원전을 요약했고, 마지막 열은 여백을 위한 제안이에요. 원전의 R은 **Routing**이며 구현 예에서는 **Wireframe**이라는 이름을 사용해요. Presenter가 이동 시점과 목적지를 판단하고, Wireframe이 실제 전환을 수행해요. [원전의 구성 요소와 Routing 설명](https://www.objc.io/issues/13-architecture/viper/)

유스케이스는 사용자가 앱에서 이루려는 작업이에요. 여백에서는 “선택한 지역의 혼잡도를 확인한다”를 하나의 유스케이스로 볼 수 있어요.

원전은 Entity를 Presenter에 그대로 넘기지 않고, 동작이 없는 결과 데이터로 바꾸는 방식을 설명해요. 또한 네트워크와 저장소 구현은 Interactor의 협력 객체로 분리해요. [원전의 Entity·데이터 계층 설명](https://www.objc.io/issues/13-architecture/viper/)

## 자료마다 구현이 다른 이유

조사한 자료는 같은 역할 이름을 사용해도 호출 방향과 상태 관리 방식이 달라요. 문서의 날짜와 적용 환경을 함께 봐야 해요.

| 자료 | 확인할 내용 | 읽을 때 주의할 점 |
| --- | --- | --- |
| [objc.io VIPER 원전](https://www.objc.io/issues/13-architecture/viper/) | 제안자들이 설명한 역할과 책임 | 2014년 UIKit·Objective-C 예제예요. |
| [원전의 공개 예제 저장소](https://github.com/objcio/issue-13-viper) | 실제 객체 연결과 테스트 구성 | 최신 SwiftUI 프로젝트 템플릿으로 보지 않아요. |
| [The Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) | Robert C. Martin이 설명한 의존성 방향 | VIPER의 파일 구조를 정해 주는 문서는 아니에요. |
| [DoorDash의 SwiftUI 도입 사례](https://careersatdoordash.com/blog/adopting-swiftui-with-a-bottom-up-approach-to-minimize-risk/) | 기존 VIP 계열 모듈에 SwiftUI를 넣은 경험 | 2022년의 점진적 전환 사례예요. 여백과 출발점이 달라요. |
| [Apple의 모델 데이터 관리](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)와 [화면 전환 문서](https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack) | SwiftUI가 상태와 경로를 화면에 반영하는 방식 | SwiftUI API의 공식 설명이지, VIPER 공식 규약은 아니에요. |

DoorDash는 View에서 Interactor로 요청하고 Presenter를 거쳐 View로 결과를 돌려주는 흐름을 소개해요. SwiftUI 연결에는 State, ViewModel, ViewState를 추가했어요. 원전의 Presenter 중심 입력 흐름과 다른 변형이에요. 이 사례는 VIPER와 SwiftUI를 함께 사용할 수 있다는 근거지만, 모든 프로젝트에 같은 중간 객체가 필요하다는 뜻은 아니에요. [DoorDash의 Reactive VIP 설명](https://careersatdoordash.com/blog/adopting-swiftui-with-a-bottom-up-approach-to-minimize-risk/)

**여백에서는 사용자 이벤트를 Presenter가 받고, Interactor가 조회·판단을 맡는 흐름을 제안해요.** 별도의 ViewModel은 처음부터 추가하지 않아요. Presenter와 같은 화면 상태를 두 군데에서 관리하지 않기 위해서예요. 이는 조사 결과를 바탕으로 한 프로젝트 설계안이며, 원전의 SwiftUI 구현을 옮긴 것이 아니에요.

## 여백의 기술 스택은 어디에 두나요?

### SDK와 비즈니스 규칙을 분리해요

Clean Architecture의 의존성 규칙은 바깥의 구현 세부사항이 안쪽의 정책을 따르도록 해요. 실행 중 데이터가 오가는 방향과 소스 코드의 의존 방향은 같지 않을 수 있어요. 인터페이스를 안쪽에 두고 바깥 구현이 이를 따르게 만들면, 유스케이스가 저장소의 구체 타입을 몰라도 데이터를 요청할 수 있어요. [의존성 규칙과 경계 통과](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

여백에는 다음과 같이 적용하는 안을 제안해요.

| 기술·객체 | 배치할 위치 | 지킬 경계 |
| --- | --- | --- |
| SwiftUI·Mapbox | View와 지도 표시 어댑터 | Mapbox 타입을 Interactor의 입력·출력으로 사용하지 않아요. |
| 혼잡도 유스케이스 | Interactor | SDK 대신 저장소 프로토콜에 의존해요. |
| Realm | 로컬 데이터 소스 | Realm 객체를 도메인 값으로 변환해서 내보내요. |
| HTTP·WebSocket 클라이언트 | 원격 데이터 소스 | 연결·해석·전송 오류를 처리하고 UI 상태는 직접 바꾸지 않아요. |
| Repository | 데이터 계층의 조정 객체 | 원격 데이터와 로컬 캐시를 결합해 Interactor에 제공해요. |
| FastAPI | 별도 백엔드 서비스 | 공공 API 수집과 앱용 응답·갱신 메시지를 담당해요. iOS VIPER의 구성 요소는 아니에요. |

여기서 Repository는 앱이 데이터를 얻는 경로를 감추는 인터페이스와 구현을 뜻해요. 저장 방식은 Repository와 데이터 소스가 맡고, 어떤 데이터를 사용자에게 유효한 정보로 볼지는 Interactor가 판단하도록 나눠요.

혼잡도 등급은 제공 기관의 값을 우선 보존해요. 앱에서 임의의 인구 기준으로 새 등급을 만들지 않아요. 색상과 문구는 표시 계층에서 결정하고, 기준 시각에 따른 오래된 데이터 판정은 유스케이스 정책으로 분리하는 안이에요. API별 등급과 지연 조건은 [실시간 혼잡도 API 조사](실시간-혼잡도-API-조사.md)를 참고하세요.

### 데이터 모델을 역할별로 구분해요

아래 타입은 여백에서 사용할 이름의 예예요.

- `CongestionResponseDTO`: 백엔드 응답을 해석하는 데이터 전송 객체예요. 서버 필드명 변경을 이 경계에서 처리해요.
- `CongestionEntity`: 장소와 관측값을 표현하는 도메인 모델이에요. Realm·Mapbox 타입을 포함하지 않아요.
- `CongestionResult`: Interactor가 Presenter에 전달하는 결과예요. 표시 문구 대신 등급·시각·유효성 같은 값을 담아요.
- `CongestionMapState`: Presenter가 만드는 화면 상태예요. 범례, 안내 문구, 로딩 상태를 담아요.

필드가 겹치더라도 각각 서버 계약, 앱 규칙, 유스케이스 결과, 화면 표현이라는 다른 변경 이유를 가져요. 다만 값 하나를 전달하는 데 의미 없는 래퍼를 계속 추가하지는 않아요.

## 지도 화면은 어떻게 동작하나요?

다음은 초기 조회와 실시간 갱신을 하나의 화면 상태로 합치는 제안이에요.

1. View가 화면 진입이나 조회 영역 변경을 Presenter에 전달해요.
2. Presenter가 로딩 상태를 만들고 Interactor에 조회를 요청해요.
3. Interactor가 Repository를 통해 캐시와 원격 데이터를 받아 최신성을 판단해요.
4. Interactor가 결과 값을 반환하면 Presenter가 지도 표시 상태로 변환해요.
5. View가 상태를 관찰해 지도와 기준 시각을 갱신해요.
6. WebSocket으로 받은 갱신도 데이터 계층과 Interactor를 거쳐 같은 상태 갱신 경로에 합쳐요.
7. 사용자가 장소를 선택하면 Presenter가 Router에 장소 식별자를 전달해 상세 화면을 열어요.

### 실시간 연결과 데이터 최신성은 달라요

WebSocket 연결이 살아 있다는 사실만으로 혼잡도 값이 최신인 것은 아니에요. 원천 데이터의 기준 시각과 앱의 수신 시각을 따로 보존하는 안을 제안해요. 구체적인 데이터 생성 주기와 지연은 [API 조사 문서](실시간-혼잡도-API-조사.md)에 정리했어요.

첫 구현에서 아래 규칙을 명시해야 해요.

- **초기 조회와 스트림의 순서:** 구독 전에 발생한 변경이 빠지지 않도록 스냅샷과 스트림을 연결할 기준을 정해요. 서버의 재생 기능이 없다면 구독 후 재조회하는 방식도 검토해요.
- **중복·역순 데이터:** 서버와 합의한 리비전이나 기준 시각으로 비교해요. 늦게 도착한 과거 응답이 최신 상태를 덮어쓰지 않게 해요.
- **연결 종료:** 마지막 정상 데이터는 유지하되, 연결 상태와 데이터 기준 시각을 따로 표시해요.
- **연결 복구:** 재조회로 누락된 변경을 보완해요. 재연결만으로 과거 메시지가 복구된다고 가정하지 않아요.
- **캐시 실패:** 원격 조회 성공과 로컬 저장 성공을 구분해요. 캐시 저장 실패 때문에 정상 수신한 지도까지 지우지 않아요.

리비전 필드, 캐시 만료 기준, 재연결 간격은 아직 확정하지 않았어요. 이 문서는 백엔드에 해당 기능이 이미 있다고 가정하지 않아요.

## SwiftUI에서는 무엇을 조정하나요?

### Presenter의 상태를 View가 관찰해요

Apple은 관찰 가능한 모델의 변경에 따라 SwiftUI가 화면을 갱신하는 방식을 설명해요. SwiftUI의 Observation 지원은 iOS 17부터 제공돼요. [모델 데이터 관리](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)

여백의 최소 지원 OS는 아직 정하지 않았어요. iOS 17 이상으로 정하면 `@Observable` Presenter와 이를 소유하는 View의 `@State` 조합을 검토해요. 이전 OS를 포함하면 `ObservableObject`·`@Published`와 소유 View의 `@StateObject` 방식을 검토해요. 둘은 객체 소유와 관찰 방식이 다르므로 프로퍼티 래퍼를 기계적으로 바꾸지 않아요. [Apple의 Observation 전환 가이드](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)

제안하는 책임은 같아요. Presenter는 화면 상태를 만들고 View는 표시해요. 지도 확대 수준처럼 View 안에서 끝나는 상태는 로컬에 둘 수 있어요. 조회 영역을 바꾸는 입력은 Presenter에 전달해요. View의 `body` 평가 때마다 모듈이나 연결을 다시 만들지 않도록 소유 지점을 정해요.

### Router는 화면 경로를 관리해요

SwiftUI의 `NavigationStack`은 경로를 데이터로 관리할 수 있어요. Apple은 경로에 무거운 모델 전체보다 가벼운 값을 사용하도록 안내해요. [NavigationStack의 상태 관리](https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack)

여백의 Router는 장소 식별자를 담은 경로 값을 관리하고, View가 경로에 맞는 목적지를 표시하도록 제안해요. Realm 객체나 현재 지도 객체를 경로에 넣지 않아요. 화면 생성은 Builder가 맡게 해서 Router에 모든 생성 로직이 쌓이지 않도록 해요. Builder는 의존 객체를 조립하는 보조 객체이지 VIPER의 여섯 번째 필수 계층은 아니에요.

### 상태 변경과 작업 수명을 명시해요

Presenter와 Router의 UI 상태 변경에는 `@MainActor`를 적용하는 안이에요. 네트워크 응답 해석과 저장 작업은 별도 데이터 계층에서 수행하도록 설계해요. `@MainActor`는 메인 디스패치 큐에 대응하는 실행자를 사용해요. [MainActor 공식 문서](https://developer.apple.com/documentation/swift/mainactor)

계층을 나누는 것과 실행 컨텍스트를 나누는 것은 별개예요. 무거운 처리가 메인 액터를 막지 않는지도 확인해야 해요.

화면이 필요로 하는 구독과 앱 전체의 소켓 연결은 수명을 구분해요. 화면을 닫으면 그 화면의 소비 작업을 취소하고, 공유 연결을 닫을지는 연결 소유자가 결정해요. Swift의 취소는 협력적이므로 `cancel()` 호출만으로 모든 수신 루프와 연결이 정리된다고 가정하지 않아요. 취소 확인과 자원 해제 경로를 구현해야 해요. [Swift의 작업 취소](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

## 인터페이스로 경계를 표현하는 예

아래 코드는 책임 경계를 보여 주는 **Swift 선언 예제**예요. 완성된 지도 화면이나 실제 API 스키마는 아니에요. Foundation만 사용하며 SDK 버전이나 최소 지원 iOS를 확정하지 않아요.

```swift
import Foundation

struct PlaceID: Hashable, Sendable {
    let rawValue: String
}

enum CongestionLevel: Sendable {
    case relaxed, normal, slightlyBusy, busy, unknown
}

// Interactor가 반환하는 결과이며, DB 객체나 View 상태가 아니에요.
struct CongestionResult: Sendable {
    let placeID: PlaceID
    let level: CongestionLevel
    let observedAt: Date
    let isStale: Bool
}

protocol CongestionMapInteracting: Sendable {
    func load(placeIDs: [PlaceID]) async throws -> [CongestionResult]
}

@MainActor
protocol CongestionMapRouting: AnyObject {
    func showPlaceDetail(placeID: PlaceID)
}
```

Presenter에는 `CongestionMapInteracting`과 `CongestionMapRouting` 구현을 주입해요. 테스트에서는 가짜 구현으로 바꿔서 실제 서버나 지도 없이 결과를 확인할 수 있어요. `unknown`은 예상하지 못한 등급을 처리하기 위한 앱 내부 값이며, 제공 기관의 공식 혼잡도 등급은 아니에요.

이 예제는 단발 조회 계약만 보여 줘요. 스트림 인터페이스는 오류 전달, 구독 해제, 재구독 규칙을 정한 뒤 추가해요. `Sendable`을 선언했다고 모든 구현이 자동으로 안전해지는 것은 아니므로 공유 상태와 격리는 구현에서 검증해야 해요.

## 모듈은 어떻게 나누나요?

여백의 첫 구현은 지도 조회와 장소 상세라는 기능 경계를 기준으로 나누는 안이에요. 모든 버튼이나 작은 하위 View마다 VIPER 모듈을 만들지는 않아요. 아래 경로는 아직 생성하지 않은 구조 예예요.

```text
Features/
  CongestionMap/
    CongestionMapView.swift
    CongestionMapPresenter.swift
    CongestionMapInteractor.swift
    CongestionMapRouter.swift
    CongestionMapBuilder.swift
    CongestionMapState.swift
  PlaceDetail/
Domain/
  Entities/
  Repositories/     # 저장소 프로토콜
Data/
  Repositories/     # 프로토콜 구현
  Remote/           # HTTP·WebSocket
  Local/            # Realm
```

한 기능을 고칠 때 파일 위치를 예측할 수 있도록 기능별로 묶어요. 공통 Entity와 저장소 계약은 공유하되, 지도와 상세 화면이 서로의 Presenter를 직접 수정하지 않도록 해요.

## MVVM과 비교하면 어떤 비용이 있나요?

MVVM은 Model–View–ViewModel의 약자예요. ViewModel로 표시 로직을 분리하고 바인딩을 활용하는 접근이에요. [objc.io의 MVVM 설명](https://www.objc.io/issues/13-architecture/mvvm/)

아래는 여백의 기능 규모를 고려한 설계 비교예요. 어느 쪽이 항상 우수하다는 판정은 아니에요.

| 비교 기준 | VIPER 적용안 | MVVM 기반 대안 |
| --- | --- | --- |
| 책임 표현 | 표시·유스케이스·이동 역할을 이름으로 구분 | ViewModel 외 책임을 나눌 팀 규칙이 필요 |
| 초기 작업량 | 인터페이스와 조립 코드가 더 필요 | 작은 화면은 적은 객체로 시작하기 쉬움 |
| 테스트 | 조회 정책과 표시 변환을 따로 검증 | ViewModel에서도 의존성을 주입하면 검증 가능 |
| 주의점 | 전달만 하는 객체가 늘어날 수 있음 | ViewModel에 조회·저장·이동이 모일 수 있음 |

MVVM에도 별도 유스케이스와 Router를 둘 수 있어요. VIPER를 쓴다고 테스트가 자동으로 생기는 것도 아니에요. 여백은 선택한 VIPER를 유지하되, 지도 모듈 하나에서 역할 분리의 이득과 조립 비용을 먼저 확인하는 방향을 제안해요.

## 구현 전에 확인할 항목

아래 항목은 제안하는 검증 기준이며, 현재 구현이나 테스트가 완료됐다는 뜻은 아니에요.

- [ ] Interactor가 Mapbox·Realm 객체 없이 동작한다.
- [ ] 같은 입력과 기준 시각을 넣으면 최신성 판정 결과가 같다.
- [ ] Presenter의 로딩·빈 결과·성공·오류 상태를 가짜 Interactor로 검증한다.
- [ ] 장소 선택 시 Router에 올바른 장소 식별자를 전달한다.
- [ ] 과거 응답과 중복 메시지가 최신 표시를 덮어쓰지 않는다.
- [ ] 화면 재진입 시 구독이 중복되지 않고, 종료 시 소비 작업이 정리된다.
- [ ] 연결 종료·재연결·캐시 실패에서도 데이터 기준 시각을 유지한다.
- [ ] 저장 모델과 도메인 모델의 변환을 데이터 계층 테스트로 확인한다.
- [ ] Mapbox 표시와 실제 저장·통신은 별도의 통합 테스트로 확인한다.
- [ ] 최소 지원 OS, 캐시 만료 기준, 스냅샷·스트림 계약을 구현 전에 확정한다.

앱의 목표와 선택한 기술은 [README](../README.md), 데이터 제공 범위와 제약은 [실시간 혼잡도 API 조사](실시간-혼잡도-API-조사.md)에서 이어서 확인할 수 있어요.
