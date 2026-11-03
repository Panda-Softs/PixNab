import Foundation

public enum ColorScaleFormat: String, CaseIterable, Sendable {
    case css, json, swiftUI
}

public struct ColorScaleStep: Equatable, Sendable {
    public let number: Int
    public let color: SRGBColor
}

/// A bounded sRGB scale based on OKLCH. At 500 the source is retained exactly;
/// other steps vary OKLCH lightness and binary-search chroma *before* clipping.
/// This is not CSS Color 4's normative local-MINDE mapping algorithm.
public enum ColorScaleGenerator {
    public static let levels = [50,100,200,300,400,500,600,700,800,900,950]

    public static func generate(from base: SRGBColor) -> [ColorScaleStep] {
        let original = OKLabColor.fromSRGB(base).lch
        let high = max(0.985, original.lightness)
        let low = min(0.12, original.lightness)
        return levels.enumerated().map { index, level in
            guard index != 5 else { return ColorScaleStep(number: level, color: base) }
            let t = abs(Double(index - 5)) / 5
            let l = index < 5
                ? original.lightness + (high - original.lightness) * pow(t, 1.15)
                : original.lightness - (original.lightness - low) * pow(t, 1.05)
            let chroma = original.chroma * (1 - 0.42 * pow(t, 1.2))
            return ColorScaleStep(number: level, color: mapped(l: l, c: chroma,
                                                               h: original.hue, alpha: base.alpha))
        }
    }

    /// Returns linear-light OKLab RGB encoding *without* clipping for reliable
    /// gamut membership tests. SRGBColor clamps only after the search finishes.
    private static func encoded(l: Double, c: Double, h: Double) -> (Double, Double, Double) {
        let angle = h * .pi / 180
        let a = c*cos(angle), b = c*sin(angle)
        let ll = pow(l + 0.3963377774*a + 0.2158037573*b, 3)
        let m = pow(l - 0.1055613458*a - 0.0638541728*b, 3)
        let s = pow(l - 0.0894841775*a - 1.2914855480*b, 3)
        let r = 4.0767416621*ll - 3.3077115913*m + 0.2309699292*s
        let g = -1.2684380046*ll + 2.6097574011*m - 0.3413193965*s
        let bl = -0.0041960863*ll - 0.7034186147*m + 1.7076147010*s
        func gamma(_ x: Double) -> Double { x <= 0.0031308 ? 12.92*x : 1.055*pow(x, 1/2.4)-0.055 }
        return (gamma(r),gamma(g),gamma(bl))
    }

    private static func mapped(l: Double, c: Double, h: Double, alpha: Double) -> SRGBColor {
        if l >= 1 { return SRGBColor(red: 1, green: 1, blue: 1, alpha: alpha) }
        if l <= 0 { return SRGBColor(red: 0, green: 0, blue: 0, alpha: alpha) }
        func inGamut(_ rgb: (Double, Double, Double)) -> Bool {
            [rgb.0,rgb.1,rgb.2].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }
        }
        var lo = 0.0, hi = max(0, c)
        if !inGamut(encoded(l: l,c: hi,h: h)) {
            for _ in 0..<28 {
                let mid = (lo+hi)/2
                if inGamut(encoded(l: l,c: mid,h: h)) { lo = mid } else { hi = mid }
            }
        } else { lo = hi }
        let rgb = encoded(l: l,c: lo,h: h)
        return SRGBColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: alpha)
    }

    public static func export(_ steps: [ColorScaleStep], name: String, as format: ColorScaleFormat) -> String {
        let slug = slugify(name)
        func hex(_ color: SRGBColor) -> String {
            ColorFormatter.format(color, as: color.alpha < 0.999999 ? .cssHexAlpha : .cssHex)
        }
        switch format {
        case .css:
            return ":root {\n" + steps.map { "  --\(slug)-\($0.number): \(hex($0.color));" }.joined(separator: "\n") + "\n}"
        case .json:
            // Safe names: only a-z, 0-9 and '-'. No unescaped user text.
            return "{\n  \"\(slug)\": {\n" + steps.map {
                "    \"\($0.number)\": \"\(hex($0.color))\""
            }.joined(separator: ",\n") + "\n  }\n}"
        case .swiftUI:
            let identifier = "palette" + slug.split(separator: "-").map { $0.capitalized }.joined()
            return "import SwiftUI\n\nenum \(identifier) {\n" + steps.map {
                String(format: "    static let shade%d = Color(.sRGB, red: %.6f, green: %.6f, blue: %.6f, opacity: %.6f)",
                       $0.number, $0.color.red, $0.color.green, $0.color.blue, $0.color.alpha)
            }.joined(separator: "\n") + "\n}"
        }
    }

    public static func slugify(_ name: String) -> String {
        let latin = name.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let parts = latin.lowercased().split { !$0.isASCII || !($0.isLetter || $0.isNumber) }
        let slug = parts.joined(separator: "-")
        return String(slug.prefix(60)).trimmingCharacters(in: CharacterSet(charactersIn: "-")) == ""
            ? "color" : String(slug.prefix(60)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}


/// Semantic design tokens from any named palette, with stable collision-safe
/// role keys. CSS includes P3 overrides only for swatches with genuine original
/// P3 values; otherwise colors remain sRGB without falsely claiming P3 origin.
public enum PaletteTokenExporter {
    public static func export(_ swatches: [PaletteSwatch], name: String,
                              as format: ColorScaleFormat) -> String {
        let prefix = ColorScaleGenerator.slugify(name)
        var used = Set<String>()
        let entries: [(key: String, swatch: PaletteSwatch)] = swatches.map { swatch in
            let slug = ColorScaleGenerator.slugify(swatch.name)
            var key = slug
            var counter = 2
            while used.contains(key) {
                key = "\(slug)-\(counter)"
                counter += 1
            }
            used.insert(key)
            return (key, swatch)
        }
        func hex(_ color: SRGBColor) -> String {
            color.alpha < 0.999999
                ? ColorFormatter.format(color, as: .cssHexAlpha)
                : ColorFormatter.format(color, as: .cssHex)
        }
        switch format {
        case .css:
            var result = ":root {\n" + entries.map {
                "  --\(prefix)-\($0.key): \(hex($0.swatch.color));"
            }.joined(separator: "\n") + "\n}"
            let wide = entries.compactMap { item -> String? in
                guard let p3 = item.swatch.sourceP3 else { return nil }
                return "    --\(prefix)-\(item.key): \(ColorFormatter.format(item.swatch.color, as: .cssDisplayP3, sourceP3: p3));"
            }
            if !wide.isEmpty {
                result += "\n\n@supports (color: color(display-p3 1 0 0)) {\n  :root {\n"
                    + wide.joined(separator: "\n") + "\n  }\n}"
            }
            return result
        case .json:
            let pairs = entries.map { (key: $0.key, value: hex($0.swatch.color)) }
            // Generated slugs are safe JSON keys, values are controlled hex.
            return "{\n  \"\(prefix)\": {\n" + pairs.map {
                "    \"\($0.key)\": \"\($0.value)\""
            }.joined(separator: ",\n") + "\n  }\n}"
        case .swiftUI:
            let identifier = "palette" + prefix.split(separator: "-").map { $0.capitalized }.joined()
            return "import SwiftUI\n\nenum \(identifier) {\n" + entries.map { item in
                let c = item.swatch.color
                let identifier = "shade" + item.key.split(separator: "-").map { $0.capitalized }.joined()
                if let p3 = item.swatch.sourceP3 {
                    return String(format: "    static let %@ = Color(.displayP3, red: %.6f, green: %.6f, blue: %.6f, opacity: %.6f)",
                                  identifier, p3.red, p3.green, p3.blue, c.alpha)
                }
                return String(format: "    static let %@ = Color(.sRGB, red: %.6f, green: %.6f, blue: %.6f, opacity: %.6f)",
                              identifier, c.red, c.green, c.blue, c.alpha)
            }.joined(separator: "\n") + "\n}"
        }
    }
}

