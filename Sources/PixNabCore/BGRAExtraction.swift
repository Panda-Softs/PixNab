import Foundation

/// One production BGRA8 cropper. The source is a top-left-origin, tightly
/// described buffer with an explicit stride; output pixels remain BGRA8.
/// Calling code must supply sRGB bytes (e.g. ScreenCaptureKit configured sRGB).
public struct BGRAPatch: Sendable, Equatable {
    public let side: Int
    public let bytesPerRow: Int
    public let bytes: [UInt8]

    public var centerBGRA: (UInt8, UInt8, UInt8, UInt8)? {
        guard side > 0, bytesPerRow >= side * 4 else { return nil }
        let offset = (side / 2) * bytesPerRow + (side / 2) * 4
        guard offset + 3 < bytes.count else { return nil }
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }
}

public enum BGRAExtraction {
    /// Copies one patch, clamping every out-of-bounds coordinate to the nearest
    /// source pixel. Source memory must remain valid for the entire call.
    public static func extract(source: UnsafeRawBufferPointer,
                               width: Int, height: Int, sourceBytesPerRow: Int,
                               point: PixelPoint, radius: Int) -> BGRAPatch? {
        guard width > 0, height > 0, width <= Int.max / 4,
              sourceBytesPerRow >= width * 4,
              sourceBytesPerRow <= Int.max / height,
              source.count >= sourceBytesPerRow * height,
              point.x >= 0, point.x < width, point.y >= 0, point.y < height,
              radius >= 1, radius <= 512,
              let src = source.baseAddress else { return nil }

        let side = radius * 2 + 1
        let rowBytes = side * 4
        var output = [UInt8](repeating: 0, count: rowBytes * side)
        output.withUnsafeMutableBytes { destination in
            guard let dst = destination.baseAddress else { return }
            for y in 0..<side {
                let srcY = min(height - 1, max(0, point.y + y - radius))
                let sourceRow = src.advanced(by: srcY * sourceBytesPerRow)
                let destinationRow = dst.advanced(by: y * rowBytes)
                for x in 0..<side {
                    let srcX = min(width - 1, max(0, point.x + x - radius))
                    destinationRow.advanced(by: x * 4)
                        .copyMemory(from: sourceRow.advanced(by: srcX * 4), byteCount: 4)
                }
            }
        }
        return BGRAPatch(side: side, bytesPerRow: rowBytes, bytes: output)
    }
}
