import SwiftUI

/// Featcher 모듈의 기본 화면입니다.
public struct FeatcherView: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            "Featcher",
            systemImage: "square.grid.2x2"
        )
    }
}

#Preview {
    FeatcherView()
}
