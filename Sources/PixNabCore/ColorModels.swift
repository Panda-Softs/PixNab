import Foundation

/// Normalized sRGB value. Out-of-gamut conversion is clipped at the input boundary.
/// Named SRGBColor rather than RGBColor to avoid colliding with QuickDraw RGBColor
/// automatically imported by Apple graphics frameworks on macOS.
public struct SRGBColor: Codable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        func clamp(_ value: Double) -> Double {
            guard value.isFinite else { return 0 }
            return min(1, max(0, value))
        }
        self.red = clamp(red); self.green = clamp(green)
        self.blue = clamp(blue); self.alpha = clamp(alpha)
    }

    public init(red8: Int, green8: Int, blue8: Int, alpha: Double = 1) {
        self.init(red: Double(red8) / 255, green: Double(green8) / 255,
                  blue: Double(blue8) / 255, alpha: alpha)
    }

    public var bytes: [Int] { [red, green, blue].map { Int(($0 * 255).rounded()) } }
    public var rgbaBytes: [Int] { bytes + [Int((alpha * 255).rounded())] }

    public var hsl: (h: Double, s: Double, l: Double) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue
        let lightness = (maxValue + minValue) / 2
        guard delta > 0 else { return (0, 0, lightness) }
        let saturation = delta / (1 - abs(2 * lightness - 1))
        var hue: Double
        switch maxValue {
        case red: hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        case green: hue = (blue - red) / delta + 2
        default: hue = (red - green) / delta + 4
        }
        hue *= 60
        if hue < 0 { hue += 360 }
        return (hue, saturation, lightness)
    }
}

/// Standard HSL (sRGB) reconstruction, shared by CSS parsing and the editor.
/// Clamping is delegated to SRGBColor's existing initializer.
public extension SRGBColor {
    init(hue: Double, saturation: Double, lightness: Double, alpha: Double = 1) {
        guard hue.isFinite, saturation.isFinite, lightness.isFinite else {
            self.init(red: 0, green: 0, blue: 0, alpha: alpha)
            return
        }
        let h = (hue.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let s = min(1, max(0, saturation))
        let l = min(1, max(0, lightness))
        let chroma = (1 - abs(2*l - 1))*s
        let x = chroma*(1 - abs((h/60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - chroma/2
        let rgb: (Double, Double, Double)
        switch h {
        case ..<60: rgb = (chroma, x, 0)
        case ..<120: rgb = (x, chroma, 0)
        case ..<180: rgb = (0, chroma, x)
        case ..<240: rgb = (0, x, chroma)
        case ..<300: rgb = (x, 0, chroma)
        default: rgb = (chroma, 0, x)
        }
        self.init(red: rgb.0 + m, green: rgb.1 + m, blue: rgb.2 + m, alpha: alpha)
    }
}

/// Common RGB/HSL harmonies. These are design suggestions, not colorimetric
/// measurements; captured Display P3 pixels remain untouched by the wheel.
public enum ColorHarmonyKind: String, CaseIterable, Identifiable, Sendable {
    case complementary, analogous, triadic, tetradic, monochromatic
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .complementary: return "Complementary"
        case .analogous: return "Analogous"
        case .triadic: return "Triadic"
        case .tetradic: return "Tetradic"
        case .monochromatic: return "Monochromatic"
        }
    }
}

public enum ColorHarmonyPalette {
    /// First entry is always the precise base color, not a reconstructed approximation.
    public static func colors(for base: SRGBColor, kind: ColorHarmonyKind) -> [SRGBColor] {
        let hsl = base.hsl
        if kind == .monochromatic {
            // Match the standalone wheel: base + one 10-point HSL lightness step.
            // The primary entry remains byte-for-byte identical to the selection.
            let shifted = hsl.l + (hsl.l > 0.5 ? -0.1 : 0.1)
            return [base, SRGBColor(hue: hsl.h, saturation: hsl.s,
                                    lightness: shifted, alpha: base.alpha)]
        }
        return [base] + hues(for: hsl.h, kind: kind).dropFirst().map { hue in
            SRGBColor(hue: hue, saturation: hsl.s, lightness: hsl.l, alpha: base.alpha)
        }
    }

    /// Positions for the visual markers and the RGB harmony calculation.
    /// Keep this single source of truth for the reference's angle offsets.
    public static func hues(for hue: Double, kind: ColorHarmonyKind) -> [Double] {
        let offsets: [Double]
        switch kind {
        case .complementary: offsets = [0, 180]
        case .analogous: offsets = [0, 30, -30]
        case .triadic: offsets = [0, 120, 240]
        case .tetradic: offsets = [0, 90, 180, 270]
        case .monochromatic: offsets = [0, 0]
        }
        return offsets.map {
            ((hue + $0).truncatingRemainder(dividingBy: 360) + 360)
                .truncatingRemainder(dividingBy: 360)
        }
    }

    public static func color(atHue hue: Double, basedOn base: SRGBColor) -> SRGBColor {
        let hsl = base.hsl
        // Grays have no defined hue. Dragging the hue ring gives them a visible hue.
        return SRGBColor(hue: hue, saturation: hsl.s < 0.00001 ? 0.7 : hsl.s,
                         lightness: hsl.l, alpha: base.alpha)
    }
}


/// Geometry shared by the native wheel and portable Swift Testing coverage.
/// Coordinates use a top-left origin, hue=0 at 12 o'clock, clockwise positive.
public struct WheelPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public enum ColorWheelGeometry {
    /// Which part of the wheel owns a pointer position. The unpainted gap
    /// between the disk and the lightness ring intentionally has no action.
    public enum InteractionZone: Equatable, Sendable {
        case disk, ring, inactive
    }

    public static func interactionZone(at point: WheelPoint, diameter: Double,
                                       ringBand: Double, separator: Double) -> InteractionZone {
        guard diameter.isFinite, diameter > 0,
              ringBand.isFinite, ringBand > 0,
              separator.isFinite, separator >= 0,
              2 * (ringBand + separator) < diameter,
              point.x.isFinite, point.y.isFinite else { return .inactive }
        let radius = hypot(point.x - diameter / 2, point.y - diameter / 2)
        if radius <= diameter / 2 - ringBand - separator { return .disk }
        if radius >= diameter / 2 - ringBand && radius <= diameter / 2 { return .ring }
        return .inactive
    }

    /// Keep a lightness drag active after it starts on the narrow ring, even
    /// when the pointer strays radially outside its painted band. A drag that
    /// starts on the disk may still transition between disk and ring; while it
    /// crosses the transparent gap, retain its last meaningful control.
    public static func dragZone(startedIn origin: InteractionZone,
                                previous: InteractionZone,
                                current: InteractionZone) -> InteractionZone {
        switch origin {
        case .ring:
            return .ring
        case .disk:
            return current == .inactive ? previous : current
        case .inactive:
            return .inactive
        }
    }

    public static func hueSaturation(at point: WheelPoint, diameter: Double,
                                     fallbackHue: Double = 0) -> (hue: Double, saturation: Double) {
        guard diameter > 0 else { return (fallbackHue, 0) }
        let dx = point.x - diameter / 2
        let dy = point.y - diameter / 2
        let distance = hypot(dx, dy)
        let hue = distance < 1e-8 ? fallbackHue : normalizedHue(atan2(dx, -dy) * 180 / .pi)
        return (hue, min(1, distance / (diameter / 2)))
    }

    public static func diskPoint(hue: Double, saturation: Double, diameter: Double) -> WheelPoint {
        let radians = normalizedHue(hue) * .pi / 180
        let distance = diameter / 2 * min(1, max(0, saturation))
        return WheelPoint(x: diameter / 2 + distance * sin(radians),
                          y: diameter / 2 - distance * cos(radians))
    }

    /// Lightness is 0 at the top, 1 at the bottom on either semicircle.
    public static func lightness(at point: WheelPoint, diameter: Double) -> (value: Double, leftArc: Bool) {
        guard diameter > 0 else { return (0.5, false) }
        let angle = normalizedHue(atan2(point.x - diameter/2, diameter/2 - point.y) * 180 / .pi)
        return ((angle <= 180 ? angle : 360 - angle) / 180, angle > 180)
    }

    /// The ring handle is centered in the colored band's thickness.
    public static func ringPoint(lightness: Double, leftArc: Bool, diameter: Double,
                                 bandWidth: Double) -> WheelPoint {
        let outerRadius = diameter / 2
        let radius = max(0, outerRadius - max(0, bandWidth) / 2)
        let angle = .pi * min(1, max(0, lightness)) * (leftArc ? -1 : 1)
        return WheelPoint(x: outerRadius + radius * sin(angle),
                          y: outerRadius - radius * cos(angle))
    }

    private static func normalizedHue(_ angle: Double) -> Double {
        (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
}

public struct PickedColor: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var color: SRGBColor
    public var pickedAt: Date
    public var isFavorite: Bool
    /// Display ICC profile name at capture time, not the original pixel gamut.
    public var displayProfileName: String?
    /// Encoded Display P3 components of the captured pixel, when available.
    /// This is the composited screen pixel, not the ICC profile of its source app.
    public var sourceP3: DisplayP3Color?

    public init(id: UUID = UUID(), color: SRGBColor, pickedAt: Date = .now,
                isFavorite: Bool = false, displayProfileName: String? = nil,
                sourceP3: DisplayP3Color? = nil) {
        self.id = id; self.color = color; self.pickedAt = pickedAt; self.isFavorite = isFavorite
        self.displayProfileName = displayProfileName
        self.sourceP3 = sourceP3
    }
}

public struct ColorHistory: Codable, Sendable {
    public private(set) var items: [PickedColor]
    public init(items: [PickedColor] = []) { self.items = items }

    public mutating func add(_ value: SRGBColor, limit: Int = 500, displayProfileName: String? = nil,
                             sourceP3: DisplayP3Color? = nil) {
        let previousIndex = items.firstIndex { item in
            item.color.rgbaBytes == value.rgbaBytes && item.sourceP3 == sourceP3
        }
        let previous = previousIndex.map { items.remove(at: $0) }
        // Provenance belongs to this capture. Never inherit the previous
        // display's profile when the current capture cannot identify it.
        items.insert(PickedColor(id: previous?.id ?? UUID(), color: value,
                                 isFavorite: previous?.isFavorite ?? false,
                                 displayProfileName: displayProfileName, sourceP3: sourceP3), at: 0)
        // Never silently discard favorited colors when enforcing history limit.
        while items.count > max(1, limit) {
            guard let index = items.lastIndex(where: { !$0.isFavorite }) else { break }
            items.remove(at: index)
        }
    }

    /// Insert an ordered harmony palette in one mutation, respecting existing
    /// deduplication, favorites and history limits. It has no screen ICC metadata.
    public mutating func addPalette(_ colors: [SRGBColor], limit: Int = 500) {
        for color in colors.reversed() { add(color, limit: limit) }
    }

    /// Removes one historical entry by stable identifier. No-op for stale UI IDs.
    @discardableResult
    public mutating func remove(id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        items.remove(at: index)
        return true
    }

    public mutating func toggleFavorite(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isFavorite.toggle()
    }
    public mutating func setFavorite(_ value: SRGBColor, favorite: Bool,
                                     sourceP3: DisplayP3Color? = nil) {
        if let index = items.firstIndex(where: {
            $0.color.rgbaBytes == value.rgbaBytes && $0.sourceP3 == sourceP3
        }) {
            items[index].isFavorite = favorite
        } else if favorite {
            items.insert(PickedColor(color: value, isFavorite: true, sourceP3: sourceP3), at: 0)
        }
    }

    public func isFavorite(_ value: SRGBColor, sourceP3: DisplayP3Color? = nil) -> Bool {
        items.contains { $0.color.rgbaBytes == value.rgbaBytes &&
            $0.sourceP3 == sourceP3 && $0.isFavorite }
    }

    /// Remove non-favorite history entries without discarding explicitly saved colors.
    public mutating func clearRecents() {
        items.removeAll { !$0.isFavorite }
    }

    public var favorites: [PickedColor] { items.filter(\.isFavorite) }
}

/// Shared filtering for the menu and history browser; case-insensitive and
/// independent from display formatting preferences.
public enum ColorHistoryQuery {
    public static func filter(_ entries: [PickedColor], text: String,
                              favoritesOnly: Bool = false) -> [PickedColor] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().replacingOccurrences(of: "#", with: "")
        return entries.filter { entry in
            guard !favoritesOnly || entry.isFavorite else { return false }
            guard !query.isEmpty else { return true }
            let hex = ColorFormatter.hex(entry.color)
            let rgb = entry.color.bytes.map(String.init).joined(separator: ", ")
            return hex.contains(query) || rgb.contains(query)
        }
    }
}
