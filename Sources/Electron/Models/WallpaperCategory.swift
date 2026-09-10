import Foundation

enum WallpaperCategory: String, Codable, CaseIterable, Identifiable {
    case all
    case nature
    case abstract
    case city
    case space
    case minimal
    case animals
    case ocean
    case technology
    case seasonal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .nature: return "Nature"
        case .abstract: return "Abstract"
        case .city: return "City"
        case .space: return "Space"
        case .minimal: return "Minimal"
        case .animals: return "Animals"
        case .ocean: return "Ocean"
        case .technology: return "Technology"
        case .seasonal: return "Seasonal"
        }
    }

    var symbolName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .nature: return "leaf"
        case .abstract: return "paintpalette"
        case .city: return "building.2"
        case .space: return "sparkles"
        case .minimal: return "circle.dashed"
        case .animals: return "pawprint"
        case .ocean: return "water.waves"
        case .technology: return "cpu"
        case .seasonal: return "snowflake"
        }
    }

    /// The search query used to approximate this category on providers
    /// that don't have native categories (e.g. Pexels/Pixabay just take
    /// free-text queries).
    var searchTerm: String? {
        self == .all ? nil : rawValue
    }
}
