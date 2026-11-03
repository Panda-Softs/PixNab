import Foundation
import Testing
@testable import PixNabCore

@Suite struct ProductionBGRATests {
    private func fixture(width: Int, height: Int, padding: Int) -> (pixels: [UInt8], stride: Int) {
        let stride = width * 4 + padding
        var source = [UInt8](repeating: 0xEE, count: stride * height)
        for y in 0..<height {
            for x in 0..<width {
                let i = y * stride + x * 4
                source[i] = UInt8(x % 256)                 // B
                source[i + 1] = UInt8(y % 256)             // G
                source[i + 2] = UInt8((x + y) % 256)       // R
                source[i + 3] = 255                       // A
            }
        }
        return (source, stride)
    }

    @Test func testExactPixelsAndCenterAcrossEdgesAndStrides() {
        for (width, height, padding) in [(1, 1, 0), (7, 5, 12), (16, 10, 32)] {
            let (pixels, stride) = fixture(width: width, height: height, padding: padding)
            for radius in [1, 2, 6, 22] {
                let points = [PixelPoint(x: 0, y: 0), PixelPoint(x: width - 1, y: height - 1),
                              PixelPoint(x: width / 2, y: height / 2)]
                for point in points {
                    let patch = pixels.withUnsafeBytes { source in
                        BGRAExtraction.extract(source: source, width: width, height: height,
                            sourceBytesPerRow: stride, point: point, radius: radius)
                    }
                    guard let patch else { Issue.record("Missing patch"); continue }
                    let side = 2 * radius + 1
                    #expect(patch.side == side)
                    #expect(patch.bytesPerRow == side * 4)
                    #expect(patch.bytes.count == side * side * 4)
                    for y in 0..<side {
                        for x in 0..<side {
                            let srcX = min(width - 1, max(0, point.x + x - radius))
                            let srcY = min(height - 1, max(0, point.y + y - radius))
                            let offset = (y * side + x) * 4
                            #expect(Array(patch.bytes[offset..<offset + 4]) == [UInt8(srcX % 256), UInt8(srcY % 256), UInt8((srcX + srcY) % 256), 255])
                        }
                    }
                    #expect(patch.centerBGRA?.0 == UInt8(point.x % 256))
                    #expect(patch.centerBGRA?.1 == UInt8(point.y % 256))
                }
            }
        }
    }

    @Test func testBadInputsAreRejectedWithoutReadingMemory() {
        let (data, stride) = fixture(width: 5, height: 5, padding: 16)
        func extract(width: Int = 5, height: Int = 5, rowStride: Int? = nil,
                     point: PixelPoint = PixelPoint(x: 2, y: 2), radius: Int = 2) -> BGRAPatch? {
            data.withUnsafeBytes { bytes in
                BGRAExtraction.extract(source: bytes, width: width, height: height,
                    sourceBytesPerRow: rowStride ?? stride, point: point, radius: radius)
            }
        }
        #expect((extract(width: 0)) == nil)
        #expect((extract(height: 0)) == nil)
        #expect((extract(rowStride: 1)) == nil)
        #expect((extract(point: PixelPoint(x: -1, y: 2))) == nil)
        #expect((extract(point: PixelPoint(x: 5, y: 2))) == nil)
        #expect((extract(point: PixelPoint(x: 2, y: 5))) == nil)
        #expect((extract(radius: 0)) == nil)
        #expect((extract(radius: 513)) == nil)
        #expect((extract(height: 9999)) == nil)
        #expect((extract(width: Int.max)) == nil)
    }

}
