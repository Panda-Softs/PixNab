import Foundation

/// CIEDE2000 (kL=kC=kH=1) for CIE Lab D50 values. Alpha is not a
/// colorimetric dimension; compare opaque colors against a common background
/// before using this metric if transparency is important.
public enum ColorDifference {
    public static func deltaE2000(_ first: CIELabColor, _ second: CIELabColor) -> Double {
        let l1 = first.lightness, l2 = second.lightness
        let c1 = hypot(first.a, first.b), c2 = hypot(second.a, second.b)
        let meanC = (c1 + c2) / 2
        let meanC7 = pow(meanC, 7)
        let g = 0.5 * (1 - sqrt(meanC7 / (meanC7 + pow(25.0, 7))))
        let a1 = (1 + g) * first.a, a2 = (1 + g) * second.a
        let cp1 = hypot(a1, first.b), cp2 = hypot(a2, second.b)
        func degrees(_ a: Double, _ b: Double) -> Double {
            let angle = atan2(b, a) * 180 / .pi
            return angle < 0 ? angle + 360 : angle
        }
        let h1 = degrees(a1, first.b), h2 = degrees(a2, second.b)
        let dL = l2 - l1, dC = cp2 - cp1
        let dh: Double
        if cp1 * cp2 < 1e-20 { dh = 0 }
        else if abs(h2 - h1) <= 180 { dh = h2 - h1 }
        else { dh = h2 - h1 + (h2 > h1 ? -360 : 360) }
        let dH = 2 * sqrt(cp1 * cp2) * sin(dh * .pi / 360)
        let meanL = (l1 + l2) / 2, meanCp = (cp1 + cp2) / 2
        let meanH: Double
        if cp1 * cp2 < 1e-20 { meanH = h1 + h2 }
        else if abs(h1 - h2) <= 180 { meanH = (h1 + h2) / 2 }
        else { meanH = (h1 + h2 + (h1 + h2 < 360 ? 360 : -360)) / 2 }
        func cosDegrees(_ degrees: Double) -> Double { cos(degrees * .pi / 180) }
        let t = 1 - 0.17 * cosDegrees(meanH - 30)
            + 0.24 * cosDegrees(2 * meanH)
            + 0.32 * cosDegrees(3 * meanH + 6)
            - 0.20 * cosDegrees(4 * meanH - 63)
        let deltaTheta = 30 * exp(-pow((meanH - 275) / 25, 2))
        let meanCp7 = pow(meanCp, 7)
        let rC = 2 * sqrt(meanCp7 / (meanCp7 + pow(25.0, 7)))
        let sL = 1 + 0.015 * pow(meanL - 50, 2) / sqrt(20 + pow(meanL - 50, 2))
        let sC = 1 + 0.045 * meanCp
        let sH = 1 + 0.015 * meanCp * t
        let rT = -sin(2 * deltaTheta * .pi / 180) * rC
        let x = dL / sL, y = dC / sC, z = dH / sH
        return sqrt(max(0, x*x + y*y + z*z + rT*y*z))
    }

    public static func deltaE2000(_ a: SRGBColor, _ b: SRGBColor,
                                   sourceP3A: DisplayP3Color? = nil,
                                   sourceP3B: DisplayP3Color? = nil) -> Double {
        deltaE2000(sourceP3A.map(CIELabColor.fromDisplayP3) ?? .fromSRGB(a),
                   sourceP3B.map(CIELabColor.fromDisplayP3) ?? .fromSRGB(b))
    }

    /// ΔEOK is an unweighted Euclidean distance in OKLab (typically 0...1).
    /// Unlike ΔE00 it is not a CIEDE2000 score and should not use its thresholds.
    public static func deltaEOK(_ a: SRGBColor, _ b: SRGBColor) -> Double {
        let x = OKLabColor.fromSRGB(a), y = OKLabColor.fromSRGB(b)
        return sqrt(pow(x.lightness - y.lightness, 2) + pow(x.a-y.a, 2) + pow(x.b-y.b, 2))
    }
}

public extension CIELabColor {
    /// Convert the *original* Display P3 sample to Lab D50 before any sRGB
    /// clipping, using the standard P3→XYZ(D65) matrix and Bradford adaptation.
    static func fromDisplayP3(_ p3: DisplayP3Color) -> CIELabColor {
        func decode(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        let r = decode(p3.red), g = decode(p3.green), b = decode(p3.blue)
        let x65 = 0.4865709486482162*r + 0.26566769316909306*g + 0.1982172852343625*b
        let y65 = 0.2289745640697488*r + 0.6917385218365064*g + 0.079286914093745*b
        let z65 = 0.04511338185890264*g + 1.043944368900976*b
        let x = 1.0479298208405488*x65 + 0.02294679334101908*y65 - 0.05019222954313557*z65
        let y = 0.02962781568815934*x65 + 0.990434484573249*y65 - 0.01707382502938514*z65
        let z = -0.009243058152591178*x65 + 0.015055144896577895*y65 + 0.7518742899580008*z65
        let delta = 6.0 / 29.0
        func f(_ t: Double) -> Double { t > delta*delta*delta ? cbrt(t) : t/(3*delta*delta) + 4.0/29.0 }
        let fx = f(x / 0.96422), fy = f(y), fz = f(z / 0.82521)
        return CIELabColor(lightness: 116*fy - 16, a: 500*(fx-fy), b: 200*(fy-fz))
    }
}

public enum ColorAccessibility {
    /// WCAG 2.x luminance ratio for opaque sRGB colors. This is not APCA.
    public static func contrastRatio(_ a: SRGBColor, _ b: SRGBColor) -> Double {
        func luminance(_ c: SRGBColor) -> Double {
            func linear(_ v: Double) -> Double { v <= 0.04045 ? v/12.92 : pow((v+0.055)/1.055, 2.4) }
            return 0.2126*linear(c.red) + 0.7152*linear(c.green) + 0.0722*linear(c.blue)
        }
        let la = luminance(a), lb = luminance(b)
        return (max(la,lb)+0.05)/(min(la,lb)+0.05)
    }
}

