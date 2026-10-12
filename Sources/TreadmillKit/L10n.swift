import Foundation

/// Shared localization for app UI, speech and framework presentation properties.
/// Persisted workout metadata and enum raw values remain independent of language.
public enum L10n {
    private final class BundleToken {}

    public static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }

    public static var languageCode: String {
        Bundle.main.preferredLocalizations.first == "ja" ? "ja" : "en"
    }

    public static func text(_ key: String) -> String {
        text(key, language: languageCode)
    }

    /// Explicit language lookup also lets tests verify translations without changing device settings.
    public static func text(_ key: String, language: String) -> String {
        let code = language == "ja" ? "ja" : "en"
        guard let path = bundle.path(forResource: code, ofType: "lproj"),
              let localized = Bundle(path: path) else { return key }
        return localized.localizedString(forKey: key, value: key, table: nil)
    }

    /// String-only placeholders avoid printf type mismatches and preserve literal percent signs.
    public static func format(_ key: String, _ arguments: String...) -> String {
        render(text(key), arguments: arguments)
    }

    static func render(_ template: String, arguments: [String]) -> String {
        let parts = template.components(separatedBy: "%@")
        guard parts.count == arguments.count + 1 else { return template }
        return zip(parts.dropLast(), arguments).map { $0 + $1 }.joined() + (parts.last ?? "")
    }
}
