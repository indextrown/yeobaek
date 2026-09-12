---
title: "Xcode Target, Scheme, Bundle과 SwiftUI Preview 이해하기"
description: "Target과 Scheme의 차이, Bundle.main이 가리키는 대상, SwiftUI Preview가 Demo App을 실행 호스트로 사용하는 흐름을 여백 프로젝트 사례로 설명해요."
---

# Xcode Target, Scheme, Bundle과 SwiftUI Preview 이해하기

## 개요

모듈 안의 SwiftUI View를 Preview할 때 같은 코드인데도 선택한 Scheme에 따라 설정값이 달라질 수 있어요. 여백에서는 `YeobaekApp` Scheme으로 `MapBoxFeatureView`를 Preview했을 때 Mapbox 토큰을 찾지 못했지만, `MapBoxFeature` Scheme으로 바꾸자 지도가 정상적으로 나타났어요.

이 현상을 이해하려면 Target, Scheme, Bundle의 역할을 구분해야 해요. 이 문서를 읽고 나면 Feature의 Demo App이 왜 필요한지, Preview에서 `Bundle.main`이 무엇을 가리키는지, 설정값이 보이지 않을 때 어디부터 확인해야 하는지 알 수 있어요.

## Target은 무엇을 만드나요?

Target은 Xcode가 만들어야 할 결과물과 빌드 방법을 정의해요. 소스 파일, 리소스, 의존성, Info.plist, 빌드 설정이 Target에 속해요. Xcode는 이 정보를 사용해 앱이나 프레임워크 같은 제품을 만들어요. [Apple의 Target 설명](https://developer.apple.com/documentation/xcode/configuring-a-new-target-in-your-project)

여백에는 다음과 같은 Target이 있어요.

| Target | 제품 | 역할 |
| --- | --- | --- |
| `YeobaekApp` | App | 사용자가 실행하는 실제 앱을 만들어요. |
| `MapFeature` | Static Framework | MapKit 화면 코드를 제공해요. 혼자 실행할 수 없어요. |
| `MapFeatureDemo` | App | `MapFeature`를 독립적으로 실행해요. |
| `MapBoxFeature` | Static Framework | Mapbox 화면 코드를 제공해요. 혼자 실행할 수 없어요. |
| `MapBoxFeatureDemo` | App | `MapBoxFeature`를 독립적으로 실행해요. |
| `ThirdParty` | Framework | 외부 SDK를 한곳에서 링크해요. |

Static Framework도 별도 Target이에요. 개발할 때는 모듈 경계를 유지하지만, 최종 앱을 링크할 때 그 코드가 앱에 합쳐져요. Demo App은 같은 Feature 코드를 자신의 실행 파일에 넣어 실행해요.

```text
MapBoxFeature 코드 + YeobaekApp 코드 = YeobaekApp
MapBoxFeature 코드 + MapBoxFeatureDemo 코드 = MapBoxFeatureDemo
```

Feature마다 Demo App이 있어도 Feature를 Dynamic Framework로 만들 필요는 없어요. Feature는 화면 코드를 제공하고 App과 Demo가 실행을 담당해요.

## Scheme은 무엇을 실행할지 정해요

Scheme은 어떤 Target을 어떤 설정으로 빌드하고 실행할지 묶어 둔 실행 계획이에요. Target이 결과물의 설계도라면 Scheme은 Xcode가 그 결과물을 다루는 방법이에요.

Scheme에는 다음 Action이 있어요.

| Action | 역할 |
| --- | --- |
| Build | 어떤 Target을 빌드할지 정해요. |
| Run | 어떤 실행 파일을 어떤 Build Configuration으로 실행할지 정해요. |
| Test | 어떤 테스트를 실행할지 정해요. |
| Profile | 성능 분석에 사용할 실행 파일과 설정을 정해요. |
| Archive | 배포용 결과물을 만들 Target과 설정을 정해요. |

Xcode는 선택한 Scheme을 보고 Build, Run, Test, Profile, Archive 작업을 수행해요. Scheme의 Build 목록에는 여러 Target이 들어갈 수 있고, Run에는 실제로 실행할 App Target이 필요해요. [Apple의 Scheme 설명](https://developer.apple.com/documentation/xcode/customizing-the-build-schemes-for-a-project)

여백의 `MapBoxFeature` Scheme은 이름이 Feature와 같지만 실제 실행 제품은 `MapBoxFeatureDemo`예요.

```text
MapBoxFeature Scheme
├── Build: MapBoxFeature와 필요한 의존성
└── Run: MapBoxFeatureDemo
```

Xcode 상단에서 `MapBoxFeature` Scheme을 선택하고 실행했을 때 `Finished running MapBoxFeatureDemo`라고 표시되는 이유예요.

## Bundle은 코드와 리소스를 담는 상자예요

Bundle은 실행 파일, Info.plist, 이미지, 문자열 같은 코드와 리소스를 정해진 구조로 담는 디렉터리예요. App과 Framework 모두 Bundle이 될 수 있어요. [Apple의 Bundle 설명](https://developer.apple.com/documentation/foundation/bundle)

`Bundle.main`은 현재 실행 중인 실행 파일이 들어 있는 Bundle을 반환해요. Framework 안에서 `Bundle.main`을 호출해도 Framework Bundle이 아니라 그 코드를 실행하는 App Bundle을 가리켜요. [Apple의 Bundle.main 설명](https://developer.apple.com/documentation/foundation/bundle/main)

```text
YeobaekApp이 실행 중
└── Bundle.main = YeobaekApp.app

MapBoxFeatureDemo가 실행 중
└── Bundle.main = MapBoxFeatureDemo.app
```

여백의 `AppConfiguration`은 다음 흐름으로 Mapbox 토큰을 읽어요.

```text
Secrets.xcconfig
→ App Target의 Build Setting
→ App의 Info.plist에 MBXAccessToken 생성
→ Bundle.main에서 MBXAccessToken 조회
```

따라서 같은 `MapBoxFeatureView`라도 어떤 App이 실행 호스트인지에 따라 조회하는 Info.plist가 달라져요.

## SwiftUI Preview도 실행할 App이 필요해요

`#Preview`는 View를 만들고 Canvas에 표시하도록 Xcode에 알려 주는 코드예요. Preview는 기기 설정과 샘플 데이터를 별도로 구성할 수 있어요. [Apple의 Preview 설명](https://developer.apple.com/documentation/xcode/adding-previews-to-your-interface-files)

Framework는 혼자 실행할 수 없으므로 Xcode는 Preview를 띄울 실행 호스트가 필요해요. 모듈화 프로젝트에서는 실제 App이나 Feature의 Demo App이 그 역할을 맡아요.

```text
#Preview
→ 선택한 Scheme 확인
→ Scheme이 빌드할 Target 확인
→ 실행 가능한 App을 Preview 호스트로 사용
→ App 안에서 Feature View 생성
→ 실행 App의 Bundle이 Bundle.main이 됨
```

Preview Canvas는 화면만 그리는 정적 이미지가 아니에요. Preview용 실행 환경에서 View 코드를 실제로 실행해요. View 초기화 과정에서 `Bundle.main`, 환경 변수, 네트워크 SDK를 사용하면 Preview 호스트의 설정에 영향을 받아요.

## Mapbox Preview는 왜 Scheme을 바꾸자 동작했나요?

`MapBoxFeatureView`는 초기화할 때 `AppConfiguration.mapboxAccessToken`을 읽어요. `AppConfiguration`은 `Bundle.main`의 Info.plist에서 `MBXAccessToken`을 찾아요.

`YeobaekApp` Scheme으로 Framework 소스의 Preview를 열었을 때는 Preview 실행 컨텍스트에서 기대한 토큰 값을 읽지 못했어요. `MapBoxFeature` Scheme으로 변경하자 `MapBoxFeatureDemo`가 Preview 호스트가 되었고, Demo Target에 연결된 설정을 읽을 수 있었어요.

```text
MapBoxFeature Scheme
→ MapBoxFeatureDemo가 실행 호스트
→ MapBoxFeatureDemo의 Debug 설정 사용
→ Projects/App/Secrets.xcconfig 적용
→ Info.plist의 MBXAccessToken 생성
→ Bundle.main에서 토큰 조회 성공
→ Mapbox 지도 표시
```

Demo App이어서 토큰을 특별하게 처리한 것은 아니에요. Demo App도 일반 App Target이고, 자신의 Info.plist와 Build Configuration을 가지고 있어요. 중요한 점은 Preview를 실행하는 호스트 App에 필요한 설정이 들어 있어야 한다는 것이에요.

## Target, Scheme, Bundle을 한 번에 구분해요

| 개념 | 답하는 질문 | 여백의 예 |
| --- | --- | --- |
| Target | 무엇을 만들까요? | `MapBoxFeature`, `MapBoxFeatureDemo` |
| Scheme | 무엇을 어떻게 빌드하고 실행할까요? | `MapBoxFeature` Scheme이 Demo를 실행해요. |
| Bundle | 실행 파일과 설정·리소스는 어디에 들어 있나요? | `MapBoxFeatureDemo.app` |
| Preview host | Preview 코드는 어느 App 안에서 실행되나요? | `MapBoxFeatureDemo` |

짧게 표현하면 다음과 같아요.

```text
Target = 제품 설계도
Scheme = 빌드와 실행 계획
Bundle = 만들어진 제품을 담는 상자
Preview host = Preview를 실제로 실행하는 App
```

## 여백에서 Scheme을 선택하는 기준

| 작업 | 선택할 Scheme |
| --- | --- |
| 전체 앱 흐름 확인 | `YeobaekApp` |
| MapKit Feature 개발과 Preview | `MapFeature` |
| Mapbox Feature 개발과 Preview | `MapBoxFeature` |
| Feature를 실제 앱에 조립한 결과 확인 | `YeobaekApp` |

Feature를 개발할 때는 해당 Demo Scheme을 선택하면 필요한 설정과 실행 환경을 좁게 유지할 수 있어요. 전체 앱의 화면 전환과 모듈 조립을 확인할 때는 `YeobaekApp` Scheme을 사용해요.

## Preview 설정을 찾지 못할 때 확인해요

1. Xcode 상단에서 현재 선택한 Scheme을 확인해요.
2. `Edit Scheme > Build`에서 Feature와 실행할 App Target이 포함됐는지 확인해요.
3. `Edit Scheme > Run`에서 실제 실행 파일과 Build Configuration을 확인해요.
4. 실행 호스트 App Target에 `.xcconfig`가 연결됐는지 확인해요.
5. App의 Info.plist에 `$(MAPBOX_ACCESS_TOKEN)` 같은 Build Setting 참조가 있는지 확인해요.
6. Preview에서 `Bundle.main.bundleIdentifier`로 현재 실행 Bundle을 확인해요.

```swift
#if DEBUG
print("Preview bundle:", Bundle.main.bundleIdentifier ?? "nil")
print(
    "Has Mapbox token:",
    Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") != nil
)
#endif
```

토큰 원문을 로그에 출력하면 안 돼요. 값의 존재 여부와 Bundle 식별자만 확인해요.

## 설정 의존성이 커지면 값을 주입해요

현재처럼 App과 Demo가 같은 Info.plist 키를 제공하면 `Bundle.main` 방식으로 운영할 수 있어요. Feature가 여러 앱, 테스트, Preview에서 재사용되고 실행 환경이 더 복잡해지면 Feature가 `Bundle.main`을 직접 읽지 않도록 설정값을 주입하는 방식이 더 안정적이에요.

```swift
MapBoxFeatureView(
    accessToken: AppConfiguration.mapboxAccessToken
)
```

이 구조에서는 App과 Demo가 설정을 읽고 Feature는 전달받은 값만 사용해요. Preview도 실제 토큰 대신 Preview 전용 설정을 전달할 수 있어요. 지금 당장 구조를 바꿔야 한다는 뜻은 아니에요. 실행 호스트가 늘어나면서 `Bundle.main` 의존성을 관리하기 어려워질 때 적용하면 돼요.
