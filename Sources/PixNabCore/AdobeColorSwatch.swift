import Foundation

/// Photoshop ACO version 1: RGB swatches without names or alpha.
/// ACO is independent of ASE; both use the same SRGBColor model.
public enum AdobeColorSwatch {
    public enum EncodingError: Error, Equatable { case tooManyColors }

    public static func encode(_ colors: [SRGBColor]) throws -> Data {
        guard colors.count <= Int(UInt16.max) else { throw EncodingError.tooManyColors }
        var output = Data()
        func append(_ number: UInt16) {
            output.append(UInt8(number >> 8))
            output.append(UInt8(number & 0xff))
        }
        append(1) // ACO version 1
        append(UInt16(colors.count))
        for color in colors {
            append(0) // color space: RGB
            for channel in [color.red, color.green, color.blue] {
                append(UInt16((channel * 65535).rounded()))
            }
            append(0) // unused channel
        }
        return output
    }
}
