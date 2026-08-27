import SwiftUI

struct AppRootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("여백")
                .font(.largeTitle.bold())

            Text("붐비는 공간 속, 여유를 찾다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    AppRootView()
}
