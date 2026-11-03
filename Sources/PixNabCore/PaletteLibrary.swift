import Foundation

public enum PaletteCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case saas, ecommerce, fintech, editorial, portfolio, wellness, nature, darkUI, designSystems, generated
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .saas: return "SaaS & Tech"
        case .ecommerce: return "E-commerce"
        case .fintech: return "Finance & Fintech"
        case .editorial: return "Editorial & Media"
        case .portfolio: return "Creative & Portfolio"
        case .wellness: return "Wellness & Lifestyle"
        case .nature: return "Nature & Travel"
        case .darkUI: return "Dark Interfaces"
        case .designSystems: return "Design Systems"
        case .generated: return "Custom & Generated"
        }
    }
}

public struct PaletteSwatch: Codable, Equatable, Sendable {
    public var name: String
    public var color: SRGBColor
    public var sourceP3: DisplayP3Color?
    public init(name: String, color: SRGBColor, sourceP3: DisplayP3Color? = nil) {
        self.name = name; self.color = color; self.sourceP3 = sourceP3
    }
}

public struct NamedPalette: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var category: PaletteCategory
    public var swatches: [PaletteSwatch]
    public var createdAt: Date
    public var updatedAt: Date
    public init(id: UUID = UUID(), name: String, category: PaletteCategory,
                swatches: [PaletteSwatch], createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.name = name; self.category = category
        self.swatches = swatches; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public struct PaletteLibrary: Codable, Equatable, Sendable {
    public private(set) var items: [NamedPalette]
    public init(items: [NamedPalette] = []) { self.items = items }

    @discardableResult
    public mutating func add(name: String, category: PaletteCategory,
                             swatches: [PaletteSwatch]) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 100,
              !swatches.isEmpty, swatches.count <= 32, items.count < 500 else { return nil }
        let value = NamedPalette(name: trimmed, category: category, swatches: swatches)
        items.insert(value, at: 0)
        return value.id
    }

    @discardableResult
    public mutating func rename(_ id: UUID, to name: String) -> Bool {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 100,
              let index = items.firstIndex(where: {$0.id == id}) else { return false }
        items[index].name = value; items[index].updatedAt = .now
        return true
    }

    @discardableResult
    public mutating func remove(_ id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        items.remove(at: index)
        return true
    }

    @discardableResult
    public mutating func duplicate(_ id: UUID) -> UUID? {
        guard let source = items.first(where: {$0.id == id}) else { return nil }
        return add(name: String((source.name + " Copy").prefix(100)), category: source.category,
                   swatches: source.swatches)
    }

    @discardableResult
    public mutating func addSwatch(_ id: UUID, swatch: PaletteSwatch) -> Bool {
        guard let i = items.firstIndex(where: { $0.id == id }),
              items[i].swatches.count < 32 else { return false }
        items[i].swatches.append(swatch)
        items[i].updatedAt = .now
        return true
    }

    @discardableResult
    public mutating func removeSwatch(_ id: UUID, at index: Int) -> Bool {
        guard let i = items.firstIndex(where: { $0.id == id }),
              items[i].swatches.count > 1,
              items[i].swatches.indices.contains(index) else { return false }
        items[i].swatches.remove(at: index)
        items[i].updatedAt = .now
        return true
    }

    @discardableResult
    public mutating func changeCategory(_ id: UUID, to category: PaletteCategory) -> Bool {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return false }
        items[i].category = category
        items[i].updatedAt = .now
        return true
    }

    /// Validated non-destructive import. Regenerate IDs so saved palettes can
    /// never overwrite an existing entry merely by reusing its UUID.
    /// The operation is all-or-nothing: no partial import on limit errors.
    @discardableResult
    public mutating func merge(_ external: PaletteLibrary) -> Int? {
        guard !external.items.isEmpty, items.count + external.items.count <= 500,
              external.items.allSatisfy({ palette in
                  let name = palette.name.trimmingCharacters(in: .whitespacesAndNewlines)
                  return !name.isEmpty && name.count <= 100 &&
                      (1...32).contains(palette.swatches.count)
              }) else { return nil }
        let additions = external.items.map { palette -> NamedPalette in
            var copy = palette
            copy.id = UUID()
            copy.createdAt = .now
            copy.updatedAt = .now
            return copy
        }
        items.insert(contentsOf: additions, at: 0)
        return additions.count
    }

    @discardableResult
    public mutating func moveSwatch(_ id: UUID, from: Int, to: Int) -> Bool {
        guard let i = items.firstIndex(where: {$0.id == id}),
              items[i].swatches.indices.contains(from),
              items[i].swatches.indices.contains(to) else { return false }
        let swatch = items[i].swatches.remove(at: from)
        items[i].swatches.insert(swatch, at: to)
        items[i].updatedAt = .now
        return true
    }
}

/// Curated starter catalog. An original PixNab set is *not* attributed to a
/// third-party brand. Third-party entries are explicitly marked as selections
/// (not their full design systems) and link to their canonical palette page.
