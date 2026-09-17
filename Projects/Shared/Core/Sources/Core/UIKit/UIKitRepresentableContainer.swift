import SwiftUI
import UIKit

/// UIKit의 UIView를 SwiftUI 계층에서 재사용할 수 있게 연결합니다.
public struct UIViewRepresentableContainer<Content: UIView>: UIViewRepresentable {
    private let makeContent: () -> Content
    private let updateContent: (Content) -> Void

    /// UIKit View의 생성과 갱신 동작을 주입해 SwiftUI 브리지를 만듭니다.
    ///
    /// - Parameters:
    ///   - makeContent: SwiftUI가 처음 표시할 UIKit View를 만드는 동작입니다.
    ///   - updateContent: SwiftUI 상태가 갱신될 때 기존 UIKit View에 반영할 동작입니다.
    public init(
        makeContent: @escaping () -> Content,
        updateContent: @escaping (Content) -> Void = { _ in }
    ) {
        self.makeContent = makeContent
        self.updateContent = updateContent
    }

    /// SwiftUI 계층에 처음 삽입할 UIKit View를 만듭니다.
    ///
    /// - Parameter context: SwiftUI가 제공하는 표현 컨텍스트입니다.
    /// - Returns: 주입된 생성 동작으로 만든 UIKit View입니다.
    public func makeUIView(
        context: Context
    ) -> Content {
        makeContent()
    }

    /// SwiftUI 상태 변경을 기존 UIKit View에 반영합니다.
    ///
    /// - Parameters:
    ///   - uiView: 이전에 생성해 재사용 중인 UIKit View입니다.
    ///   - context: SwiftUI가 제공하는 표현 컨텍스트입니다.
    public func updateUIView(
        _ uiView: Content,
        context: Context
    ) {
        updateContent(uiView)
    }
}

/// UIKit의 UIViewController를 SwiftUI 계층에서 생명주기와 함께 재사용할 수 있게 연결합니다.
public struct UIViewControllerRepresentableContainer<Content: UIViewController>: UIViewControllerRepresentable {
    private let makeContent: () -> Content
    private let updateContent: (Content) -> Void

    /// UIKit ViewController의 생성과 갱신 동작을 주입해 SwiftUI 브리지를 만듭니다.
    ///
    /// - Parameters:
    ///   - makeContent: SwiftUI가 처음 표시할 UIKit ViewController를 만드는 동작입니다.
    ///   - updateContent: SwiftUI 상태가 갱신될 때 기존 UIKit ViewController에 반영할 동작입니다.
    public init(
        makeContent: @escaping () -> Content,
        updateContent: @escaping (Content) -> Void = { _ in }
    ) {
        self.makeContent = makeContent
        self.updateContent = updateContent
    }

    /// SwiftUI 계층에 처음 삽입할 UIKit ViewController를 만듭니다.
    ///
    /// - Parameter context: SwiftUI가 제공하는 표현 컨텍스트입니다.
    /// - Returns: 주입된 생성 동작으로 만든 UIKit ViewController입니다.
    public func makeUIViewController(
        context: Context
    ) -> Content {
        makeContent()
    }

    /// SwiftUI 상태 변경을 기존 UIKit ViewController에 반영합니다.
    ///
    /// - Parameters:
    ///   - uiViewController: 이전에 생성해 재사용 중인 UIKit ViewController입니다.
    ///   - context: SwiftUI가 제공하는 표현 컨텍스트입니다.
    public func updateUIViewController(
        _ uiViewController: Content,
        context: Context
    ) {
        updateContent(uiViewController)
    }
}
