---
title: "Static Framework와 Dynamic Framework 이해하기"
description: "Static과 Dynamic Framework가 앱에 연결되는 방식, Feature와 Demo App의 관계, 여백 프로젝트의 선택 기준을 설명해요."
---

# Static Framework와 Dynamic Framework 이해하기

## 개요

Static Framework와 Dynamic Framework는 모두 코드를 모듈로 나누는 방법이에요. 가장 큰 차이는 **Framework의 코드가 최종 앱에 들어가는 시점과 방식**이에요.

이 문서에서는 다음 내용을 알아봐요.

- Static과 Dynamic Framework의 차이
- Feature마다 Demo App이 있어도 Static을 사용할 수 있는 이유
- Mapbox에서 발생했던 링크 오류와 실행 오류의 차이
- 여백 프로젝트에서 Framework 종류를 선택하는 기준

## 가장 짧게 구분해요

```text
Static = 빌드할 때 코드를 사용하는 앱에 합쳐요.
Dynamic = 별도 Framework 파일을 앱에 넣고 실행할 때 불러와요.
```

여기서 Static은 Swift의 `static` 프로퍼티나 타입 메서드와는 관계가 없어요. Framework 바이너리를 최종 실행 파일에 연결하는 방식을 뜻해요.

## Static Framework는 앱에 코드를 합쳐요

Static Framework를 사용하는 앱을 빌드하면 Framework의 코드가 앱 실행 파일에 합쳐져요.

```text
MapFeature 코드 + YeobaekApp 코드
              ↓
      YeobaekApp 실행 파일
```

최종 앱 안에 `MapFeature.framework`를 별도 실행 파일처럼 넣고 런타임에 불러오는 방식이 아니에요. 대신 앱을 링크할 때 필요한 코드가 앱 실행 파일에 포함돼요.

그렇다고 모듈 구분이 사라지는 것은 아니에요. 개발할 때는 계속 별도 Target과 Module로 관리하고, `import MapFeature`처럼 접근 제어와 의존성 경계를 유지할 수 있어요.

Apple도 Static Framework의 주 바이너리를 정적 아카이브로 설명하며, 코드는 클라이언트에 링크되므로 임베드된 Framework 번들에서는 주 바이너리를 제외한다고 안내해요. 자세한 내용은 [Creating a static framework](https://developer.apple.com/documentation/Xcode/creating-a-static-framework)에서 확인할 수 있어요.

## Demo App이 있어도 Static을 사용할 수 있어요

Feature에 Demo App이 있다고 해서 Feature를 Dynamic Framework로 만들 필요는 없어요.

Feature는 직접 실행되는 프로그램이 아니고, App과 Demo App이 Feature를 사용하는 실행 주체예요. 각 앱을 빌드할 때 Feature 코드가 각 실행 파일에 합쳐져요.

```text
MapFeature 코드 + YeobaekApp 코드
              ↓
      YeobaekApp 실행 파일

MapFeature 코드 + MapFeatureDemo 코드
              ↓
    MapFeatureDemo 실행 파일
```

따라서 다음 구조가 자연스러워요.

- `MapFeature`: Static Framework
- `YeobaekApp`: App Target
- `MapFeatureDemo`: App Target

Demo App의 역할은 Feature를 독립된 실행 환경에서 빠르게 확인하는 것이에요. Feature 바이너리가 런타임에 독립적으로 존재해야 한다는 뜻은 아니에요.

## Dynamic Framework는 별도 파일로 남아요

Dynamic Framework는 앱 실행 파일에 코드가 합쳐지지 않고 별도 바이너리로 앱 번들에 포함돼요.

```text
YeobaekApp.app/
  YeobaekApp
  Frameworks/
    ThirdParty.framework
    MapboxMaps.framework
    MapboxCommon.framework
```

앱을 실행하면 동적 로더인 `dyld`가 `Frameworks` 디렉터리와 `@rpath`를 확인해 필요한 Framework를 불러와요.

그래서 Dynamic Framework는 다음 조건이 모두 맞아야 해요.

- 빌드할 때 필요한 심볼이 연결되어야 해요.
- 앱 번들에 Framework 파일이 포함되어야 해요.
- 실제 기기에서 사용할 수 있도록 코드 서명이 되어야 해요.
- `@rpath`를 통해 올바른 위치를 찾을 수 있어야 해요.

앱이 Framework를 링크했지만 임베드하지 않으면 실행 시점에 충돌할 수 있어요. Apple의 [Addressing missing framework crashes](https://developer.apple.com/documentation/xcode/addressing-missing-framework-crashes)와 [Embedding Frameworks In An App](https://developer.apple.com/library/archive/technotes/tn2435/_index.html)에서도 실행 앱이 의존하는 동적 Framework를 앱 Target이 임베드해야 한다고 설명해요.

## 차이를 비교해요

| 구분 | Static Framework | Dynamic Framework |
| --- | --- | --- |
| 코드가 연결되는 시점 | 최종 앱을 링크할 때 | Framework를 링크한 뒤 실행 시 로드할 때 |
| 최종 코드 위치 | 앱 실행 파일 내부 | 별도 `.framework` 바이너리 |
| 앱 번들 임베드 | 주 바이너리를 별도로 로드하지 않음 | 앱의 `Frameworks`에 포함해야 함 |
| 실행 시 로딩 | 별도 동적 로딩 없음 | `dyld`가 로드함 |
| 코드 서명 관리 | 최종 앱 중심 | 임베드된 Framework도 필요 |
| 대표 문제 | 중복 링크, 실행 파일 크기 증가 | 누락된 임베드, `@rpath`, 서명 오류 |
| Demo App과 관계 | 각 Demo 실행 파일에 코드가 합쳐짐 | Demo가 Framework를 임베드하고 로드함 |

Static이 항상 빠르고 Dynamic이 항상 느리다고 단정할 수는 없어요. 다만 Dynamic Framework 수가 많아지면 앱 시작 시 로드하고 검증할 바이너리도 늘어나므로 관리할 요소가 많아져요.

반대로 Static Framework를 여러 Dynamic Framework에 각각 링크하면 동일한 코드가 여러 바이너리에 중복될 수 있어요. 프로젝트의 최종 의존성 구조를 보고 선택해야 해요.

## 여백에서는 이렇게 사용해요

| 모듈 | 종류 | 이유 |
| --- | --- | --- |
| `MapFeature` | Static Framework | 내부 Feature이며 App과 Demo에 각각 합치면 돼요. |
| `MapBoxFeature` | Static Framework | Feature 코드를 최종 App 링크 단계에서 `ThirdParty`와 함께 해결해요. |
| `ThirdParty` | Dynamic Framework | 외부 SDK를 연결하는 허브 역할을 해요. |
| `MapboxMaps` | Dynamic Framework | Mapbox가 제공하는 SDK 제품 정책을 따라요. |
| `YeobaekApp` | App | Feature와 외부 SDK를 최종적으로 링크하고 임베드해요. |
| Feature Demo | App | 해당 Feature를 실행할 수 있는 작은 호스트 앱이에요. |

`ThirdParty`는 모든 외부 라이브러리를 코드에서 대신 노출하는 모듈이 아니에요. 프로젝트 의존성 그래프에서 외부 SDK를 한곳에 모으는 링크 허브예요. Feature 소스에서는 필요한 라이브러리 이름을 직접 `import MapboxMaps`처럼 사용해요.

## Mapbox 오류로 차이를 이해해요

### `Undefined symbol`은 빌드할 때 발생해요

`MapBoxFeature`가 Dynamic Framework였을 때 `MapboxMaps.Map`, `Viewport`, `MapStyle` 등의 `Undefined symbol` 오류가 발생했어요.

Swift 컴파일러는 `MapboxMaps` 모듈을 찾아 타입을 이해했지만, `MapBoxFeature.framework` 자체를 만드는 링크 단계에서는 실제 구현을 연결하지 못한 상태였어요. Dynamic Framework는 자신이 별도 바이너리이므로 자신의 링크 단계에서 필요한 심볼을 해결해야 해요.

`MapBoxFeature`를 Static Framework로 바꾸면 Feature의 코드는 별도 동적 바이너리로 완성되지 않아요. 최종 `YeobaekApp`을 링크할 때 Feature 코드와 `ThirdParty`, `MapboxMaps` 구현을 함께 연결하므로 심볼을 해결할 수 있어요.

### `Library not loaded`는 실행할 때 발생해요

실제 기기에서 다음 형태의 오류도 발생했어요.

```text
Library not loaded: @rpath/MapboxCommon.framework/MapboxCommon
```

이 경우 빌드와 링크는 완료되었지만, 앱 실행 시 `dyld`가 필요한 동적 Framework 파일을 앱 번들에서 찾지 못한 것이에요.

앱 Target이 `ThirdParty`에 직접 의존하도록 구성하면 최종 실행 앱이 Mapbox의 동적 Framework들을 자신의 번들에 임베드할 책임을 명확하게 가질 수 있어요.

두 오류는 다음처럼 구분하면 쉬워요.

```text
Undefined symbol    = 빌드할 때 필요한 구현을 연결하지 못했어요.
Library not loaded = 실행할 때 필요한 동적 파일을 찾지 못했어요.
```

## 언제 Static을 선택하나요?

다음 조건이라면 Static Framework를 먼저 고려해요.

- 우리가 직접 만드는 Feature, Domain, Core 모듈이에요.
- 런타임에 별도 바이너리로 교체하거나 로드할 이유가 없어요.
- App과 Demo App이 각각 모듈을 사용하면 충분해요.
- 동적 임베드와 `@rpath` 관리를 줄이고 싶어요.
- 최종 App 링크 단계에서 의존성을 한 번에 해결하고 싶어요.

여백의 일반적인 Feature는 여기에 해당하므로 `.staticFramework`를 기본값으로 사용해요.

## 언제 Dynamic을 선택하나요?

다음과 같이 별도 런타임 바이너리가 필요한 이유가 있을 때 Dynamic Framework를 고려해요.

- 외부 SDK가 Dynamic Framework 형태로 제공돼요.
- 공급사의 배포 방식이나 Tuist 제품 설정이 Dynamic을 요구해요.
- 여러 Dynamic Framework가 공통 코드를 공유해야 해서 정적 코드 중복을 피해야 해요.
- 모듈을 별도 바이너리로 배포하거나 관리해야 해요.
- 실행 앱이 Framework를 임베드하고 서명하는 구조를 명확히 관리할 수 있어요.

Dynamic은 더 발전된 방식이고 Static은 단순한 방식이라는 관계가 아니에요. 필요한 실행 구조가 서로 다른 선택지예요.

## 선택 순서

새 모듈을 만들 때는 다음 순서로 판단해요.

1. 외부 SDK라면 공급사가 제공하는 제품 종류와 Tuist 설정을 먼저 확인해요.
2. 우리가 만드는 Feature, Domain, Core라면 Static을 기본으로 선택해요.
3. 별도 런타임 파일이어야 하는 구체적인 이유가 있을 때만 Dynamic을 선택해요.
4. Dynamic을 선택했다면 최종 App Target이 모든 동적 의존성을 링크하고 임베드하는지 확인해요.
5. 빌드 오류는 심볼 연결을, 실행 오류는 임베드와 `@rpath`를 먼저 확인해요.

## 주의할 점

Static Framework를 여러 Dynamic Framework에 각각 포함하면 코드가 중복될 수 있어요. Objective-C 런타임을 사용하는 라이브러리는 중복 클래스나 심볼 문제도 주의해야 해요.

Dynamic Framework는 자신이 의존하는 다른 Dynamic Framework까지 최종 App이 임베드해야 해요. 중간 Framework가 의존한다고 해서 최종 앱 번들에 자동으로 항상 포함된다고 가정하면 안 돼요.

Framework의 Static 또는 Dynamic 여부는 모듈의 공개 범위와도 다른 개념이에요. `public`, `internal`, Target dependency, `import` 가능 여부는 별도로 설계해야 해요.

XCFramework도 무조건 Dynamic인 것은 아니에요. XCFramework는 여러 플랫폼과 아키텍처의 바이너리를 묶는 형식이며, 내부에 Static 또는 Dynamic Framework를 담을 수 있어요. 자세한 내용은 [Creating a multiplatform binary framework bundle](https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle)에서 확인할 수 있어요.

## 여백의 기본 원칙

현재 프로젝트에서는 다음 원칙을 기본값으로 사용해요.

```text
App과 Feature Demo = .app
Feature             = .staticFramework
Domain과 Core       = .staticFramework
ThirdParty 링크 허브 = .framework
외부 SDK             = 공급사와 Tuist 제품 정책을 따름
```

이 원칙은 절대 규칙이 아니라 시작점이에요. 새로운 SDK나 특수한 배포 요구가 생기면 의존성 그래프와 최종 앱의 임베드 구조를 확인한 뒤 조정해요.

Target, Scheme, Bundle, Preview 실행 환경의 관계는 [Xcode Target, Scheme, Bundle과 SwiftUI Preview 이해하기](../development/xcode-target-scheme-bundle-preview.md)에서 이어서 확인할 수 있어요.

## 참고 자료

- [Apple: Creating a static framework](https://developer.apple.com/documentation/Xcode/creating-a-static-framework)
- [Apple: Addressing missing framework crashes](https://developer.apple.com/documentation/xcode/addressing-missing-framework-crashes)
- [Apple: Embedding Frameworks In An App](https://developer.apple.com/library/archive/technotes/tn2435/_index.html)
- [Apple: Creating a multiplatform binary framework bundle](https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle)
