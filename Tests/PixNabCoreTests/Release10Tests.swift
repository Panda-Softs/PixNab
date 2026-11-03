import Foundation
import Testing
@testable import PixNabCore

@Suite struct Release10Tests {
    private func hex(_ r: Int, _ g: Int, _ b: Int, _ alpha: Double = 1) -> SRGBColor {
        SRGBColor(red8: r, green8: g, blue8: b, alpha: alpha)
    }

    @Test func testASEMagicVersionAndBlockCount() {
        let bytes = Array(AdobeSwatchExchange.encode([
            AdobeSwatch(name: "Red", color: hex(255, 0, 0))
        ]))
        #expect(Array(bytes.prefix(12)) == [65,83,69,70,0,1,0,0,0,0,0,1])
        #expect(Array(bytes[12..<14]) == [0,1])
        let blockLength = Int(bytes[14]) << 24 | Int(bytes[15]) << 16 | Int(bytes[16]) << 8 | Int(bytes[17])
        #expect(blockLength + 18 == bytes.count)
        #expect(Array(bytes[18..<20]) == [0,4]) // three UTF-16 letters + null
    }

    @Test func testASECoordinatesAndGlobalColor() {
        let bytes = Array(AdobeSwatchExchange.encode([
            AdobeSwatch(name: "R", color: hex(255,0,0))
        ]))
        // The block ends with RGB floats (1, 0, 0) and global-type 0.
        #expect(Array(bytes.suffix(14)) == [0x3f,0x80,0,0, 0,0,0,0, 0,0,0,0, 0,0])
    }

    @Test func testASEMultipleBlocksAndUnicode() {
        let bytes = Array(AdobeSwatchExchange.encode([
            AdobeSwatch(name: "Blue", color: hex(0,0,255)),
            AdobeSwatch(name: "Étoile ✨", color: hex(8,9,10))
        ]))
        #expect(Array(bytes[8..<12]) == [0,0,0,2])
        #expect(bytes.contains(0x52)) // RGB tags
        #expect(bytes.count > 70)
    }

    @Test func testASEEmptyLibraryIsValidHeader() {
        #expect(Array(AdobeSwatchExchange.encode([])) == [65,83,69,70,0,1,0,0,0,0,0,0])
    }

    @Test func testASEIgnoresAlphaWithoutPremultiplyingRGB() {
        let opaque = AdobeSwatchExchange.encode([AdobeSwatch(name: "A", color: hex(250,30,40))])
        let translucent = AdobeSwatchExchange.encode([AdobeSwatch(name: "A", color: hex(250,30,40,0.2))])
        #expect(opaque == translucent)
    }

    @Test func testRenderKeyStableOnRepeatedTimerTick() {
        let key = MagnifierRenderKey(frameRevision: 8, pixel: PixelPoint(x: 200, y: 300),
            radius: 24, zoom: 8, precise: false, format: .cssHex, showsLabel: true, sessionCount: 2)
        let repeated = MagnifierRenderKey(frameRevision: 8, pixel: PixelPoint(x: 200, y: 300),
            radius: 24, zoom: 8, precise: false, format: .cssHex, showsLabel: true, sessionCount: 2)
        #expect(key == repeated)
    }

    @Test func testRenderInvalidatedByFrameOrPixelMovement() {
        let base = MagnifierRenderKey(frameRevision: 1, pixel: PixelPoint(x: 5, y: 9),
            radius: 5, zoom: 8, precise: false, format: .cssHex, showsLabel: true, sessionCount: 0)
        #expect(base != MagnifierRenderKey(frameRevision: 2, pixel: base.pixel,
            radius: 5, zoom: 8, precise: false, format: .cssHex, showsLabel: true, sessionCount: 0))
        #expect(base != MagnifierRenderKey(frameRevision: 1, pixel: PixelPoint(x: 6, y: 9),
            radius: 5, zoom: 8, precise: false, format: .cssHex, showsLabel: true, sessionCount: 0))
    }

    @Test func testRenderInvalidatedByPrecisionFormatOrSession() {
        let p = PixelPoint(x: 0, y: 0)
        let a = MagnifierRenderKey(frameRevision: 1, pixel: p, radius: 3, zoom: 5,
            precise: false, format: .cssHex, showsLabel: true, sessionCount: 0)
        let b = MagnifierRenderKey(frameRevision: 1, pixel: p, radius: 3, zoom: 5,
            precise: true, format: .cssHex, showsLabel: true, sessionCount: 0)
        let c = MagnifierRenderKey(frameRevision: 1, pixel: p, radius: 3, zoom: 5,
            precise: false, format: .cssRGB, showsLabel: true, sessionCount: 0)
        let d = MagnifierRenderKey(frameRevision: 1, pixel: p, radius: 3, zoom: 5,
            precise: false, format: .cssHex, showsLabel: true, sessionCount: 1)
        #expect(a != b)
        #expect(a != c)
        #expect(a != d)
    }

    @Test func testFrameRateDefaultsToSmooth() {
        #expect(AppPreferences().captureFrameRate == .smooth)
    }

    @Test func testFrameRatePreferenceRoundTrip() throws {
        var settings = AppPreferences()
        settings.captureFrameRate = .energySaver
        let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(settings))
        #expect(restored.captureFrameRate == .energySaver)
    }

    @Test func testOldPreferencesWithoutFrameRateRetainDefault() throws {
        let restored = try JSONDecoder().decode(AppPreferences.self, from: Data("{\"zoom\":9}".utf8))
        #expect(restored.captureFrameRate == .smooth)
        #expect(restored.zoom == 9)
    }

}
