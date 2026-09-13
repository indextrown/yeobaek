---
kind: tech-spec
title: "UIKit Component의 SwiftUI 연결"
status: "초안"
last_updated: "2026-09-13"
html: "./tech-spec.html"
---

# UIKit Component의 SwiftUI 연결

## 요약

UIKit으로 작성한 UI를 UIKit과 SwiftUI에서 함께 사용할 수 있도록 `Projects/Shared/Component` 모듈을 제안해요. 개발자는 UIKit 뷰의 생성과 상태 반영을 `Component`에 정의하고, SwiftUI에서 사용할 때 해당 컴포넌트에 `View`를 추가 채택해요. 첫 버전은 뷰 생성과 단방향 상태 갱신에 집중하고, 컬렉션뷰 전용 조건은 포함하지 않아요.

이 문서는 구현 전 초안이에요. 아래 인터페이스와 예시는 아직 여백의 기능 코드로 구현하거나 빌드한 결과가 아니에요.

## 배경

여백은 UIKit + RxSwift + MVVM을 제품 Feature의 기본 방식으로 사용해요. `MapFeature`만 SwiftUI로 구현하고, App과 Preview에서는 UIKit 화면을 SwiftUI에 연결하는 래퍼도 사용해요.

현재 `Projects/Shared/Core/Sources/Core/UIKit/UIKitRepresentableContainer.swift`에는 UIView와 UIViewController를 감싸는 클로저 기반 래퍼가 있어요. 이 도구는 개별 화면 연결에 사용할 수 있지만, 재사용할 UI의 생성과 갱신 규칙을 하나의 컴포넌트 타입으로 정의하지는 않아요.

사용자가 지정한 하루한컷 프로젝트에서 다음 구현을 확인했어요.

| 참고 코드 | 확인한 역할 |
| --- | --- |
| `Projects/Shared/CollectionViewAdapter/Sources/Collection/5. Component.swift` | `Content: UIView`, `createContent()`, `render(context:content:)`로 생성과 갱신을 분리해요. |
| `Projects/Shared/CollectionViewAdapter/Sources/Collection/SwiftUI/25. Component+SwiftUI.swift` | `Component where Self: View`에 기본 `body`를 제공하고 UIViewRepresentable로 연결해요. |
| `Projects/Shared/CollectionViewAdapter/Sources/Collection/4. ComponentContext.swift` | 컬렉션 위치 정보와 렌더링 작업의 취소 수명을 함께 관리해요. |

하루한컷의 `Component`는 컬렉션 레이아웃을 위한 추정 높이와 Diffable Data Source를 위한 `Item: Identifiable & Equatable`도 요구해요. 여백에서는 이 조건을 가져오지 않고, UIKit UI를 선언적인 값으로 표현하고 갱신하는 개념만 활용하려고 해요.

## 목표

- 같은 UIKit UI를 UIKit 화면과 SwiftUI 화면에서 사용할 수 있어야 해요.
- 개발자는 컴포넌트에 `View`를 추가 채택하는 것만으로 SwiftUI 문법과 modifier를 사용할 수 있어야 해요.
- SwiftUI에서 전달한 최신 상태가 기존 UIKit 뷰에 반영되어야 해요.
- 컴포넌트마다 UIViewRepresentable 코드를 반복 작성하지 않아도 되어야 해요.
- UI를 만들기 위해 컬렉션뷰, 셀 식별자 또는 비교 가능한 Item을 정의할 필요가 없어야 해요.
- 기존 지도 Feature와 Core의 래퍼를 바꾸지 않고 독립 Demo에서 설계를 확인할 수 있어야 해요.

## 목표가 아닌 것

- UICollectionView, Diffable Data Source, 셀 재사용과 Compositional Layout을 추상화하지 않아요.
- 기존 UIView 클래스에 `View`만 붙이면 자동 변환되는 기능은 만들지 않아요. UIView의 생성과 갱신을 담당하는 컴포넌트 구조체가 `View`를 채택해요.
- UIKit 이벤트를 SwiftUI의 상태나 Binding에 자동으로 전달하지 않아요. 이벤트와 Coordinator 설계는 후속 범위예요.
- Rx 구독, 네트워크 요청과 비동기 작업을 렌더링 수명에 자동 연결하지 않아요.
- 모든 UIView의 동적 높이와 SwiftUI 애니메이션을 자동 지원하지 않아요.
- UIViewController 래퍼나 기존 지도 화면을 새 모듈로 이전하지 않아요.
- 색상, 폰트, 버튼 등 디자인 시스템 전체를 이 모듈에 모으지 않아요.

## 계획

### 모듈과 책임

다음 구조를 제안해요. 파일과 타깃은 기능 구현을 승인한 뒤 만들어요.

```text
Projects/Shared/Component/
├── Project.swift
├── Sources/Component/
│   ├── Component.swift
│   ├── ComponentRepresentable.swift
│   └── Component+SwiftUI.swift
└── Demo/
    └── ComponentDemoApp.swift
```

`Component`는 UIKit과 SwiftUI만 사용하는 독립 framework로 구성해요. Core, Domain, Data, ThirdParty와 RxSwift는 의존하지 않아요. `ComponentDemo` 실행 타깃만 새 framework를 의존하고, 기존 제품 Feature에는 이번 단계에서 의존성을 추가하지 않아요.

| 구성 | 제안하는 책임 |
| --- | --- |
| `Component` | UIKit 뷰의 구체 타입, 생성과 최신 상태 반영을 정의해요. |
| `ComponentRepresentable<C>` | SwiftUI의 생성과 갱신 호출을 컴포넌트에 전달해요. 모듈 내부 구현으로 숨겨요. |
| `Component where Self: View` | 컴포넌트를 Representable로 감싸는 기본 `body`를 제공해요. |
| 구체 컴포넌트 | `count`, `title` 등 표시할 값을 보관하고 UIKit 뷰에 반영해요. |
| `ComponentDemo` | 같은 컴포넌트의 UIKit 사용과 SwiftUI 상태 갱신을 확인해요. |

Core의 기존 래퍼는 클로저로 개별 UI를 연결하는 용도로 유지해요. 새 모듈은 컴포넌트 타입의 계약을 제공해요. 첫 단계에서는 두 도구를 통합하려고 Core의 책임이나 의존 방향을 변경하지 않아요.

### 생성과 갱신 계약

컴포넌트는 공통 Item을 요구하지 않아요. 상태를 일반 프로퍼티로 보관하고, UIKit을 만지는 메서드에만 `@MainActor`를 지정해요. SwiftUI 브리지 자체는 UI 어댑터이므로 메인 액터에서 동작하도록 해요.

```swift
import UIKit

/// UIKit 뷰의 생성과 상태 반영을 정의하는 UI 단위입니다.
public protocol Component {
    associatedtype Content: UIView

    /// 상태를 표시할 UIKit 뷰를 생성합니다.
    /// - Returns: 새로 생성한 UIKit 뷰입니다.
    @MainActor
    func createContent() -> Content

    /// 기존 UIKit 뷰에 현재 상태를 반영합니다.
    /// - Parameter content: 상태를 갱신할 UIKit 뷰입니다.
    @MainActor
    func render(
        content: Content
    )
}
```

하루한컷의 `CompositionalLayoutSizeable`, `estimatedHeight`, `Item` 제약은 제거해요. 첫 계약에서는 `ComponentContext`도 요구하지 않아요. 다만 렌더링 작업 취소는 컬렉션 전용 개념이 아니므로, 이벤트나 비동기 작업을 지원하는 단계에서 별도의 범용 수명 관리로 설계해요.

### SwiftUI 연결 흐름

개발자가 `extension CountComponent: View {}`를 선언하면, 다음 조건부 확장이 기본 `body`를 제공하도록 해요. 호출부에서 `AnyView`를 사용하거나 UIKit 뷰를 미리 만들어 보관하지 않아요.

```swift
import SwiftUI

public extension Component where Self: View {
    /// UIKit 컴포넌트를 표시하는 기본 SwiftUI 표현입니다.
    @MainActor
    var body: some View {
        ComponentRepresentable(component: self)
    }
}
```

위 코드의 `ComponentRepresentable`은 구현할 내부 브리지를 가리켜요. 브리지는 다음 순서로 동작하도록 해요.

1. SwiftUI가 `makeUIView`를 호출하면 `createContent()`로 UIKit 뷰를 만들어요.
2. 브리지가 `render(content:)`를 호출해 초기 상태를 반영해요.
3. 부모의 상태가 바뀌면 SwiftUI가 최신 컴포넌트 값으로 `updateUIView`를 호출해요.
4. 브리지는 기존 UIKit 뷰에 `render(content:)`를 호출해요. 갱신할 때마다 뷰를 다시 만들지 않아요.
5. SwiftUI가 뷰를 제거하면 뷰의 수명이 끝나요. 다시 삽입하거나 정체성을 바꾸면 새 뷰를 만들 수 있어요.

뷰 생성과 갱신은 SwiftUI의 [UIViewRepresentable 계약](https://developer.apple.com/documentation/swiftui/uiviewrepresentable)을 따라요. `createContent()`를 앱 실행 중 한 번만 호출한다고 보장하지 않아요. `render` 호출 횟수도 특정 값으로 가정하지 않아요.

### 개발자 사용 예시

다음 코드는 사용 형태를 설명하기 위한 예시예요. `UILabel`은 기존 UIKit 뷰이고, `CountComponent`는 이 뷰에 표시할 값을 보관해요.

```swift
import Component
import SwiftUI
import UIKit

struct CountComponent: Component {
    let count: Int

    /// 표시할 숫자를 저장합니다.
    /// - Parameter count: 화면에 표시할 현재 값입니다.
    init(
        count: Int
    ) {
        self.count = count
    }

    /// 숫자를 표시할 UIKit 라벨을 생성합니다.
    /// - Returns: 기본 스타일을 설정한 라벨입니다.
    @MainActor
    func createContent() -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .title2)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        return label
    }

    /// 현재 숫자를 기존 라벨에 반영합니다.
    /// - Parameter content: 숫자를 표시할 라벨입니다.
    @MainActor
    func render(
        content: UILabel
    ) {
        content.text = "현재 값: \(count)"
    }
}

extension CountComponent: View {}

struct ComponentDemoView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 16) {
            CountComponent(count: count)
                .frame(height: 44)

            Button("증가") {
                count += 1
            }
        }
        .padding()
    }
}
```

예제 버튼은 SwiftUI 버튼이에요. UIKit 내부 이벤트의 역방향 전달까지 구현했다는 의미는 아니에요. 높이 `44`는 예제의 명시적인 크기이고, 모든 컴포넌트가 따라야 하는 기본 높이는 아니에요.

UIKit UIViewController 내부에서는 같은 컴포넌트로 뷰를 만들고 갱신해요. 생성한 라벨의 배치와 제약 조건은 해당 화면이 관리해요.

```swift
let component = CountComponent(count: 0)
let label = component.createContent()
component.render(content: label)

// 기존 라벨에 새로운 값을 반영해요.
CountComponent(count: 1).render(content: label)
```

### 수명과 레이아웃 기준

- `createContent()`에서 하위 뷰와 고정 제약 조건을 설정해요. `render`에서는 최신 표시 상태만 반영해요.
- 같은 값으로 `render`를 반복해도 하위 뷰, 이벤트 연결과 구독이 늘어나지 않아야 해요.
- `render`에서 SwiftUI의 Binding을 다시 변경하거나 외부 상태를 발행하지 않아요. 화면 갱신의 순환을 방지해요.
- UIKit 뷰가 보관한 콜백이나 Rx 구독의 자동 정리는 첫 버전에서 보장하지 않아요. 외부 작업이 필요한 컴포넌트는 후속 수명 관리 설계 이후에 적용해요.
- Demo는 명시적인 SwiftUI 크기를 사용해요. 여러 줄 텍스트와 임의 UIView의 동적 높이는 별도의 `sizeThatFits` 및 Auto Layout 계약이 필요해요.
- SwiftUI가 관리하는 최상위 UIKit 뷰의 `frame`, `bounds`, `center`, `transform`을 컴포넌트가 직접 변경하지 않아요. [Apple의 레이아웃 주의 사항](https://developer.apple.com/documentation/swiftui/uiviewrepresentable)을 따라요.

### 적용과 확인 순서

구현을 승인하면 모듈과 독립 Demo부터 추가해요. 기존 Mapbox, MapKit, App 세션과 Core의 UIViewController 래퍼는 유지해요. 새로운 모듈의 책임과 의존 방향은 `docs/architecture/architecture-overview.md`에 반영하고, Demo 사용법은 기존 문서 체계 안에 안내해요.

구현 단계에서 확인할 항목은 다음과 같아요. 이번 테크 스펙 작성에서는 기능 빌드와 테스트를 실행하지 않아요.

- 같은 UIKit 뷰 인스턴스에 새 컴포넌트 값이 반영되는지 확인해요.
- SwiftUI 부모의 상태 변경이 UILabel의 문구에 반영되는지 확인해요.
- 같은 값으로 여러 번 갱신해도 하위 뷰가 늘어나지 않는지 확인해요.
- 화면 제거 후 UIKit 뷰가 해제되고, 재삽입 시 최신 상태로 생성되는지 확인해요.
- Demo가 Core, Domain, Data 또는 제품 Feature 없이 실행되는지 확인해요.
- Dynamic Type과 접근성에서 예제의 숫자를 읽을 수 있는지 확인해요. 고정 높이 예제의 제약도 함께 확인해요.

## 고려 사항

- **Framework 타입:** 독립 모듈과 Demo 구성은 제안했지만 static/dynamic은 아직 합의하지 않았어요. 기존 Shared 모듈의 dynamic 구성과 맞출지, 실제 링크 조건을 달리할지 구현 승인 전에 사용자와 확정해요.
- **자동 크기 계산:** intrinsic content size가 없는 UIView나 여러 줄 텍스트는 최소 래퍼만으로 원하는 높이를 보장하지 못해요. 첫 버전은 명시적인 크기 사용으로 제한하고, [sizeThatFits](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/sizethatfits(_:uiview:context:)) 지원은 별도 범위로 합의해요.
- **이벤트와 수명:** UIKit 버튼, delegate, Rx 구독까지 첫 버전에 넣으려면 최신 콜백 교체와 해제 시점을 먼저 설계해야 해요. 현재 초안은 이를 제외해 범위를 작게 유지해요.
- **이름과 공개 계약:** 모듈과 프로토콜 모두 `Component`를 사용하는 안이에요. Demo를 별도 모듈에서 컴파일해 `import Component`와 기본 `body` 접근이 가능한지 구현 단계에서 확인해요.

## 마일스톤

| 단계 | 완료 조건 |
| --- | --- |
| 설계 확정 | 생성·갱신 계약, 첫 버전의 제외 범위, framework 타입과 Demo 구성을 합의해요. |
| 독립 모듈 구현 | 컬렉션 전용 제약 없이 Component와 내부 SwiftUI 브리지를 만들어요. |
| Demo와 동작 확인 | UIKit과 SwiftUI에서 같은 컴포넌트를 사용하고, 상태 갱신·재사용·해제를 확인해요. |
| 문서와 PR 준비 | 승인된 구현 및 확인 결과를 기록하고, 모듈 문서와 Demo 사용법을 갱신해요. 커밋·게시 범위는 별도 요청에 따라 진행해요. |
