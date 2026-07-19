import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system, leaf, ocean, sunset, monochrome

    static let storageKey = "appTheme"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .leaf: "Leaf"
        case .ocean: "Ocean"
        case .sunset: "Sunset"
        case .monochrome: "Monochrome"
        }
    }

    var accent: Color {
        switch self {
        case .system: .indigo
        case .leaf: .green
        case .ocean: .blue
        case .sunset: .orange
        case .monochrome: .primary
        }
    }

    var heroColors: [Color] {
        switch self {
        case .system: [.indigo, .teal]
        case .leaf: [.green, .mint]
        case .ocean: [.blue, .cyan]
        case .sunset: [.orange, .pink]
        case .monochrome: [Color(uiColor: .darkGray), Color(uiColor: .systemGray)]
        }
    }
}
