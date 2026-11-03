import Foundation

/// A named RGB swatch. ASE stores RGB as three 32-bit floats and does not
/// include alpha; importing apps will receive the uncomposited sRGB channels.
public struct AdobeSwatch: Equatable, Sendable {
    public let name: String
    public let color: SRGBColor

    public init(name: String, color: SRGBColor) {
        self.name = name
        self.color = color
    }
}

/// Exports Adobe Swatch Exchange 1.0, a simple interoperable file format for
/// solid colors. Both Photoshop and Illustrator can import these libraries.
/// There is no dependency on an installed Adobe application.
public enum AdobeSwatchExchange {
    public static func encode(_ swatches: [AdobeSwatch]) -> Data {
        var file = Data("ASEF".utf8)
        file.appendBigEndian(UInt16(1)) // major version
        file.appendBigEndian(UInt16(0)) // minor version
        file.appendBigEndian(UInt32(min(swatches.count, Int(UInt32.max))))
        for swatch in swatches {
            var block = Data()
            // Prefix in Unicode scalar units to avoid splitting surrogate pairs.
            let name = String(swatch.name.prefix(120))
            let codeUnits = Array(name.utf16)
            block.appendBigEndian(UInt16(codeUnits.count + 1)) // includes null terminator
            for unit in codeUnits { block.appendBigEndian(unit) }
            block.appendBigEndian(UInt16(0))
            block.append(contentsOf: Array("RGB ".utf8))
            for channel in [swatch.color.red, swatch.color.green, swatch.color.blue] {
                block.appendBigEndian(Float(channel).bitPattern)
            }
            block.appendBigEndian(UInt16(0)) // global color, not spot or normal
            file.appendBigEndian(UInt16(0x0001)) // color entry block
            file.appendBigEndian(UInt32(block.count))
            file.append(block)
        }
        return file
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value))
    }
    mutating func appendBigEndian(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value >> 24))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value))
    }
}
