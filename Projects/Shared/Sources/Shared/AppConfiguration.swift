import Foundation

public enum AppConfiguration {
    public static var mapboxAccessToken: String? {
        value(for: "MBXAccessToken")
    }

    /// Reads a resolved configuration string from the running app's Info.plist.
    ///
    /// - Parameter key: The Info.plist key to read from the main bundle.
    /// - Returns: Trimmed text, or nil for missing, non-string, blank, or unresolved values.
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
