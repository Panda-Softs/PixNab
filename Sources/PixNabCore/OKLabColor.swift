import Foundation

/// OKLab from linear-light sRGB (D65); no third-party color dependency.
/// This is an output encoding only: the sampled SRGBColor stays the single source of truth.
public struct OKLabColor: Equatable, Sendable {
    public let lightness: Double
    public let a: Double
    public let b: Double

    public var lch: (lightness: Double, chroma: Double, hue: Double) {
        let chroma = hypot(a, b)
        let angle = atan2(b, a) * 180 / .pi
        return (lightness, chroma, chroma < 0.000_000_01 ? 0 : (angle < 0 ? angle + 360 : angle))
    }

    public static func fromSRGB(_ color: SRGBColor) -> OKLabColor {
        func linearize(_ v: Double) -> Double {
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let r = linearize(color.red), g = linearize(color.green), b = linearize(color.blue)
        let l = cbrt(0.4122214708*r + 0.5363325363*g + 0.0514459929*b)
        let m = cbrt(0.2119034982*r + 0.6806995451*g + 0.1073969566*b)
        let s = cbrt(0.0883024619*r + 0.2817188376*g + 0.6299787005*b)
        return OKLabColor(
            lightness: 0.2104542553*l + 0.7936177850*m - 0.0040720468*s,
            a: 1.9779984951*l - 2.4285922050*m + 0.4505937099*s,
            b: 0.0259040371*l + 0.7827717662*m - 0.8086757660*s)
    }
}


/// CIE Lab using a D50 reference white, as required by CSS Color 4 `lab()`.
/// sRGB is decoded to linear light, transformed to D65 XYZ, then adapted to D50
/// using the standard Bradford matrix. This does not reconstruct source P3 data.
public struct CIELabColor: Equatable, Sendable {
    public let lightness: Double
    public let a: Double
    public let b: Double

    public init(lightness: Double, a: Double, b: Double) {
        self.lightness = lightness; self.a = a; self.b = b
    }

    /// Convert CSS Lab (D50) back into the app's canonical sRGB space.
    /// As with all SRGBColor inputs, values outside the sRGB gamut are clipped.
    public func toSRGB(alpha: Double = 1) -> SRGBColor {
        let fy = (lightness + 16) / 116
        let fx = fy + a / 500
        let fz = fy - b / 200
        func inverse(_ t: Double) -> Double {
            let delta = 6.0 / 29.0
            return t > delta ? t*t*t : 3*delta*delta*(t - 4.0/29.0)
        }
        let x = 0.96422 * inverse(fx)
        let y = inverse(fy)
        let z = 0.82521 * inverse(fz)
        // Inverse of the same D50-adapted sRGB matrix used by fromSRGB.
        let r = 3.1338561*x - 1.6168667*y - 0.4906146*z
        let g = -0.9787684*x + 1.9161415*y + 0.0334540*z
        let bl = 0.0719453*x - 0.2289914*y + 1.4052427*z
        func encode(_ v: Double) -> Double {
            v <= 0.0031308 ? 12.92*v : 1.055*pow(v, 1 / 2.4) - 0.055
        }
        return SRGBColor(red: encode(r), green: encode(g), blue: encode(bl), alpha: alpha)
    }

    public static func fromSRGB(_ color: SRGBColor) -> CIELabColor {
        func linear(_ v: Double) -> Double {
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let r = linear(color.red), g = linear(color.green), b = linear(color.blue)
        // Combined sRGB(D65) -> XYZ(D50) Bradford-adapted matrix.
        let x = 0.4360747*r + 0.3850649*g + 0.1430804*b
        let y = 0.2225045*r + 0.7168786*g + 0.0606169*b
        let z = 0.0139322*r + 0.0971045*g + 0.7141733*b
        func f(_ t: Double) -> Double {
            let delta = 6.0 / 29.0
            return t > delta*delta*delta ? cbrt(t) : t/(3*delta*delta) + 4.0/29.0
        }
        let fx = f(x / 0.96422), fy = f(y), fz = f(z / 0.82521)
        return CIELabColor(lightness: 116*fy - 16, a: 500*(fx-fy), b: 200*(fy-fz))
    }
}

extension OKLabColor {
    /// Inverse of the OKLab D65 transform. Out-of-gamut channels are clipped by
    /// SRGBColor at the single canonical color-storage boundary.
    public func toSRGB(alpha: Double = 1) -> SRGBColor {
        let l = pow(lightness + 0.3963377774*a + 0.2158037573*b, 3)
        let m = pow(lightness - 0.1055613458*a - 0.0638541728*b, 3)
        let s = pow(lightness - 0.0894841775*a - 1.2914855480*b, 3)
        let r = 4.0767416621*l - 3.3077115913*m + 0.2309699292*s
        let g = -1.2684380046*l + 2.6097574011*m - 0.3413193965*s
        let bl = -0.0041960863*l - 0.7034186147*m + 1.7076147010*s
        func encode(_ value: Double) -> Double {
            value <= 0.0031308 ? 12.92*value : 1.055*pow(value, 1.0/2.4) - 0.055
        }
        return SRGBColor(red: encode(r), green: encode(g), blue: encode(bl), alpha: alpha)
    }
}

/// CSS Display P3 uses D65 primaries and the same transfer function as sRGB.
/// Exporting an sRGB sample as P3 does NOT recover colors lost during capture.
public struct DisplayP3Color: Codable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red; self.green = green; self.blue = blue
    }

    public static func fromSRGB(_ value: SRGBColor) -> DisplayP3Color {
        let r = decode(value.red), g = decode(value.green), b = decode(value.blue)
        return DisplayP3Color(
            red: encode(0.8224619687*r + 0.1775380313*g),
            green: encode(0.0331941989*r + 0.9668058011*g),
            blue: encode(0.0170826307*r + 0.0723974407*g + 0.9105199286*b))
    }

    /// Unclamped, linear-light sRGB channels. Used both for export and to
    /// detect gamut clipping *before* SRGBColor clamps its stored components.
    /// Encoded RGB comparisons after clipping cannot detect lost P3 colors.
    private var linearSRGB: (red: Double, green: Double, blue: Double) {
        let r = Self.decode(red), g = Self.decode(green), b = Self.decode(blue)
        return (
            1.2249401763*r - 0.2249401763*g,
            -0.0420569547*r + 1.0420569547*g,
            -0.0196375546*r - 0.0786360456*g + 1.0982736002*b
        )
    }

    /// Indicates that an sRGB-only output cannot preserve this sampled color.
    /// The tolerance avoids classifying a round-tripped neutral as out of gamut
    /// solely because of matrix coefficient rounding.
    public var isOutsideSRGBGamut: Bool {
        let rgb = linearSRGB
        return [rgb.red, rgb.green, rgb.blue].contains { !$0.isFinite || $0 < -1e-6 || $0 > 1 + 1e-6 }
    }

    public func toSRGB(alpha: Double = 1) -> SRGBColor {
        let rgb = linearSRGB
        return SRGBColor(red: Self.encode(rgb.red), green: Self.encode(rgb.green),
                         blue: Self.encode(rgb.blue), alpha: alpha)
    }

    private static func decode(_ value: Double) -> Double {
        value <= 0.04045 ? value/12.92 : pow((value + 0.055)/1.055, 2.4)
    }
    private static func encode(_ value: Double) -> Double {
        value <= 0.0031308 ? 12.92*value : 1.055*pow(value, 1.0/2.4) - 0.055
    }
}
