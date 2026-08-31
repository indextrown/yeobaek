import Foundation

public enum AppConfiguration {
    public static var mapboxAccessToken: String? {
        value(for: "MBXAccessToken")
    }

    /// 실행 중인 앱의 Info.plist에서 빌드 설정이 반영된 문자열을 읽습니다.
    ///
    /// - Parameter key: 메인 번들의 Info.plist에서 조회할 키입니다.
    /// - Returns: 앞뒤 공백과 개행을 제거한 문자열입니다. 값이 없거나 문자열이 아닌 경우, 비어 있거나 빌드 설정이 치환되지 않은 경우에는 `nil`입니다.
    private static func value(
        for key: String
    ) -> String? {
        guard let rawValue = Bundle.main.object(
            forInfoDictionaryKey: key
        ) as? String else {
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty,
              !value.contains("$(") else {
            return nil
        }

        return value
    }
}
