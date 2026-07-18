import Foundation

struct AppLanguage: Identifiable, Hashable {
    static let storageKey = "appLanguageCode"

    let code: String
    let name: String
    var id: String { code }

    static let supported: [AppLanguage] = [
        .init(code: "", name: "System Default"),
        .init(code: "en", name: "English"), .init(code: "as", name: "অসমীয়া"),
        .init(code: "bn", name: "বাংলা"), .init(code: "brx", name: "बड़ो"),
        .init(code: "doi", name: "डोगरी"), .init(code: "gu", name: "ગુજરાતી"),
        .init(code: "hi", name: "हिन्दी"), .init(code: "kn", name: "ಕನ್ನಡ"),
        .init(code: "ks", name: "کٲشُر"), .init(code: "kok", name: "कोंकणी"),
        .init(code: "mai", name: "मैथिली"), .init(code: "ml", name: "മലയാളം"),
        .init(code: "mni", name: "ꯃꯤꯇꯩ ꯂꯣꯟ"), .init(code: "mr", name: "मराठी"),
        .init(code: "ne", name: "नेपाली"), .init(code: "or", name: "ଓଡ଼ିଆ"),
        .init(code: "pa", name: "ਪੰਜਾਬੀ"), .init(code: "fa", name: "فارسی"),
        .init(code: "sa", name: "संस्कृतम्"), .init(code: "sat", name: "ᱥᱟᱱᱛᱟᱲᱤ"),
        .init(code: "sd", name: "سنڌي"), .init(code: "ta", name: "தமிழ்"),
        .init(code: "te", name: "తెలుగు"), .init(code: "ur", name: "اردو"),
        .init(code: "es", name: "Español"), .init(code: "fr", name: "Français"),
        .init(code: "pt-BR", name: "Português (Brasil)"),
        .init(code: "zh-Hans", name: "简体中文"), .init(code: "ar", name: "العربية")
    ]

    static func locale(for code: String) -> Locale {
        code.isEmpty ? .autoupdatingCurrent : Locale(identifier: code)
    }

    static func isRightToLeft(_ code: String) -> Bool {
        let effectiveCode = code.isEmpty ? (Locale.preferredLanguages.first ?? "en") : code
        return ["ar", "fa", "ks", "sd", "ur"].contains { effectiveCode.hasPrefix($0) }
    }

    static func localized(_ key: String) -> String {
        let selected = UserDefaults.standard.string(forKey: storageKey) ?? ""
        if selected == "en" { return key }
        guard !selected.isEmpty,
              let path = Bundle.main.path(forResource: selected, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
