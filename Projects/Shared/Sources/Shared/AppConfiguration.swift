import Foundation

public enum AppConfiguration {
    public static var mapboxAccessToken: String? {
        value(for: "MBXAccessToken")
    }

    private static func value(for key: String) -> String? {
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
