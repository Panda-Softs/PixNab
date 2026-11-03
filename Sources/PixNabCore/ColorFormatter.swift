import Foundation

public enum ColorOutputFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case genericHex, genericRGB8, genericDecimal, genericHSB, cssHex, cssHexAlpha, cssRGB, cssRGBA, cssHSL, cssHSLA
    case cssModernRGB, cssModernHSL, cssDisplayP3, cssLab, cssLCH, cssOKLab, cssOKLCH, cssHWB, swiftNSColor, swiftNSColorDeviceRGB, swiftNSColorHSB, swiftUIColor, swiftUIColorHSB, swiftUI, objcNSColor, cgColor, android, kotlin, java, python, rust, dotNet, openGL

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .genericHex: return "Generic Hex"
        case .genericRGB8: return "Generic 8-bit"
        case .genericDecimal: return "Generic Decimal"
        case .genericHSB: return "Generic HSB"
        case .cssHex: return "CSS Hex"
        case .cssHexAlpha: return "CSS Hex Alpha"
        case .cssRGB: return "CSS RGB"
        case .cssRGBA: return "CSS RGBA"
        case .cssHSL: return "CSS HSL"
        case .cssHSLA: return "CSS HSLA"
        case .cssModernRGB: return "CSS RGB (modern)"
        case .cssModernHSL: return "CSS HSL (modern)"
        case .cssDisplayP3: return "CSS Display P3"
        case .cssLab: return "CSS Lab (D50)"
        case .cssLCH: return "CSS LCH (D50)"
        case .cssOKLab: return "CSS OKLab"
        case .cssOKLCH: return "CSS OKLCH"
        case .cssHWB: return "CSS HWB"
        case .swiftNSColor: return "Swift NSColor RGB"
        case .swiftNSColorDeviceRGB: return "Swift NSColor Device RGB"
        case .swiftNSColorHSB: return "Swift NSColor HSB"
        case .swiftUIColor: return "Swift UIColor RGB"
        case .swiftUIColorHSB: return "Swift UIColor HSB"
        case .swiftUI: return "SwiftUI Color"
        case .objcNSColor: return "Objective-C NSColor"
        case .cgColor: return "Core Graphics CGColor"
        case .android: return "Android Color"
        case .kotlin: return "Kotlin Android Color"
        case .python: return "Python RGB tuple"
        case .rust: return "Rust RGB tuple"
        case .java: return "Java Color"
        case .dotNet: return ".NET Color"
        case .openGL: return "OpenGL"
        }
    }
}

public struct FormattingOptions: Codable, Sendable, Equatable {
    public var uppercaseHex = false
    public var hexPrefix = ""
    public var cssShorthand = false
    public var decimalPlaces = 3
    public var trimTrailingZeros = false
    public var commaSeparated = true
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case uppercaseHex, hexPrefix, cssShorthand, decimalPlaces, trimTrailingZeros, commaSeparated
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        uppercaseHex = try values.decodeIfPresent(Bool.self, forKey: .uppercaseHex) ?? uppercaseHex
        hexPrefix = try values.decodeIfPresent(String.self, forKey: .hexPrefix) ?? hexPrefix
        cssShorthand = try values.decodeIfPresent(Bool.self, forKey: .cssShorthand) ?? cssShorthand
        decimalPlaces = max(0, min(8, try values.decodeIfPresent(Int.self, forKey: .decimalPlaces) ?? decimalPlaces))
        trimTrailingZeros = try values.decodeIfPresent(Bool.self, forKey: .trimTrailingZeros) ?? trimTrailingZeros
        commaSeparated = try values.decodeIfPresent(Bool.self, forKey: .commaSeparated) ?? commaSeparated
    }
}

public enum ColorFormatter {
    public static func format(_ color: SRGBColor, as format: ColorOutputFormat,
                              options: FormattingOptions = .init(),
                              sourceP3: DisplayP3Color? = nil) -> String {
        let b = color.bytes, h = color.hsl
        let brightness = max(color.red, color.green, color.blue)
        let saturationHSB = brightness == 0 ? 0 : (brightness - min(color.red, color.green, color.blue)) / brightness
        let channelSeparator = options.commaSeparated ? ", " : " "
        let a = decimal(color.alpha, options: options)
        func dec(_ x: Double) -> String { decimal(x, options: options) }
        let hexBase = hex(color, uppercase: options.uppercaseHex)
        switch format {
        case .genericHex: return options.hexPrefix + hexBase
        case .genericRGB8: return b.map(String.init).joined(separator: channelSeparator)
        case .genericDecimal: return [color.red, color.green, color.blue].map(dec).joined(separator: channelSeparator)
        case .genericHSB: return [h.h / 360, saturationHSB, brightness].map(dec).joined(separator: channelSeparator)
        case .cssHex:
            var output = hexBase
            if options.cssShorthand, output.count == 6 {
                let c = Array(output)
                if c[0] == c[1], c[2] == c[3], c[4] == c[5] {
                    output = String([c[0], c[2], c[4]])
                }
            }
            return "#" + output
        case .cssHexAlpha:
            return "#" + hexBase + String(format: options.uppercaseHex ? "%02X" : "%02x", color.rgbaBytes[3])
        case .cssRGB: return "rgb(\(b[0]), \(b[1]), \(b[2]))"
        case .cssRGBA: return "rgba(\(b[0]), \(b[1]), \(b[2]), \(a))"
        case .cssHSL: return "hsl(\(Int(h.h.rounded())), \(Int((h.s * 100).rounded()))%, \(Int((h.l * 100).rounded()))%)"
        case .cssHSLA: return "hsla(\(Int(h.h.rounded())), \(Int((h.s * 100).rounded()))%, \(Int((h.l * 100).rounded()))%, \(a))"
        case .cssModernRGB:
            return "rgb(\(b[0]) \(b[1]) \(b[2]) / \(a))"
        case .cssModernHSL:
            return "hsl(\(Int(h.h.rounded())) \(Int((h.s * 100).rounded()))% \(Int((h.l * 100).rounded()))% / \(a))"
        case .cssDisplayP3:
            let p3 = sourceP3 ?? DisplayP3Color.fromSRGB(color)
            return "color(display-p3 \(dec(p3.red)) \(dec(p3.green)) \(dec(p3.blue)) / \(a))"
        case .cssLab:
            let lab = CIELabColor.fromSRGB(color)
            return "lab(\(dec(lab.lightness))% \(dec(lab.a)) \(dec(lab.b)) / \(a))"
        case .cssLCH:
            let lab = CIELabColor.fromSRGB(color)
            let chroma = hypot(lab.a, lab.b)
            let angle = atan2(lab.b, lab.a) * 180 / .pi
            let hue = chroma < 0.00000001 ? 0 : (angle < 0 ? angle + 360 : angle)
            return "lch(\(dec(lab.lightness))% \(dec(chroma)) \(dec(hue)) / \(a))"
        case .cssOKLab:
            let lab = OKLabColor.fromSRGB(color)
            return "oklab(\(dec(lab.lightness * 100))% \(dec(lab.a)) \(dec(lab.b)) / \(a))"
        case .cssOKLCH:
            let lch = OKLabColor.fromSRGB(color).lch
            return "oklch(\(dec(lch.lightness * 100))% \(dec(lch.chroma)) \(dec(lch.hue)) / \(a))"
        case .cssHWB:
            let white = min(color.red, color.green, color.blue)
            let black = 1 - max(color.red, color.green, color.blue)
            return "hwb(\(dec(h.h)) \(dec(white * 100))% \(dec(black * 100))% / \(a))"
        case .swiftNSColor:
            return "NSColor(srgbRed: \(dec(color.red)), green: \(dec(color.green)), blue: \(dec(color.blue)), alpha: \(a))"
        case .swiftNSColorDeviceRGB:
            return "NSColor(deviceRed: \(dec(color.red)), green: \(dec(color.green)), blue: \(dec(color.blue)), alpha: \(a))"
        case .swiftNSColorHSB:
            return "NSColor(calibratedHue: \(dec(h.h / 360)), saturation: \(dec(saturationHSB)), brightness: \(dec(brightness)), alpha: \(a))"
        case .swiftUIColor:
            return "UIColor(red: \(dec(color.red)), green: \(dec(color.green)), blue: \(dec(color.blue)), alpha: \(a))"
        case .swiftUIColorHSB:
            return "UIColor(hue: \(dec(h.h / 360)), saturation: \(dec(saturationHSB)), brightness: \(dec(brightness)), alpha: \(a))"
        case .swiftUI:
            return "Color(.sRGB, red: \(dec(color.red)), green: \(dec(color.green)), blue: \(dec(color.blue)), opacity: \(a))"
        case .objcNSColor:
            return "[NSColor colorWithSRGBRed:\(dec(color.red)) green:\(dec(color.green)) blue:\(dec(color.blue)) alpha:\(a)]"
        case .cgColor:
            return "CGColor(srgbRed: \(dec(color.red)), green: \(dec(color.green)), blue: \(dec(color.blue)), alpha: \(a))"
        case .android: return "Color.rgb(\(b[0]), \(b[1]), \(b[2]))"
        case .kotlin: return "android.graphics.Color.rgb(\(b[0]), \(b[1]), \(b[2]))"
        case .python: return "(\(b[0]), \(b[1]), \(b[2]))"
        case .rust: return "(\(b[0])u8, \(b[1])u8, \(b[2])u8)"
        case .java: return "new Color(\(b[0]), \(b[1]), \(b[2]))"
        case .dotNet: return "Color.FromArgb(\(b[0]), \(b[1]), \(b[2]))"
        case .openGL: return "glColor4f(\(dec(color.red)), \(dec(color.green)), \(dec(color.blue)), \(a))"
        }
    }

    public static func hex(_ color: SRGBColor, uppercase: Bool = false) -> String {
        let value = color.bytes.map { String(format: "%02x", $0) }.joined()
        return uppercase ? value.uppercased() : value
    }

    private static func decimal(_ value: Double, options: FormattingOptions) -> String {
        let digits = min(8, max(0, options.decimalPlaces))
        let result = String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), digits, value)
        guard options.trimTrailingZeros, result.contains(".") else { return result }
        var stripped = result
        while stripped.last == "0" { stripped.removeLast() }
        if stripped.last == "." { stripped.removeLast() }
        return stripped
    }
}
