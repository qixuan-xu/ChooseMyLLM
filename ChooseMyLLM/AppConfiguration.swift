import Foundation

// Values are supplied by AppConfig.xcconfig through the built app's Info.plist.
// Edit AppConfig.xcconfig to change branding, version, or splash duration.
enum AppConfiguration {
    static var displayName: String {
        string("CFBundleDisplayName") ?? string("CFBundleName") ?? "App"
    }

    static var version: String { string("CFBundleShortVersionString") ?? "—" }
    static var tagline: String { string("AppTagline") ?? "" }
    static var credit: String { string("AppCredit") ?? "" }

    static var splashDuration: Double {
        guard let value = string("SplashDurationSeconds"),
              let seconds = Double(value), seconds.isFinite, seconds >= 0 else {
            return 0
        }
        return seconds
    }

    private static func string(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
