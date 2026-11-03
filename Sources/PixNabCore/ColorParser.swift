import Foundation

/// Shared, strict color input parser. Only supported representations are accepted;
/// malformed or ambiguous strings never silently change the active selection.
public enum ColorParser {
    public static func parse(_ input: String) -> SRGBColor? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let hex = parseHex(text) { return hex }
        // CSS function and color-space identifiers are ASCII case-insensitive.
        let css = text.lowercased()
        return parseCSSRGB(css) ?? parseCSSHSL(css) ?? parseCSSLab(css)
            ?? parseCSSLCH(css) ?? parseCSSOKLab(css) ?? parseCSSOKLCH(css) ?? parseCSSHWB(css)
            ?? parseCSSDisplayP3(css)
    }

    /// Retains the wide-gamut CSS input alongside its sRGB fallback. The normal
    /// parse API remains source-compatible for clients that only need sRGB.
    public struct ParsedColor: Sendable {
        public let color: SRGBColor
        public let sourceP3: DisplayP3Color?
    }

    public static func parseDetailed(_ input: String) -> ParsedColor? {
        let css = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let p3 = parseCSSDisplayP3Detailed(css) { return p3 }
        guard let fallback = parse(input) else { return nil }
        return ParsedColor(color: fallback, sourceP3: nil)
    }

    public static func parseHex(_ input: String) -> SRGBColor? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: String
        if text.hasPrefix("#") { value = String(text.dropFirst()) }
        else if text.lowercased().hasPrefix("0x") { value = String(text.dropFirst(2)) }
        else { value = text }

        guard [3, 4, 6, 8].contains(value.count),
              value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { return nil }
        let digits = Array(value)
        let numbers: [Int]
        if value.count <= 4 {
            numbers = digits.compactMap { Int(String(repeating: $0, count: 2), radix: 16) }
        } else {
            numbers = stride(from: 0, to: value.count, by: 2).compactMap {
                Int(String(digits[$0...($0 + 1)]), radix: 16)
            }
        }
        guard numbers.count == (value.count <= 4 ? value.count : value.count / 2) else { return nil }
        return SRGBColor(red8: numbers[0], green8: numbers[1], blue8: numbers[2],
                        alpha: numbers.count == 4 ? Double(numbers[3]) / 255.0 : 1)
    }

    /// CSS Color 3 hsl()/hsla() (comma-separated) and CSS Color 4 hsl() (space-separated).
    /// The hue is in degrees; saturation and lightness are percentages.
    private static func parseCSSHSL(_ input: String) -> SRGBColor? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let alphaFunction = text.hasPrefix("hsla(")
        guard (alphaFunction || text.hasPrefix("hsl(")), text.hasSuffix(")"),
              let opening = text.firstIndex(of: "(") else { return nil }
        let raw = String(text[text.index(after: opening)..<text.index(before: text.endIndex)])
        let oldSyntax = raw.contains(",")
        let components: [String]
        if oldSyntax {
            components = raw.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            components = raw.replacingOccurrences(of: "/", with: " / ")
                .split(whereSeparator: { $0.isWhitespace }).map(String.init)
        }
        if oldSyntax {
            guard components.count == (alphaFunction ? 4 : 3) else { return nil }
        } else {
            guard components.count == 3 || components.count == 5,
                  (!alphaFunction || components.count == 5) else { return nil }
            if components.count == 5 && components[3] != "/" { return nil }
        }
        guard let rawHue = degrees(components[0]),
              let sat = percentage(components[1]), let light = percentage(components[2]) else { return nil }
        let alphaIndex = oldSyntax ? 3 : 4
        let alpha: Double
        if components.count > alphaIndex {
            guard let a = alphaComponent(components[alphaIndex]) else { return nil }
            alpha = a
        } else { alpha = 1 }
        return SRGBColor(hue: rawHue, saturation: sat / 100,
                         lightness: light / 100, alpha: alpha)
    }

    /// CSS Color 4 lab(L% a b / alpha), emitted by the shared formatter.
    /// Reject non-finite numbers and malformed or mixed separator syntax.
    private static func parseCSSLab(_ input: String) -> SRGBColor? {
        let text = input.lowercased()
        guard text.hasPrefix("lab("), text.hasSuffix(")") else { return nil }
        let raw = text.dropFirst(4).dropLast()
        let parts = raw.replacingOccurrences(of: "/", with: " / ")
            .split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count == 3 || (parts.count == 5 && parts[3] == "/"),
              parts[0].hasSuffix("%"),
              let lightness = Double(parts[0].dropLast()), lightness.isFinite,
              (0...100).contains(lightness),
              let a = Double(parts[1]), a.isFinite,
              let b = Double(parts[2]), b.isFinite else { return nil }
        let alpha: Double
        if parts.count == 5 {
            guard let value = alphaComponent(parts[4]) else { return nil }
            alpha = value
        } else { alpha = 1 }
        return CIELabColor(lightness: lightness, a: a, b: b).toSRGB(alpha: alpha)
    }

    /// CSS Color 4 OKLab, OKLCH and HWB share the strict separator/alpha policy
    /// of the existing CSS Lab parser. Angles are in degrees, as emitted by PixNab.
    private static func functionalComponents(_ input: String, prefix: String) -> [String]? {
        guard input.hasPrefix(prefix + "("), input.hasSuffix(")") else { return nil }
        let raw = input.dropFirst(prefix.count + 1).dropLast()
        guard !raw.contains(",") else { return nil }
        let parts = raw.replacingOccurrences(of: "/", with: " / ")
            .split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count == 3 || (parts.count == 5 && parts[3] == "/") else { return nil }
        return parts
    }

    private static func functionalAlpha(_ parts: [String]) -> Double? {
        parts.count == 3 ? 1 : alphaComponent(parts[4])
    }

    private static func parseCSSLCH(_ input: String) -> SRGBColor? {
        guard let parts = functionalComponents(input, prefix: "lch"),
              let l = percentage(parts[0]),
              let chroma = Double(parts[1]), chroma.isFinite, chroma >= 0,
              let hue = degrees(parts[2]),
              let alpha = functionalAlpha(parts) else { return nil }
        let radians = hue * .pi / 180
        return CIELabColor(lightness: l, a: chroma*cos(radians),
                           b: chroma*sin(radians)).toSRGB(alpha: alpha)
    }

    private static func parseCSSOKLab(_ input: String) -> SRGBColor? {
        guard let parts = functionalComponents(input, prefix: "oklab"),
              let l = percentage(parts[0]),
              let a = Double(parts[1]), a.isFinite,
              let b = Double(parts[2]), b.isFinite,
              let alpha = functionalAlpha(parts) else { return nil }
        return OKLabColor(lightness: l/100, a: a, b: b).toSRGB(alpha: alpha)
    }

    private static func parseCSSOKLCH(_ input: String) -> SRGBColor? {
        guard let parts = functionalComponents(input, prefix: "oklch"),
              let l = percentage(parts[0]),
              let chroma = Double(parts[1]), chroma.isFinite, chroma >= 0,
              let hue = degrees(parts[2]),
              let alpha = functionalAlpha(parts) else { return nil }
        let radians = hue * .pi / 180
        return OKLabColor(lightness: l/100, a: chroma*cos(radians),
                          b: chroma*sin(radians)).toSRGB(alpha: alpha)
    }

    private static func parseCSSHWB(_ input: String) -> SRGBColor? {
        guard let parts = functionalComponents(input, prefix: "hwb"),
              let hue = degrees(parts[0]),
              let white = percentage(parts[1]),
              let black = percentage(parts[2]),
              let alpha = functionalAlpha(parts) else { return nil }
        let w = white/100, bl = black/100
        if w + bl >= 1 {
            let gray = w/(w + bl)
            return SRGBColor(red: gray, green: gray, blue: gray, alpha: alpha)
        }
        // Reuse the HSL hue wheel instead of maintaining another one.
        guard let pure = parseCSSHSL("hsl(\(hue) 100% 50%)") else { return nil }
        return SRGBColor(red: pure.red*(1-w-bl)+w,
                         green: pure.green*(1-w-bl)+w,
                         blue: pure.blue*(1-w-bl)+w, alpha: alpha)
    }

    private static func parseCSSDisplayP3(_ input: String) -> SRGBColor? {
        parseCSSDisplayP3Detailed(input)?.color
    }

    private static func parseCSSDisplayP3Detailed(_ input: String) -> ParsedColor? {
        guard input.hasPrefix("color("), input.hasSuffix(")") else { return nil }
        let raw = String(input.dropFirst(6).dropLast())
        let parts = raw.replacingOccurrences(of: "/", with: " / ")
            .split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count == 4 || (parts.count == 6 && parts[4] == "/"),
              parts[0] == "display-p3",
              let r = p3Component(parts[1]),
              let g = p3Component(parts[2]),
              let b = p3Component(parts[3]),
              let alpha = parts.count == 6 ? alphaComponent(parts[5]) : 1 else { return nil }
        let p3 = DisplayP3Color(red: r, green: g, blue: b)
        return ParsedColor(color: p3.toSRGB(alpha: alpha), sourceP3: p3)
    }

    /// CSS color(display-p3 ...) accepts unitless channels or percentages;
    /// unlike byte RGB(), percentages are relative to normalized 0...1.
    private static func p3Component(_ input: String) -> Double? {
        if input.hasSuffix("%") {
            guard let value = Double(input.dropLast()), value.isFinite else { return nil }
            return value / 100
        }
        guard let value = Double(input), value.isFinite else { return nil }
        return value
    }

    private static func degrees(_ input: String) -> Double? {
        let units: [(suffix: String, scale: Double)] = [
            ("turn", 360), ("grad", 0.9), ("rad", 180 / .pi), ("deg", 1)
        ]
        for unit in units where input.hasSuffix(unit.suffix) {
            guard let number = Double(input.dropLast(unit.suffix.count)), number.isFinite else { return nil }
            return number * unit.scale
        }
        guard let number = Double(input), number.isFinite else { return nil }
        return number
    }

    private static func percentage(_ text: String) -> Double? {
        guard text.hasSuffix("%"), let number = Double(text.dropLast()),
              number.isFinite, (0...100).contains(number) else { return nil }
        return number
    }

    private static func parseCSSRGB(_ input: String) -> SRGBColor? {
        let lower = input.lowercased()
        let alphaFunction = lower.hasPrefix("rgba(")
        guard alphaFunction || lower.hasPrefix("rgb("), input.last == ")",
              let opening = lower.firstIndex(of: "(") else { return nil }
        let raw = String(lower[lower.index(after: opening)..<lower.index(before: lower.endIndex)])
        let legacy = raw.contains(",")
        let components: [String]
        if legacy {
            components = raw.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == (alphaFunction ? 4 : 3) else { return nil }
        } else {
            components = raw.replacingOccurrences(of: "/", with: " / ")
                .split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard components.count == 3 || components.count == 5,
                  (!alphaFunction || components.count == 5) else { return nil }
            if components.count == 5 && components[3] != "/" { return nil }
        }
        let channels = components.prefix(3).compactMap(rgbComponent)
        guard channels.count == 3 else { return nil }
        let alphaIndex = legacy ? 3 : 4
        let alpha: Double
        if components.count > alphaIndex {
            guard let a = alphaComponent(components[alphaIndex]) else { return nil }
            alpha = a
        } else { alpha = 1 }
        return SRGBColor(red8: channels[0], green8: channels[1], blue8: channels[2], alpha: alpha)
    }

    private static func rgbComponent(_ input: String) -> Int? {
        if input.hasSuffix("%") {
            guard let percent = percentage(input) else { return nil }
            return Int((percent * 255 / 100).rounded())
        }
        guard let byte = Int(input), (0...255).contains(byte) else { return nil }
        return byte
    }

    private static func alphaComponent(_ input: String) -> Double? {
        if input.hasSuffix("%") {
            guard let percent = percentage(input) else { return nil }
            return percent / 100
        }
        guard let value = Double(input), value.isFinite, (0...1).contains(value) else { return nil }
        return value
    }
}
