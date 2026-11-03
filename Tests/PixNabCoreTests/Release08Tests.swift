import Foundation
import Testing
@testable import PixNabCore

@Suite struct Release08Tests {
    @Test func testOKLabBlackAndWhite() {
        let black = OKLabColor.fromSRGB(.init(red: 0, green: 0, blue: 0))
        #expect(abs((black.lightness) - (0)) <= (1e-9))
        #expect(abs((black.a) - (0)) <= (1e-9))
        #expect(abs((black.b) - (0)) <= (1e-9))
        let white = OKLabColor.fromSRGB(.init(red: 1, green: 1, blue: 1))
        #expect(abs((white.lightness) - (1)) <= (1e-6))
        #expect(abs((white.a) - (0)) <= (1e-6))
        #expect(abs((white.b) - (0)) <= (1e-6))
    }
    @Test func testOKLabRedReference() {
        let lab = OKLabColor.fromSRGB(.init(red: 1, green: 0, blue: 0))
        #expect(abs((lab.lightness) - (0.62795536)) <= (0.000002))
        #expect(abs((lab.a) - (0.22486306)) <= (0.000002))
        #expect(abs((lab.b) - (0.12584630)) <= (0.000002))
    }
    @Test func testOKLCHColorCylindricalValues() {
        let lch = OKLabColor.fromSRGB(.init(red: 1, green: 0, blue: 0)).lch
        #expect(abs((lch.chroma) - (0.257683)) <= (0.00001))
        #expect(abs((lch.hue) - (29.2339)) <= (0.002))
    }
    @Test func testOKLCHAchromaticHueIsZero() {
        #expect(OKLabColor.fromSRGB(.init(red: 0, green: 0, blue: 0)).lch.hue == 0)
    }
    @Test func testModernCSSIncludesExplicitAlpha() {
        let red = SRGBColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        #expect(ColorFormatter.format(red, as: .cssOKLab).contains(" / 0.500)"))
        #expect(ColorFormatter.format(red, as: .cssOKLCH).contains(" / 0.500)"))
        #expect(ColorFormatter.format(red, as: .cssHWB) == "hwb(0.000 0.000% 0.000% / 0.500)")
    }
    @Test func testHWBBlackWhite() {
        let white = SRGBColor(red: 1, green: 1, blue: 1)
        let black = SRGBColor(red: 0, green: 0, blue: 0)
        #expect(ColorFormatter.format(white, as: .cssHWB) == "hwb(0.000 100.000% 0.000% / 1.000)")
        #expect(ColorFormatter.format(black, as: .cssHWB) == "hwb(0.000 0.000% 100.000% / 1.000)")
    }
    @Test func testOtherLanguageFormatsUseSharedRGBBytes() {
        let c = SRGBColor(red8: 12, green8: 128, blue8: 255)
        #expect(ColorFormatter.format(c, as: .python) == "(12, 128, 255)")
        #expect(ColorFormatter.format(c, as: .rust) == "(12u8, 128u8, 255u8)")
        #expect(ColorFormatter.format(c, as: .kotlin) == "android.graphics.Color.rgb(12, 128, 255)")
    }
    @Test func testFormatCatalogUniqueRawValuesAndTitles() {
        let formats = ColorOutputFormat.allCases
        #expect(Set(formats.map(\.rawValue)).count == formats.count)
        #expect(Set(formats.map(\.title)).count == formats.count)
        #expect(formats.count >= 27)
    }
    @Test func testNewFormatsSaveAndLoadPreferences() throws {
        var pref = AppPreferences()
        pref.defaultFormat = .cssOKLCH
        pref.favoriteFormats = [.cssOKLab, .cssHWB, .python]
        let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(pref))
        #expect(restored.defaultFormat == .cssOKLCH)
        #expect(restored.favoriteFormats == pref.favoriteFormats)
    }
    @Test func testLegacySettingsDecodeNewValuesWithDefaults() throws {
        let minimal = Data("{\"zoom\":10,\"chooseFormatAfterPick\":true}".utf8)
        let restored = try JSONDecoder().decode(AppPreferences.self, from: minimal)
        #expect(restored.zoom == 10)
        #expect(restored.chooseFormatAfterPick)
        #expect(restored.defaultFormat == .cssHex)
    }
    @Test func testHistoryPersistsFavoriteIdentityAcrossJSON() throws {
        var history = ColorHistory()
        let red = SRGBColor(red8: 255, green8: 0, blue8: 0)
        history.add(red)
        history.toggleFavorite(id: history.items[0].id)
        let uuid = history.items[0].id
        let restored = try JSONDecoder().decode(ColorHistory.self, from: JSONEncoder().encode(history))
        #expect(restored.items.first?.id == uuid)
        #expect(restored.favorites.count == 1)
    }
}
