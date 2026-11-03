import Foundation
import Testing
@testable import PixNabCore

@Suite struct ColorTests {
    @Test func testHarmoniesHaveExpectedHuesAndPreserveAlpha() {
        let red = SRGBColor(red8: 255, green8: 0, blue8: 0, alpha: 0.4)
        for (kind, expected) in [
            (ColorHarmonyKind.complementary, [0.0, 180.0]),
            (.analogous, [0, 30, 330]),
            (.triadic, [0, 120, 240]),
            (.tetradic, [0, 90, 180, 270])
        ] {
            let colors = ColorHarmonyPalette.colors(for: red, kind: kind)
            #expect(colors.count == expected.count)
            #expect(colors.first == red)
            for (color, hue) in zip(colors, expected) {
                #expect(abs(color.hsl.h - hue) < 0.0001)
                #expect(abs(color.alpha - 0.4) < 0.000001)
            }
        }
    }

    @Test func testMonochromaticHarmonyOnlyChangesLightness() {
        let base = SRGBColor(red8: 130, green8: 50, blue8: 200)
        let colors = ColorHarmonyPalette.colors(for: base, kind: .monochromatic)
        #expect(colors.count == 2)
        #expect(colors[0] == base)
        #expect(abs(colors[1].hsl.l - base.hsl.l) > 0.09)
        #expect(abs(colors[1].hsl.l - base.hsl.l) < 0.11)
        for color in colors { #expect(abs(color.hsl.h - base.hsl.h) < 0.00001) }
    }

    @Test func testHueWheelNormalizesAndHandlesGrayscale() {
        let base = SRGBColor(red8: 128, green8: 128, blue8: 128, alpha: 0.65)
        let color = ColorHarmonyPalette.color(atHue: -120, basedOn: base)
        #expect(abs(color.hsl.h - 240) < 0.000001)
        #expect(color.hsl.s > 0.69)
        #expect(abs(color.alpha - base.alpha) < 0.000001)
    }

    @Test func testHSLSharedInitializerMatchesCSSParser() {
        for h in stride(from: -360.0, through: 720.0, by: 30) {
            let code = "hsl(\(h) 65% 42% / 0.5)"
            let parsed = ColorParser.parse(code)
            let direct = SRGBColor(hue: h, saturation: 0.65, lightness: 0.42, alpha: 0.5)
            #expect(parsed == direct)
        }
    }
    @Test func testHarmonyPaletteHistoryKeepsOrderAndFavoriteIdentity() {
        let base = SRGBColor(red8: 40, green8: 93, blue8: 215)
        let palette = ColorHarmonyPalette.colors(for: base, kind: .tetradic)
        #expect(palette.count == 4)
        var history = ColorHistory()
        history.add(palette[1])
        let favoriteID = history.items[0].id
        history.toggleFavorite(id: favoriteID)

        history.addPalette(palette)
        #expect(history.items.count == 4)
        #expect(history.items.map(\.color) == palette)
        #expect(history.items[1].id == favoriteID)
        #expect(history.items[1].isFavorite)
        #expect(history.items.allSatisfy { $0.sourceP3 == nil })

        // Reapplying a saved palette must not produce duplicates or lose stars.
        history.addPalette(palette)
        #expect(history.items.map(\.color) == palette)
        #expect(history.items[1].id == favoriteID)
        #expect(history.items[1].isFavorite)
    }

    @Test func testHarmonyPaletteHistoryDoesNotEraseP3Provenance() {
        let p3 = DisplayP3Color(red: 0, green: 1, blue: 0)
        let color = p3.toSRGB()
        var history = ColorHistory()
        history.add(color, displayProfileName: "Display P3", sourceP3: p3)
        history.addPalette([color, SRGBColor(red8: 255, green8: 0, blue8: 0)])
        #expect(history.items.count == 3)
        #expect(history.items[2].sourceP3 == p3)
        #expect(history.items[2].displayProfileName == "Display P3")
        #expect(history.items[0].sourceP3 == nil)
    }

    @Test func testHarmonyPaletteUsesExistingSessionFormatting() {
        let color = SRGBColor(red8: 40, green8: 93, blue8: 215)
        let palette = ColorHarmonyPalette.colors(for: color, kind: .complementary)
        var session = PickSession()
        for suggestion in palette { session.append(suggestion) }
        #expect(session.colors == palette)
        let expected = palette.map { ColorFormatter.format($0, as: .cssHex) }.joined(separator: ", ")
        #expect(session.formatted(as: .cssHex, separator: .commaSpace) == expected)
        #expect(session.formatted(as: .cssHex, separator: .blankLine).components(separatedBy: "\n\n").count == 2)
    }

    @Test func testWideGamutAndUntaggedColorsRemainDistinctInHistory() {
        let p3 = DisplayP3Color(red: 0, green: 1, blue: 0)
        let color = p3.toSRGB()
        var history = ColorHistory()
        history.add(color, displayProfileName: "Display P3", sourceP3: p3)
        let originalID = history.items[0].id
        history.add(color)
        #expect(history.items.count == 2)
        #expect(history.items[0].sourceP3 == nil)
        #expect(history.items[1].sourceP3 == p3)
        #expect(history.items[1].displayProfileName == "Display P3")
        #expect(history.items[1].id == originalID)
        history.add(color, displayProfileName: "Current", sourceP3: p3)
        #expect(history.items.count == 2)
        #expect(history.items[0].id == originalID)
        #expect(history.items[0].displayProfileName == "Current")
        #expect(history.items[1].sourceP3 == nil)
    }

    @Test func testWideGamutFavoritesStayAttachedToExactP3Entry() {
        let p3 = DisplayP3Color(red: 0, green: 1, blue: 0)
        let color = p3.toSRGB()
        var history = ColorHistory()
        history.add(color, sourceP3: p3)
        history.toggleFavorite(id: history.items[0].id)
        history.add(color)
        #expect(history.items.count == 2)
        #expect(history.items[0].isFavorite == false)
        #expect(history.items[1].isFavorite == true)
        #expect(history.isFavorite(color, sourceP3: p3))
        #expect(!history.isFavorite(color))
    }

    @Test func testCIELabD50ReferencePrimariesAndNeutrals() {
        let white = CIELabColor.fromSRGB(.init(red8: 255, green8: 255, blue8: 255))
        #expect(abs((white.lightness) - (100)) <= (0.02))
        #expect(abs((white.a) - (0)) <= (0.03))
        #expect(abs((white.b) - (0)) <= (0.03))
        let black = CIELabColor.fromSRGB(.init(red8: 0, green8: 0, blue8: 0))
        #expect(abs((black.lightness) - (0)) <= (0.001))
        let red = CIELabColor.fromSRGB(.init(red8: 255, green8: 0, blue8: 0))
        #expect(abs((red.lightness) - (54.29)) <= (0.08))
        #expect(abs((red.a) - (80.81)) <= (0.15))
        #expect(abs((red.b) - (69.89)) <= (0.15))
    }

    @Test func testLabFormatUsesSharedFormattingOptions() {
        var options = FormattingOptions()
        options.decimalPlaces = 2
        let text = ColorFormatter.format(.init(red8: 255, green8: 0, blue8: 0), as: .cssLab, options: options)
        #expect(text.hasPrefix("lab(54.29% "), "\(text)")
        #expect(text.hasSuffix(" / 1.00)"), "\(text)")
    }

    @Test func testCSSLabParsingMatchesReferenceColors() {
        let red = ColorParser.parse("lab(54.29% 80.81 69.89 / 0.5)")
        #expect((red) != nil)
        #expect(abs((red?.alpha ?? 0) - (0.5)) <= (0.001))
        #expect(abs((red?.red ?? 0) - (1)) <= (0.002))
        #expect(abs((red?.green ?? 1) - (0)) <= (0.003))
        #expect(abs((red?.blue ?? 1) - (0)) <= (0.003))
        let white = ColorParser.parse("lab(100% 0 0)")
        #expect(white?.bytes == [255, 255, 255])
    }

    @Test func testCSSLabRoundTripWithSharedFormatter() {
        let colors: [SRGBColor] = [
            .init(red8: 12, green8: 82, blue8: 177),
            .init(red8: 183, green8: 113, blue8: 51),
            .init(red8: 255, green8: 0, blue8: 0)
        ]
        var opts = FormattingOptions()
        opts.decimalPlaces = 4
        for color in colors {
            let formatted = ColorFormatter.format(color, as: .cssLab, options: opts)
            guard let parsed = ColorParser.parse(formatted) else {
                Issue.record("Could not parse \(formatted)")
                continue
            }
            for (a, b) in zip(parsed.bytes, color.bytes) {
                #expect(abs(a - b) <= 1, "\(formatted)")
            }
        }
    }

    @Test func testCSSLabRejectsInvalidInput() {
        for text in ["lab(50 0 0)", "lab(NaN% 0 0)", "lab(101% 0 0)",
                     "lab(50% 0)", "lab(50% 0 0 / 2)", "lab(50% 0 0 /)",
                     "lab(50% 0 0 garbage)", "lab(50% inf 0)"] {
            #expect((ColorParser.parse(text)) == nil, "\(text)")
        }
    }

    @Test func testHSBFormatsUseHSVNotHSLLightness() {
        let red = SRGBColor(red8: 255, green8: 0, blue8: 0)
        let gray = SRGBColor(red8: 128, green8: 128, blue8: 128)
        var options = FormattingOptions()
        options.decimalPlaces = 3
        #expect(ColorFormatter.format(red, as: .genericHSB, options: options) == "0.000, 1.000, 1.000")
        #expect(ColorFormatter.format(red, as: .swiftNSColorHSB, options: options) ==
                "NSColor(calibratedHue: 0.000, saturation: 1.000, brightness: 1.000, alpha: 1.000)")
        #expect(ColorFormatter.format(red, as: .swiftUIColorHSB, options: options) ==
                "UIColor(hue: 0.000, saturation: 1.000, brightness: 1.000, alpha: 1.000)")
        #expect(ColorFormatter.format(gray, as: .genericHSB, options: options) == "0.000, 0.000, 0.502")
        #expect(ColorFormatter.format(.init(red8: 0, green8: 0, blue8: 0), as: .genericHSB) == "0.000, 0.000, 0.000")
    }

    @Test func testNewHSBFormatsDecodeFromOldPreferences() throws {
        for format in [ColorOutputFormat.genericHSB, .swiftNSColorHSB, .swiftUIColorHSB] {
            var preferences = AppPreferences()
            preferences.defaultFormat = format
            let copy = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))
            #expect(copy.defaultFormat == format)
        }
    }

    @Test func testCapturedP3CSSUsesSourceInsteadOfReconstructedSRGB() {
        // Vivid P3 green clips to sRGB; the original P3 value must survive export.
        let p3 = DisplayP3Color(red: 0, green: 1, blue: 0)
        let clipped = p3.toSRGB()
        let reconstructed = ColorFormatter.format(clipped, as: .cssDisplayP3)
        let retained = ColorFormatter.format(clipped, as: .cssDisplayP3, sourceP3: p3)
        #expect(reconstructed != retained)
        #expect(retained == "color(display-p3 0.000 1.000 0.000 / 1.000)")
        let parsed = ColorParser.parseDetailed(retained)
        #expect(parsed?.sourceP3 == p3)
    }

    @Test func testWideGamutPickSessionSurvivesDiskAndUndo() throws {
        let p3 = DisplayP3Color(red: 0.12, green: 0.9, blue: 0.31)
        var session = PickSession()
        session.append(p3.toSRGB(), sourceP3: p3)
        session.append(.init(red8: 128, green8: 64, blue8: 0))
        let loaded = try JSONDecoder().decode(PickSession.self, from: JSONEncoder().encode(session))
        #expect(loaded.count == 2)
        #expect(loaded.sourceP3[0] == p3)
        #expect(loaded.sourceP3[1] == nil)
        #expect(loaded.formatted(as: .cssDisplayP3).hasPrefix("color(display-p3 0.120 0.900 0.310"))
        var undo = loaded
        _ = undo.undoLast()
        #expect(undo.lastSourceP3 == p3)
        _ = undo.undoLast()
        #expect(undo.sourceP3.isEmpty)
    }

    @Test func testLegacySessionsAndHistoryDecodeWithoutWideGamutMetadata() throws {
        let legacySession = #"{"colors":[{"red":1,"green":0,"blue":0,"alpha":1}]}"#
        let session = try JSONDecoder().decode(PickSession.self, from: Data(legacySession.utf8))
        #expect(session.count == 1)
        #expect(session.sourceP3.count == 1)
        #expect(session.sourceP3[0] == nil)
        var history = ColorHistory()
        let p3 = DisplayP3Color(red: 0, green: 1, blue: 0)
        history.add(p3.toSRGB(), sourceP3: p3)
        let copy = try JSONDecoder().decode(ColorHistory.self, from: JSONEncoder().encode(history))
        #expect(copy.items[0].sourceP3 == p3)
    }

    @Test func testDifferentP3ColorsDoNotCollapseInClippedSRGBHistory() {
        // Distinct Display P3 colors can both clip to the same sRGB bytes.
        let one = DisplayP3Color(red: 1, green: 0, blue: 0)
        let two = DisplayP3Color(red: 0.99, green: 0, blue: 0)
        let left = one.toSRGB(), right = two.toSRGB()
        #expect(left.rgbaBytes == right.rgbaBytes)
        var history = ColorHistory()
        history.add(left, sourceP3: one)
        history.add(right, sourceP3: two)
        #expect(history.items.count == 2)
        history.setFavorite(left, favorite: true, sourceP3: one)
        #expect(history.isFavorite(left, sourceP3: one))
        #expect(!history.isFavorite(right, sourceP3: two))
    }

    @Test func testReferenceGray() {
        let color = SRGBColor(red8: 94, green8: 94, blue8: 94)
        #expect(ColorFormatter.format(color, as: .genericHex) == "5e5e5e")
        #expect(ColorFormatter.format(color, as: .cssHex) == "#5e5e5e")
        #expect(ColorFormatter.format(color, as: .cssRGB) == "rgb(94, 94, 94)")
        #expect(ColorFormatter.format(color, as: .cssHSL) == "hsl(0, 0%, 37%)")
    }
    @Test func testHSLPrimaries() {
        let red = SRGBColor(red8: 255, green8: 0, blue8: 0)
        #expect(ColorFormatter.format(red, as: .cssHSL) == "hsl(0, 100%, 50%)")
        #expect(ColorFormatter.format(SRGBColor(red8: 0, green8: 255, blue8: 0), as: .cssHSL) == "hsl(120, 100%, 50%)")
    }
    @Test func testShorthandAndCase() {
        var options = FormattingOptions()
        options.cssShorthand = true; options.uppercaseHex = true
        #expect(ColorFormatter.format(SRGBColor(red8: 170, green8: 0, blue8: 255), as: .cssHex, options: options) == "#A0F")
        #expect(ColorFormatter.format(SRGBColor(red8: 171, green8: 0, blue8: 255), as: .cssHex, options: options) == "#AB00FF")
    }
    @Test func testClampNonFinite() {
        let c = SRGBColor(red: .nan, green: 3, blue: -5, alpha: .infinity)
        #expect(c.rgbaBytes == [0,255,0,0])
    }
    @Test func testHistoryDeduplicatesAndKeepsFavorites() {
        var history = ColorHistory()
        let red = SRGBColor(red8: 255, green8: 0, blue8: 0)
        history.add(red)
        history.toggleFavorite(id: history.items[0].id)
        history.add(SRGBColor(red8: 0, green8: 255, blue8: 0))
        history.add(red)
        #expect(history.items.count == 2)
        #expect(history.items[0].isFavorite)
        history.add(SRGBColor(red8: 0, green8: 0, blue8: 255), limit: 2)
        #expect(history.items.count == 2)
        #expect(history.favorites.count == 1)
    }
    @Test func testJSONRoundTrip() throws {
        var p = AppPreferences()
        p.defaultFormat = .swiftUI
        let loaded = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(p))
        #expect(loaded.defaultFormat == .swiftUI)
    }
    @Test func testPixelMappingRetina() {
        #expect(PixelGeometry.point(globalX: 25, globalY: 75,
            displayX: 0, displayY: 0, widthPoints: 100, heightPoints: 100,
            widthPixels: 200, heightPixels: 200) == PixelPoint(x: 50, y: 50))
    }
    @Test func testPixelMappingSecondaryScreen() {
        #expect(PixelGeometry.point(globalX: -900, globalY: -400,
            displayX: -1000, displayY: -500, widthPoints: 1000, heightPoints: 500,
            widthPixels: 1500, heightPixels: 750) == PixelPoint(x: 150, y: 600))
    }
    @Test func testPixelMappingOutOfBounds() {
        #expect((PixelGeometry.point(globalX: 100, globalY: 40,
            displayX: 0, displayY: 0, widthPoints: 100, heightPoints: 100,
            widthPixels: 200, heightPixels: 200)) == nil)
        #expect((PixelGeometry.point(globalX: 25, globalY: 40,
            displayX: 0, displayY: 0, widthPoints: 0, heightPoints: 100,
            widthPixels: 200, heightPixels: 200)) == nil)
    }
    @Test func testFormattingOptionsAffectOnlyTheirFormat() {
        var options = FormattingOptions()
        options.hexPrefix = "0x"
        options.decimalPlaces = 2
        options.trimTrailingZeros = true
        let c = SRGBColor(red8: 0, green8: 128, blue8: 255)
        #expect(ColorFormatter.format(c, as: .genericHex, options: options) == "0x0080ff")
        #expect(ColorFormatter.format(c, as: .cssHex, options: options) == "#0080ff")
        #expect(ColorFormatter.format(c, as: .genericDecimal, options: options) == "0, 0.5, 1")
    }
    @Test func testEveryFormatNonEmpty() {
        let color = SRGBColor(red8: 64, green8: 128, blue8: 192)
        for format in ColorOutputFormat.allCases {
            #expect(!(ColorFormatter.format(color, as: format).isEmpty), "\(format)")
        }
    }
    @Test func testHistoryPreservesIdentityAfterRepeatSelection() {
        var history = ColorHistory()
        let color = SRGBColor(red8: 16, green8: 32, blue8: 48)
        history.add(color)
        let originalID = history.items[0].id
        history.add(color)
        #expect(history.items[0].id == originalID)
        #expect(history.items.count == 1)
    }

    @Test func testFavoriteNewColorAndClearRecents() {
        let red = SRGBColor(red8: 255, green8: 0, blue8: 0)
        let blue = SRGBColor(red8: 0, green8: 0, blue8: 255)
        var history = ColorHistory()
        history.add(red)
        history.setFavorite(blue, favorite: true)
        #expect(history.isFavorite(blue))
        history.clearRecents()
        #expect(history.items.count == 1)
        #expect(history.items[0].color == blue)
        history.setFavorite(blue, favorite: false)
        #expect(!(history.isFavorite(blue)))
    }

    @Test func testCSSAndHexInput() {
        #expect(ColorParser.parse("  #abc ")?.rgbaBytes == [170, 187, 204, 255])
        #expect(ColorParser.parse("0x0A1b2C")?.rgbaBytes == [10, 27, 44, 255])
        #expect(ColorParser.parse("#11223380")?.rgbaBytes == [17, 34, 51, 128])
        #expect(ColorParser.parse("#f08a")?.rgbaBytes == [255, 0, 136, 170])
        #expect(ColorParser.parse("rgb(12, 34, 56)")?.rgbaBytes == [12, 34, 56, 255])
        #expect(ColorParser.parse("rgba(12,34,56,0.5)")?.rgbaBytes == [12, 34, 56, 128])
    }

    @Test func testColorParserRejectsInvalidAndAmbiguousValues() {
        for invalid in ["", "#12", "#zzzzzz", "red", "#12345", "#123456789",
                        "rgb(300,0,0)", "rgb(12.5,0,0)", "rgba(1,2,3,NaN)",
                        "rgba(1,2,3,1.5)", "rgb(1 2 / 3)", "rgba(1,2,3)"] {
            #expect((ColorParser.parse(invalid)) == nil, "\(invalid)")
        }
    }

    @Test func testColorParserRoundTripAllRGBBytes() {
        for i in 0...255 {
            let color = SRGBColor(red8: i, green8: 255 - i, blue8: (i * 17) % 256)
            let hex = ColorFormatter.format(color, as: .cssHex)
            #expect(ColorParser.parse(hex)?.rgbaBytes == color.rgbaBytes)
        }
    }

    @Test func testCSSHexAlphaAndParsingRoundTrip() {
        let color = SRGBColor(red8: 10, green8: 20, blue8: 30, alpha: 0.5)
        #expect(ColorFormatter.format(color, as: .cssHexAlpha) == "#0a141e80")
        #expect(ColorParser.parse(ColorFormatter.format(color, as: .cssHexAlpha))?.rgbaBytes == color.rgbaBytes)
        var options = FormattingOptions()
        options.uppercaseHex = true
        options.cssShorthand = true
        #expect(ColorFormatter.format(color, as: .cssHexAlpha, options: options) == "#0A141E80")
    }

    @Test func testSwiftDeviceRGBFormatMatchesReference() {
        let color = SRGBColor(red8: 94, green8: 94, blue8: 94)
        #expect(ColorFormatter.format(color, as: .swiftNSColorDeviceRGB) == "NSColor(deviceRed: 0.369, green: 0.369, blue: 0.369, alpha: 1.000)")
    }

    @Test func testHistoryEncodingAndDecodingAfterModelRename() throws {
        // Persisted JSON has value fields, not the Swift struct name; v0.1 files stay readable.
        let legacyJSON = """
        {"items":[{"id":"12345678-1234-1234-1234-123456789abc","color":{"red":1,"green":0,"blue":0,"alpha":1},"pickedAt":0,"isFavorite":true}]}
        """
        let restored = try JSONDecoder().decode(ColorHistory.self, from: Data(legacyJSON.utf8))
        #expect(restored.items.count == 1)
        #expect(restored.items[0].color.bytes == [255, 0, 0])
        #expect(restored.items[0].isFavorite)
        let data = try JSONEncoder().encode(restored)
        #expect(try JSONDecoder().decode(ColorHistory.self, from: data).items.count == 1)
    }

    @Test func testPixelMappingClampsLastPhysicalRow() {
        #expect(PixelGeometry.point(globalX: 0, globalY: 0,
            displayX: 0, displayY: 0, widthPoints: 100, heightPoints: 100,
            widthPixels: 200, heightPixels: 200) == PixelPoint(x: 0, y: 199))
    }

    @Test func testLegacyPreferencesDecodeWithoutNewFields() throws {
        let json = """
        {"zoom":11,"pickShortcut":{"keyCode":35,"modifiers":2304},
         "defaultFormat":"cssRGB","formatting":{"uppercaseHex":true,"decimalPlaces":2}}
        """
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: Data(json.utf8))
        #expect(preferences.zoom == 11)
        #expect(preferences.pickShortcut.keyCode == 35)
        #expect(preferences.defaultFormat == .cssRGB)
        #expect(preferences.formatting.uppercaseHex)
        #expect(preferences.formatting.decimalPlaces == 2)
        #expect(preferences.formatting.commaSeparated)
        #expect(!(preferences.favoriteFormats.isEmpty))
    }

    @Test func testOldPreferencesKeepFieldsAndDefaultMissingKeys() throws {
        let old = #"{"appearance":"Dark","captureRadius":31,"chooseFormatAfterPick":true}"#
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data(old.utf8))
        #expect(decoded.appearance == .dark)
        #expect(decoded.chooseFormatAfterPick)
        #expect(decoded.captureRadius == 31)
        #expect(decoded.defaultFormat == .cssHex)
    }

    @Test func testLegacyFormattingOptionsRecoverMissingProperties() throws {
        let json = #"{"uppercaseHex":true,"decimalPlaces":5}"#
        let options = try JSONDecoder().decode(FormattingOptions.self, from: Data(json.utf8))
        #expect(options.uppercaseHex)
        #expect(options.decimalPlaces == 5)
        #expect(options.hexPrefix == "")
        #expect(!(options.trimTrailingZeros))
    }

    @Test func testPreferenceSanitizationAndFormatFavorites() throws {
        let json = #"{"zoom":999,"captureRadius":-40,"favoriteFormats":["cssHex","cssHex","swiftUI"]}"#
        var settings = try JSONDecoder().decode(AppPreferences.self, from: Data(json.utf8))
        #expect(settings.zoom == 15)
        #expect(settings.captureRadius == 9)
        #expect(settings.favoriteFormats == [.cssHex, .swiftUI])
        settings.toggleFavoriteFormat(.swiftUI)
        #expect(settings.favoriteFormats == [.cssHex])
        settings.toggleFavoriteFormat(.swiftUI)
        #expect(settings.favoriteFormats == [.cssHex, .swiftUI])
        let saved = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(AppPreferences.self, from: saved).favoriteFormats == settings.favoriteFormats)
    }

    @Test func testCSSHSLParsingPrimaryColors() {
        let samples: [(String, [Int])] = [
            ("hsl(0, 100%, 50%)", [255, 0, 0, 255]),
            ("hsl(120, 100%, 50%)", [0, 255, 0, 255]),
            ("hsl(-120,100%,50%)", [0, 0, 255, 255]),
            ("hsla(240,100%,50%,0.5)", [0, 0, 255, 128]),
            ("hsl(60 100% 50%)", [255, 255, 0, 255]),
            ("hsl(240deg 100% 50% / 0.5)", [0, 0, 255, 128])
        ]
        for (string, expected) in samples {
            #expect(ColorParser.parse(string)?.rgbaBytes == expected, "\(string)")
        }
    }

    @Test func testCSSHSLRejectsMalformed() {
        for value in ["hsl(0,120%,50%)", "hsl(0,-1%,50%)", "hsl(NaN,0%,0%)",
                      "hsl(0,0,0)", "hsl(0,0%,50%,2)", "hsla(0,0%,50%)",
                      "hsl(10 20% / 1)", "hsl(10 20% 50% / -1)"] {
            #expect((ColorParser.parse(value)) == nil, "\(value)")
        }
    }

    @Test func testNewOutputFormatsAndFavorites() {
        let c = SRGBColor(red8: 255, green8: 0, blue8: 0)
        #expect(ColorFormatter.format(c, as: .cssModernRGB) == "rgb(255 0 0 / 1.000)")
        #expect(ColorFormatter.format(c, as: .cssModernHSL) == "hsl(0 100% 50% / 1.000)")
        #expect(ColorFormatter.format(c, as: .openGL) == "glColor4f(1.000, 0.000, 0.000, 1.000)")
    }

    @Test func testModernHSLRoundTripPrimaries() {
        for c in [SRGBColor(red8: 255, green8: 0, blue8: 0),
                  SRGBColor(red8: 0, green8: 255, blue8: 0),
                  SRGBColor(red8: 0, green8: 0, blue8: 255)] {
            #expect(ColorParser.parse(ColorFormatter.format(c, as: .cssModernHSL))?.rgbaBytes == c.rgbaBytes)
        }
    }

    @Test func testCSSModernRGBParsingAndRoundTrip() {
        #expect(ColorParser.parse("rgb(255 0 128 / 0.5)")?.rgbaBytes == [255, 0, 128, 128])
        #expect(ColorParser.parse("rgb(100% 0% 50%)")?.rgbaBytes == [255, 0, 128, 255])
        #expect(ColorParser.parse("rgba(10,20,30,25%)")?.rgbaBytes == [10, 20, 30, 64])
        #expect(ColorParser.parse("hsl(240 100% 50% / 25%)")?.rgbaBytes == [0, 0, 255, 64])
        for sample in [SRGBColor(red8: 0, green8: 0, blue8: 0),
                       SRGBColor(red8: 255, green8: 128, blue8: 16),
                       SRGBColor(red8: 10, green8: 40, blue8: 90)] {
            #expect(ColorParser.parse(ColorFormatter.format(sample, as: .cssModernRGB))?.rgbaBytes == sample.rgbaBytes)
        }
    }

    @Test func testMalformedCSSModernRGBRejected() {
        for text in ["rgb(10 20)", "rgb(10 20 300)", "rgb(10 20 30 / 101%)",
                     "rgb(10 20 30 / NaN)", "rgb(10 20 30 / 1 / 2)"] {
            #expect((ColorParser.parse(text)) == nil, "\(text)")
        }
    }


    @Test func testSearchHistoryByHexRGBAndWhitespace() {
        let a = PickedColor(color: SRGBColor(red8: 94, green8: 94, blue8: 94))
        let b = PickedColor(color: SRGBColor(red8: 255, green8: 20, blue8: 30), isFavorite: true)
        let entries = [a, b]
        #expect(ColorHistoryQuery.filter(entries, text: " #5E5E ").map(\.id) == [a.id])
        #expect(ColorHistoryQuery.filter(entries, text: "255, 20").map(\.id) == [b.id])
        #expect(ColorHistoryQuery.filter(entries, text: " ").count == 2)
        #expect(ColorHistoryQuery.filter(entries, text: "not a color").isEmpty)
    }

    @Test func testHistoryFavoriteFilterAndStaleRemoval() {
        var history = ColorHistory()
        history.add(SRGBColor(red8: 10, green8: 20, blue8: 30))
        history.add(SRGBColor(red8: 30, green8: 40, blue8: 50))
        let favorite = history.items[0]
        history.toggleFavorite(id: favorite.id)
        #expect(ColorHistoryQuery.filter(history.items, text: "", favoritesOnly: true).map(\.id) == [favorite.id])
        let didRemoveUnknown = history.remove(id: UUID())
        #expect(!didRemoveUnknown)
        #expect(history.items.count == 2)
        let didRemoveFavorite = history.remove(id: favorite.id)
        #expect(didRemoveFavorite)
        #expect(history.favorites.isEmpty)
        #expect(history.items.count == 1)
    }

    @Test func testHistoryDeletePersistsAcrossRoundTrip() throws {
        var history = ColorHistory()
        history.add(SRGBColor(red8: 255, green8: 0, blue8: 0))
        history.add(SRGBColor(red8: 0, green8: 0, blue8: 255))
        let removedID = history.items[0].id
        let didRemoveEntry = history.remove(id: removedID)
        #expect(didRemoveEntry)
        let saved = try JSONEncoder().encode(history)
        let loaded = try JSONDecoder().decode(ColorHistory.self, from: saved)
        #expect(loaded.items.count == 1)
        #expect(!(loaded.items.contains { $0.id == removedID }))
    }

    @Test func testHotkeyPolicyRejectsUnsafeGlobalKeys() {
        #expect(!(HotkeyPolicy.isSafe(Hotkey(keyCode: 8, modifiers: 0))))
        #expect(!(HotkeyPolicy.isSafe(Hotkey(keyCode: 8, modifiers: 0x0200))))
        #expect(!(HotkeyPolicy.isSafe(Hotkey(keyCode: 200, modifiers: 0x0100))))
        #expect(!(HotkeyPolicy.isSafe(Hotkey(keyCode: 8, modifiers: 0x8000))))
        #expect(HotkeyPolicy.isSafe(Hotkey(keyCode: 8, modifiers: 0x0900)))
    }

    @Test func testHotkeyPolicyProtectsAgainstDuplicates() {
        let first = Hotkey(keyCode: 8, modifiers: 0x0900)
        let second = Hotkey(keyCode: 35, modifiers: 0x0900)
        #expect(!(HotkeyPolicy.isValidPair(first, first)))
        #expect(HotkeyPolicy.isValidPair(first, second))
    }

    @Test func testPixelCentersRoundTripAtNonIntegralScaling() {
        let size = (w: 3024, h: 1964)
        let samples = [PixelPoint(x: 0, y: 0),
                       PixelPoint(x: size.w - 1, y: size.h - 1),
                       PixelPoint(x: 1007, y: 1729)]
        for pixel in samples {
            let center = PixelGeometry.center(of: pixel, displayX: -1680.5, displayY: 95.25,
                                              widthPoints: 1512, heightPoints: 982,
                                              widthPixels: size.w, heightPixels: size.h)
            #expect((center) != nil)
            #expect(PixelGeometry.point(globalX: center!.x, globalY: center!.y,
                                                displayX: -1680.5, displayY: 95.25,
                                                widthPoints: 1512, heightPoints: 982,
                                                widthPixels: size.w, heightPixels: size.h) == pixel)
        }
    }

    @Test func testPixelCentersRejectInvalidCoordinates() {
        #expect((PixelGeometry.center(of: PixelPoint(x: -1, y: 4),
            displayX: 0, displayY: 0, widthPoints: 100, heightPoints: 100,
            widthPixels: 200, heightPixels: 200)) == nil)
        #expect((PixelGeometry.center(of: PixelPoint(x: 1, y: 1),
            displayX: .nan, displayY: 0, widthPoints: 100, heightPoints: 100,
            widthPixels: 200, heightPixels: 200)) == nil)
        #expect((PixelGeometry.center(of: PixelPoint(x: 1, y: 1),
            displayX: 0, displayY: 0, widthPoints: 0, heightPoints: 100,
            widthPixels: 200, heightPixels: 200)) == nil)
    }

    @Test func testCapturedPixelPipelineUsesPhysicalCoordinates() {
        // Regression for the v0.5 compile error: the capture-position mapper must
        // produce PixelPoint, the same type consumed by PixelNavigation and center().
        let width = 3024, height = 1964
        let displayX = -1512.0, displayY = 0.0
        let widthPoints = 1512.0, heightPoints = 982.0
        let pointer = PixelGeometry.point(
            globalX: -1512.0 + 200.25, globalY: 801.75,
            displayX: displayX, displayY: displayY,
            widthPoints: widthPoints, heightPoints: heightPoints,
            widthPixels: width, heightPixels: height)
        #expect((pointer) != nil)
        let moved = PixelNavigation.moved(pointer!, dx: 1, dy: -10,
                                         width: width, height: height)
        #expect((moved) != nil)
        #expect(moved!.x == pointer!.x + 1)
        #expect(moved!.y == pointer!.y - 10)
        let center = PixelGeometry.center(of: moved!, displayX: displayX,
                                          displayY: displayY, widthPoints: widthPoints,
                                          heightPoints: heightPoints,
                                          widthPixels: width, heightPixels: height)
        #expect((center) != nil)
        #expect(PixelGeometry.point(
            globalX: center!.x, globalY: center!.y,
            displayX: displayX, displayY: displayY,
            widthPoints: widthPoints, heightPoints: heightPoints,
            widthPixels: width, heightPixels: height) == moved)
    }

    @Test func testPhysicalPixelNavigationClampsToCapturedBuffer() {
        let base = PixelPoint(x: 50, y: 30)
        #expect(PixelNavigation.moved(base, dx: 1, dy: -1, width: 100, height: 100) == PixelPoint(x: 51, y: 29))
        #expect(PixelNavigation.moved(base, dx: -999, dy: 999, width: 100, height: 100) == PixelPoint(x: 0, y: 99))
        #expect(PixelNavigation.moved(base, dx: Int.max, dy: Int.min, width: 100, height: 100) == PixelPoint(x: 99, y: 0))
        #expect((PixelNavigation.moved(PixelPoint(x: -1, y: 0), dx: 0, dy: 0,
                                          width: 100, height: 100)) == nil)
    }

    @Test func testCustomHotkeyLabelsAndSafety() {
        let key = Hotkey(keyCode: 8, modifiers: 0x0800 | 0x0100)
        #expect(HotkeyDisplay.label(for: key) == "⌥⌘C")
        #expect(HotkeyPolicy.isSafe(Hotkey(keyCode: 35, modifiers: 0x1000)))
        #expect(!(HotkeyPolicy.isSafe(Hotkey(keyCode: 55, modifiers: 0x0100))))
        #expect(!(HotkeyPolicy.isSafe(Hotkey(keyCode: 57, modifiers: 0x0100))))
        #expect(HotkeyDisplay.label(for: Hotkey(keyCode: 7, modifiers: 0x1200)) == "⌃⇧X")
    }

    @Test func testCustomHotkeysSurviveSavedPreferences() throws {
        var settings = AppPreferences()
        settings.pickShortcut = Hotkey(keyCode: 7, modifiers: 0x1800)
        settings.formatsShortcut = Hotkey(keyCode: 35, modifiers: 0x1100)
        let restored = try JSONDecoder().decode(AppPreferences.self,
                                                from: JSONEncoder().encode(settings))
        #expect(HotkeyPolicy.isValidPair(restored.pickShortcut, restored.formatsShortcut))
        #expect(restored.pickShortcut == settings.pickShortcut)
        #expect(restored.formatsShortcut == settings.formatsShortcut)
    }

}

@Suite struct PickSessionTests {
    private let red = SRGBColor(red8: 255, green8: 0, blue8: 0)
    private let blue = SRGBColor(red8: 0, green8: 0, blue8: 255)

    @Test func testOrdinaryClickFinishes() {
        #expect(PickAction.resolve(command: false, option: false) == .finish)
    }

    @Test func testOptionClickOpensFormats() {
        #expect(PickAction.resolve(command: false, option: true) == .chooseFormat)
    }

    @Test func testCommandClickKeepsPickerOpenEvenWithOption() {
        #expect(PickAction.resolve(command: true, option: false) == .continuePicking)
        #expect(PickAction.resolve(command: true, option: true) == .continuePicking)
    }

    @Test func testMultiplePicksKeepSelectionOrderAndFormat() {
        var session = PickSession()
        session.append(red)
        session.append(blue)
        #expect(session.count == 2)
        #expect(session.formatted(as: .cssHex) == "#ff0000\n#0000ff")
        #expect(session.formatted(as: .cssRGB) == "rgb(255, 0, 0)\nrgb(0, 0, 255)")
    }

    @Test func testEmptySessionAndSingleColor() {
        var session = PickSession()
        #expect(session.formatted(as: .cssHex) == "")
        session.append(red)
        #expect(session.formatted(as: .cssHex) == "#ff0000")
    }

    @Test func testRepeatedPicksArePreservedWithinSession() {
        var session = PickSession()
        session.append(red)
        session.append(red)
        #expect(session.count == 2)
        #expect(session.formatted(as: .cssHex) == "#ff0000\n#ff0000")
    }

    @Test func testHistoryDeduplicatesWhileSessionPreservesPicks() {
        var session = PickSession()
        var history = ColorHistory()
        for color in [red, blue, red] {
            session.append(color)
            history.add(color)
        }
        #expect(session.count == 3)
        #expect(history.items.count == 2)
    }

    @Test func testSessionLimitKeepsMostRecentSelections() {
        var session = PickSession()
        for _ in 0..<502 { session.append(red) }
        session.append(blue)
        #expect(session.count == 500)
        #expect(session.colors.last == blue)
        #expect(session.colors.first == red)
    }
}

@Suite struct SessionPersistenceTests {
    private let red = SRGBColor(red8: 255, green8: 0, blue8: 0)
    private let blue = SRGBColor(red8: 0, green8: 0, blue8: 255)

    @Test func testUndoLeavesPreviousPicksInOrder() {
        var session = PickSession()
        session.append(red)
        session.append(blue)
        let undoneBlue = session.undoLast()
        #expect(undoneBlue == blue)
        #expect(session.count == 1)
        #expect(session.last == red)
        #expect(session.formatted(as: .cssHex) == "#ff0000")
    }

    @Test func testUndoEmptySessionIsSafe() {
        var session = PickSession()
        let undoOnEmpty = session.undoLast()
        #expect(undoOnEmpty == nil)
        session.append(red)
        let undoneRed = session.undoLast()
        #expect(undoneRed == red)
        #expect(session.count == 0)
        let undoAfterLast = session.undoLast()
        #expect(undoAfterLast == nil)
        #expect((session.last) == nil)
    }

    @Test func testUndoDoesNotErasePreexistingHistoryOrFavorites() {
        var session = PickSession()
        var history = ColorHistory()
        history.add(red)
        history.toggleFavorite(id: history.items[0].id)
        session.append(red)
        session.append(blue)
        history.add(blue)
        session.undoLast()
        #expect(history.items.count == 2)
        #expect(history.favorites.count == 1)
        #expect(session.count == 1)
    }

    @Test func testSessionRoundTripPreservesOrderAndDuplicates() throws {
        var session = PickSession()
        for color in [red, blue, red] { session.append(color) }
        let loaded = try JSONDecoder().decode(PickSession.self, from: JSONEncoder().encode(session))
        #expect(loaded.colors == [red, blue, red])
        #expect(loaded.formatted(as: .cssHex) == "#ff0000\n#0000ff\n#ff0000")
    }

    @Test func testEmptySessionRoundTrip() throws {
        let encoded = try JSONEncoder().encode(PickSession())
        let loaded = try JSONDecoder().decode(PickSession.self, from: encoded)
        #expect(loaded.colors.isEmpty)
    }

    @Test func testSeparatorsProduceExpectedClipboardOutput() {
        var session = PickSession()
        session.append(red)
        session.append(blue)
        #expect(session.formatted(as: .cssHex, separator: .newLine) == "#ff0000\n#0000ff")
        #expect(session.formatted(as: .cssHex, separator: .blankLine) == "#ff0000\n\n#0000ff")
        #expect(session.formatted(as: .cssHex, separator: .commaSpace) == "#ff0000, #0000ff")
    }

    @Test func testSingleSelectionDoesNotGainSeparator() {
        var session = PickSession()
        session.append(red)
        for separator in SessionSeparator.allCases {
            #expect(session.formatted(as: .cssHex, separator: separator) == "#ff0000")
        }
    }

    @Test func testPreferencesRoundTripNewSeparator() throws {
        var preferences = AppPreferences()
        preferences.sessionSeparator = .blankLine
        let saved = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: saved)
        #expect(decoded.sessionSeparator == .blankLine)
    }

    @Test func testLegacyPreferencesKeepDefaultSeparator() throws {
        let legacy = #"{"defaultFormat":"cssHex","zoom":12}"#
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data(legacy.utf8))
        #expect(decoded.sessionSeparator == .newLine)
        #expect(decoded.zoom == 12)
    }

    @Test func testSeparatorCountAndTitlesStable() {
        #expect(Set(SessionSeparator.allCases.map(\.rawValue)).count == 3)
        #expect(SessionSeparator.newLine.title == "One per line")
    }
}

@Suite struct DisplayProfileHistoryTests {
    @Test func testProfileNameIsSavedWithColor() {
        var history = ColorHistory()
        history.add(SRGBColor(red8: 10, green8: 20, blue8: 30), displayProfileName: "Display P3")
        #expect(history.items.first?.displayProfileName == "Display P3")
    }

    @Test func testProfileNameAndFavoriteSurviveRepeatedPick() {
        let color = SRGBColor(red8: 10, green8: 20, blue8: 30)
        var history = ColorHistory()
        history.add(color, displayProfileName: "Display P3")
        let id = try! #require(history.items.first?.id)
        history.toggleFavorite(id: id)
        history.add(color)
        #expect((history.items.first?.displayProfileName) == nil)
        #expect(history.items.first?.id == id)
        #expect(history.items.first?.isFavorite == true)
    }

    @Test func testRepeatedPickUsesCurrentDisplayProfile() {
        let color = SRGBColor(red8: 10, green8: 20, blue8: 30)
        var history = ColorHistory()
        history.add(color, displayProfileName: "Display P3")
        let id = history.items[0].id
        history.add(color, displayProfileName: "sRGB IEC61966-2.1")
        #expect(history.items.count == 1)
        #expect(history.items[0].id == id)
        #expect(history.items[0].displayProfileName == "sRGB IEC61966-2.1")
    }

    @Test func testLegacyHistoryWithoutProfileDecodes() throws {
        let color = SRGBColor(red8: 11, green8: 22, blue8: 33)
        let history = ColorHistory(items: [PickedColor(color: color)])
        let data = try JSONEncoder().encode(history)
        let decoded = try JSONDecoder().decode(ColorHistory.self, from: data)
        #expect((decoded.items.first?.displayProfileName) == nil)
    }
}

/// Numeric and malformed-input coverage for the color-space formats already
/// exposed by the shared formatter and now supported by the same parser.
@Suite struct CSSColorSpaceRoundTripTests {
    private let examples: [SRGBColor] = [
        .init(red8: 0, green8: 0, blue8: 0),
        .init(red8: 255, green8: 255, blue8: 255),
        .init(red8: 255, green8: 0, blue8: 0),
        .init(red8: 0, green8: 255, blue8: 0),
        .init(red8: 0, green8: 0, blue8: 255),
        .init(red8: 8, green8: 77, blue8: 155),
        .init(red8: 232, green8: 174, blue8: 57),
        .init(red8: 110, green8: 110, blue8: 110)
    ]

    @Test func testRoundTripsThroughSupportedCSSSpaces() {
        var options = FormattingOptions()
        options.decimalPlaces = 8
        for representation: ColorOutputFormat in [.cssLab, .cssLCH, .cssOKLab, .cssOKLCH, .cssHWB, .cssDisplayP3] {
            for color in examples {
                let text = ColorFormatter.format(color, as: representation, options: options)
                guard let parsed = ColorParser.parse(text) else {
                    Issue.record("Cannot parse \(representation): \(text)")
                    continue
                }
                for (actual, expected) in zip(parsed.bytes, color.bytes) {
                    #expect(abs(actual - expected) <= 1, "\(text)")
                }
            }
        }
    }

    @Test func testAlphaIsPreservedAcrossColorSpaces() {
        let color = SRGBColor(red8: 73, green8: 104, blue8: 154, alpha: 0.4)
        var options = FormattingOptions()
        options.decimalPlaces = 7
        for format: ColorOutputFormat in [.cssLab, .cssLCH, .cssOKLab, .cssOKLCH, .cssHWB, .cssDisplayP3] {
            let text = ColorFormatter.format(color, as: format, options: options)
            #expect(abs((ColorParser.parse(text)?.alpha ?? -1) - (0.4)) <= (0.000001), "\(text)")
        }
    }

    @Test func testP3ReferenceWhiteBlackAndNeutral() {
        let black = DisplayP3Color(red: 0, green: 0, blue: 0).toSRGB()
        let white = DisplayP3Color(red: 1, green: 1, blue: 1).toSRGB()
        #expect(black.bytes == [0, 0, 0])
        #expect(white.bytes == [255, 255, 255])
        let neutral = DisplayP3Color(red: 0.5, green: 0.5, blue: 0.5).toSRGB()
        for channel in neutral.bytes { #expect(abs((channel) - (128)) <= (1)) }
    }

    @Test func testP3OutOfSRGBGamutIsClippedPredictably() {
        let wideRed = ColorParser.parse("color(display-p3 1 0 0)")
        #expect(wideRed?.bytes == [255, 0, 0])
        let wideGreen = ColorParser.parse("color(display-p3 0 1 0)")
        #expect(wideGreen?.bytes == [0, 255, 0])
    }

    @Test func testHWBGrayscaleWhenWhitePlusBlackAtLeastOne() {
        #expect(ColorParser.parse("hwb(240 80% 80%)")?.bytes == [128, 128, 128])
        #expect(ColorParser.parse("hwb(120 100% 0%)")?.bytes == [255, 255, 255])
    }

    @Test func testOKLabKnownNeutralAndPrimaries() {
        let black = OKLabColor.fromSRGB(.init(red8: 0, green8: 0, blue8: 0))
        #expect(abs((black.lightness) - (0)) <= (0.000001))
        let white = OKLabColor.fromSRGB(.init(red8: 255, green8: 255, blue8: 255))
        #expect(abs((white.lightness) - (1)) <= (0.00001))
        let red = OKLabColor.fromSRGB(.init(red8: 255, green8: 0, blue8: 0))
        #expect(abs((red.lightness) - (0.62796)) <= (0.0001))
        #expect(abs((red.a) - (0.22486)) <= (0.0001))
    }

    @Test func testCSSAngleUnitsAndFunctionCasing() {
        #expect(ColorParser.parse("HSL(0.5turn 100% 50%)")?.bytes == [0, 255, 255])
        #expect(ColorParser.parse("hwb(200grad 0% 0%)")?.bytes == [0, 255, 255])
        #expect(ColorParser.parse("OKLCH(0% 0 3.141592653589793rad)")?.bytes == [0, 0, 0])
        #expect(ColorParser.parse("COLOR(DISPLAY-P3 1 1 1)")?.bytes == [255, 255, 255])
        #expect(ColorParser.parse("color(display-p3 100% 100% 100% / 50%)")?.bytes == [255, 255, 255])
        #expect(ColorParser.parse("color(display-p3 100% 100% 100% / 50%)")?.alpha ?? 0 == 0.5)
    }

    @Test func testBadInputsRejectedWithoutChangingColor() {
        let invalid = [
            "oklab(50 0.1 0.1)", "oklab(NaN% 0 0)", "oklab(30% inf 0)",
            "oklab(20% 0 0 / 2)", "oklab(20% 0 0 / )", "oklab(30% 0 0, 0.8)",
            "lch(40% -0.2 50)", "lch(20% 30 NaN)", "oklch(40% -0.2 50)", "oklch(50% 0.1 NaN)", "oklch(30% 0.5 180 / inf)",
            "hwb(30 30 20)", "hwb(30 40% 40% / -1)", "hwb(inf 30% 20%)",
            "color(srgb 1 0 0)", "color(display-p3 1 0)",
            "color(display-p3 1 infinity 0)", "color(display-p3 1 0 0 / 2)",
            "color(display-p3 1, 0, 0)"
        ]
        for input in invalid { #expect((ColorParser.parse(input)) == nil, "\(input)") }
    }

    @Test func testExistingPreferencesAndNewFormatDecode() throws {
        var prefs = AppPreferences()
        prefs.defaultFormat = .cssDisplayP3
        prefs.favoriteFormats.append(.cssDisplayP3)
        let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(prefs))
        #expect(restored.defaultFormat == .cssDisplayP3)
        #expect(restored.favoriteFormats.contains(.cssDisplayP3))
        let legacy = try JSONDecoder().decode(AppPreferences.self, from: Data(#"{"zoom":7,"defaultFormat":"cssHex"}"#.utf8))
        #expect(legacy.defaultFormat == .cssHex)
    }
}


/// The same pure coordinate mapping used by the native SwiftUI wheel.
@Suite struct ColorWheelGeometryTests {
    @Test func ringDragContinuesWhilePointerMovesAwayFromBand() {
        let diameter = 350.0
        let center = diameter / 2
        let zone = { (radius: Double) in
            ColorWheelGeometry.interactionZone(
                at: WheelPoint(x: center + radius, y: center),
                diameter: diameter, ringBand: 12, separator: 13)
        }
        // The press starts on the visible ring, but real mouse drags are not
        // perfectly circular and can cross the gap, disk and window bounds.
        let origin = zone(169)
        #expect(origin == .ring)
        for radius in [169.0, 160, 145, 80, 178, 210, 155, 169] {
            #expect(ColorWheelGeometry.dragZone(
                startedIn: origin, previous: .ring, current: zone(radius)) == .ring)
        }
    }

    @Test func ringDragUsesAngleEvenWhenPointerIsOutsideWheel() {
        let diameter = 350.0
        for radius in [20.0, 110, 169, 195, 280] {
            let point = WheelPoint(x: diameter / 2 + radius * sin(.pi * 0.7),
                                   y: diameter / 2 - radius * cos(.pi * 0.7))
            let lightness = ColorWheelGeometry.lightness(at: point, diameter: diameter)
            #expect(abs(lightness.value - 0.7) < 1e-10)
            #expect(!lightness.leftArc)
        }
    }

    @Test func diskDragCanMoveOntoRingAndReturnAfterGap() {
        let origin = ColorWheelGeometry.InteractionZone.disk
        var previous = origin
        let transitions: [(ColorWheelGeometry.InteractionZone,
                           ColorWheelGeometry.InteractionZone)] = [
            (.disk, .disk),
            (.inactive, .disk),
            (.ring, .ring),
            (.inactive, .ring),
            (.disk, .disk)
        ]
        for (current, expected) in transitions {
            let actual = ColorWheelGeometry.dragZone(
                startedIn: origin, previous: previous, current: current)
            #expect(actual == expected)
            previous = actual
        }
        #expect(ColorWheelGeometry.dragZone(
            startedIn: .inactive, previous: .inactive, current: .ring) == .inactive)
    }

    @Test func aSingleDragCanCrossFromDiskToRingWithoutAnotherSelection() {
        let diameter = 350.0
        let zone = { (radius: Double) in
            ColorWheelGeometry.interactionZone(
                at: WheelPoint(x: diameter / 2 + radius, y: diameter / 2),
                diameter: diameter, ringBand: 12, separator: 13)
        }
        // In a continuous pointer gesture, movement should be routed by
        // location rather than by whichever control originally had focus.
        #expect(zone(0) == .disk)
        #expect(zone(100) == .disk)
        #expect(zone(150) == .disk)
        #expect(zone(155) == .inactive) // native background shows through
        #expect(zone(163) == .ring)
        #expect(zone(169) == .ring) // centered on the visible lightness band
        #expect(zone(175) == .ring)
        #expect(zone(180) == .inactive)
        #expect(zone(140) == .disk) // return to disk without a second click
    }

    @Test func lightnessRingUsesWholeWheelCoordinatesAfterRouting() {
        let diameter = 350.0
        let ringBand = 12.0
        for leftArc in [false, true] {
            for lightness in [0.15, 0.35, 0.5, 0.75, 0.85] {
                let point = ColorWheelGeometry.ringPoint(
                    lightness: lightness, leftArc: leftArc,
                    diameter: diameter, bandWidth: ringBand)
                #expect(ColorWheelGeometry.interactionZone(
                    at: point, diameter: diameter, ringBand: ringBand,
                    separator: 13) == .ring)
                let restored = ColorWheelGeometry.lightness(at: point, diameter: diameter)
                #expect(abs(restored.value - lightness) < 1e-8)
                #expect(restored.leftArc == leftArc)
            }
        }
    }

    @Test func wheelInteractionIgnoresInvalidGeometry() {
        for point in [WheelPoint(x: .nan, y: 12), WheelPoint(x: 3, y: .infinity)] {
            #expect(ColorWheelGeometry.interactionZone(at: point, diameter: 350,
                                                       ringBand: 12, separator: 13) == .inactive)
        }
        #expect(ColorWheelGeometry.interactionZone(
            at: WheelPoint(x: 0, y: 0), diameter: 0,
            ringBand: 12, separator: 13) == .inactive)
        #expect(ColorWheelGeometry.interactionZone(
            at: WheelPoint(x: 15, y: 15), diameter: 35,
            ringBand: 12, separator: 13) == .inactive)
    }

    @Test func diskCardinalPositions() {
        let top = ColorWheelGeometry.hueSaturation(at: .init(x: 150, y: 0), diameter: 300)
        let right = ColorWheelGeometry.hueSaturation(at: .init(x: 300, y: 150), diameter: 300)
        let bottom = ColorWheelGeometry.hueSaturation(at: .init(x: 150, y: 300), diameter: 300)
        let left = ColorWheelGeometry.hueSaturation(at: .init(x: 0, y: 150), diameter: 300)
        #expect(abs(top.hue - 0) < 1e-10)
        #expect(abs(right.hue - 90) < 1e-10)
        #expect(abs(bottom.hue - 180) < 1e-10)
        #expect(abs(left.hue - 270) < 1e-10)
        #expect([top, right, bottom, left].allSatisfy { abs($0.saturation - 1) < 1e-10 })
    }

    @Test func diskAllowsFreeSaturationAndCenterKeepsHue() {
        let center = ColorWheelGeometry.hueSaturation(at: .init(x: 150, y: 150),
                                                      diameter: 300, fallbackHue: 217)
        #expect(center.hue == 217)
        #expect(center.saturation == 0)
        let quarter = ColorWheelGeometry.hueSaturation(at: .init(x: 150, y: 112.5), diameter: 300)
        #expect(abs(quarter.saturation - 0.25) < 1e-10)
        let outside = ColorWheelGeometry.hueSaturation(at: .init(x: 150, y: -30), diameter: 300)
        #expect(outside.saturation == 1)
    }

    @Test func diskRoundTrip() {
        for hue in stride(from: 0.0, through: 330.0, by: 30) {
            for saturation in [0.2, 0.45, 0.8, 1.0] {
                let point = ColorWheelGeometry.diskPoint(hue: hue, saturation: saturation, diameter: 350)
                let restored = ColorWheelGeometry.hueSaturation(at: point, diameter: 350)
                #expect(abs(restored.hue - hue) < 1e-8)
                #expect(abs(restored.saturation - saturation) < 1e-8)
            }
        }
    }

    @Test func lightnessArcAndMidBandPosition() {
        let diameter = 350.0
        let bandWidth = 12.0
        for left in [false, true] {
            for lightness in [0.0, 0.15, 0.5, 0.85, 1.0] {
                let point = ColorWheelGeometry.ringPoint(lightness: lightness,
                    leftArc: left, diameter: diameter, bandWidth: bandWidth)
                let radialDistance = hypot(point.x - diameter/2, point.y - diameter/2)
                #expect(abs(radialDistance - (diameter - bandWidth)/2) < 1e-8)
                let restored = ColorWheelGeometry.lightness(at: point, diameter: diameter)
                #expect(abs(restored.value - lightness) < 1e-8)
                if lightness > 0 && lightness < 1 { #expect(restored.leftArc == left) }
            }
        }
    }

    @Test func wheelHarmonyMatchesStandaloneAngularOffsets() {
        let base = SRGBColor(hue: 30, saturation: 0.65, lightness: 0.45)
        for (kind, expected) in [
            (ColorHarmonyKind.complementary, [30.0, 210.0]),
            (.analogous, [30, 60, 0]),
            (.triadic, [30, 150, 270]),
            (.tetradic, [30, 120, 210, 300])
        ] {
            let colors = ColorHarmonyPalette.colors(for: base, kind: kind)
            #expect(colors.count == expected.count)
            for (color, hue) in zip(colors, expected) {
                #expect(abs(color.hsl.h - hue) < 1e-8)
            }
        }
    }

    @Test func monochromaticRangeClampsAtEnds() {
        let dark = SRGBColor(hue: 310, saturation: 0.85, lightness: 0.05)
        let light = SRGBColor(hue: 310, saturation: 0.85, lightness: 0.95)
        let darkPair = ColorHarmonyPalette.colors(for: dark, kind: .monochromatic)
        let lightPair = ColorHarmonyPalette.colors(for: light, kind: .monochromatic)
        #expect(darkPair.count == 2 && lightPair.count == 2)
        #expect(darkPair[0] == dark && lightPair[0] == light)
        #expect(abs(darkPair[1].hsl.l - 0.15) < 1e-8)
        #expect(abs(lightPair[1].hsl.l - 0.85) < 1e-8)
    }
}

@Suite struct LanguagePreferenceTests {
    @Test func languageDefaultsToSystemForLegacyDocuments() throws {
        let old = Data(#"{"appearance":"Dark","zoom":9}"#.utf8)
        let settings = try JSONDecoder().decode(AppPreferences.self, from: old)
        #expect(settings.language == .system)
        #expect(settings.zoom == 9)
        #expect(settings.appearance == .dark)
    }

    @Test func languagePersistsAcrossRoundTrips() throws {
        for language in AppLanguage.allCases {
            var preferences = AppPreferences()
            preferences.language = language
            let restored = try JSONDecoder().decode(AppPreferences.self,
                from: JSONEncoder().encode(preferences))
            #expect(restored.language == language)
        }
    }

    @Test func unsupportedSavedLanguageDoesNotDiscardOtherPreferences() throws {
        let old = Data(#"{"language":"italian","zoom":11}"#.utf8)
        let settings = try JSONDecoder().decode(AppPreferences.self, from: old)
        #expect(settings.language == .system)
        #expect(settings.zoom == 11)
    }

    @Test func systemLanguageResolvesSupportedPreferredLanguage() {
        #expect(AppLanguage.system.effectiveIdentifier(systemLanguages: ["fr-CH", "en-US"]) == "fr")
        #expect(AppLanguage.system.effectiveIdentifier(systemLanguages: ["de-CH", "fr-FR"]) == "fr")
        #expect(AppLanguage.system.effectiveIdentifier(systemLanguages: ["de-CH", "en-GB"]) == "en")
        #expect(AppLanguage.system.effectiveIdentifier(systemLanguages: ["de-CH"]) == "en")
        #expect(AppLanguage.french.effectiveIdentifier(systemLanguages: ["en-US"]) == "fr")
        #expect(AppLanguage.english.effectiveIdentifier(systemLanguages: ["fr-CH"]) == "en")
    }
}


@Suite struct ProductionColorContractsTests {
    @Test func catalogHas33StableUniqueFormatsAndPublicReferenceFamilies() {
        let formats = ColorOutputFormat.allCases
        #expect(formats.count == 33)
        #expect(Set(formats.map(\.rawValue)).count == formats.count)
        // Verify actual supported families from the public ColorSnapper page;
        // this does NOT assert exhaustive parity of proprietary format variants.
        for required in [ColorOutputFormat.genericHex, .cssHex, .cssLCH,
                         .cssOKLCH, .swiftNSColor, .swiftUIColor, .swiftUI,
                         .objcNSColor, .cgColor, .android, .java, .dotNet, .openGL] {
            #expect(formats.contains(required))
        }
        for format in formats {
            #expect(!format.title.isEmpty)
            let encoded = ColorFormatter.format(SRGBColor(red8: 40, green8: 93, blue8: 215), as: format)
            #expect(!encoded.isEmpty)
            #expect(!encoded.lowercased().contains("nan"))
            #expect(!encoded.lowercased().contains("inf"))
        }
    }

    @Test func p3GamutCheckOperatesBeforeSRGBClipping() {
        let saturatedP3Red = DisplayP3Color(red: 1, green: 0, blue: 0)
        #expect(saturatedP3Red.isOutsideSRGBGamut)
        #expect(!DisplayP3Color(red: 0.5, green: 0.5, blue: 0.5).isOutsideSRGBGamut)
        #expect(!DisplayP3Color.fromSRGB(SRGBColor(red8: 40, green8: 93, blue8: 215)).isOutsideSRGBGamut)
        let fallback = saturatedP3Red.toSRGB()
        #expect(fallback.red == 1)
        #expect(fallback.green == 0)
        #expect(fallback.blue == 0)
    }

    @Test func p3ExportRetainsEncodedComponentsWhenSRGBClips() {
        let p3 = DisplayP3Color(red: 1, green: 0.1, blue: 0.03)
        let fallback = p3.toSRGB(alpha: 0.6)
        let formatted = ColorFormatter.format(fallback, as: .cssDisplayP3, sourceP3: p3)
        #expect(formatted == "color(display-p3 1.000 0.100 0.030 / 0.600)")
        #expect(ColorFormatter.format(fallback, as: .cssRGB).hasPrefix("rgb("))
        let decoded = ColorParser.parseDetailed(formatted)
        #expect(decoded?.sourceP3 == p3)
        #expect(decoded?.color.alpha == fallback.alpha)
    }

    @Test func capturedProvenanceIsNotConfusedWithDocumentICCOrHDR() {
        #expect(ColorCaptureContract.workingSpace == "sRGB")
        #expect(ColorCaptureContract.captureSpace == "Display P3")
        #expect(ColorCaptureContract.captureDynamicRange == "SDR")
        #expect(!ColorCaptureContract.sourceApplicationICCIsKnown)
        #expect(!ColorCaptureContract.supportsHDRSampling)
        #expect(ColorCaptureContract.profileExplanation.contains("not preserved"))
        let p3 = DisplayP3Color(red: 0.9, green: 0.1, blue: 0.6)
        var history = ColorHistory()
        history.add(p3.toSRGB(), displayProfileName: "Display P3", sourceP3: p3)
        let decoded = try? JSONDecoder().decode(ColorHistory.self, from: JSONEncoder().encode(history))
        #expect(decoded?.items.first?.sourceP3 == p3)
        #expect(decoded?.items.first?.displayProfileName == "Display P3")
    }

    @Test func allLanguageChoicesAndSystemUnderscoreLocalesRemainCompatible() {
        #expect(Set(AppLanguage.allCases.map(\.rawValue)) == ["system", "english", "french"])
        #expect(AppLanguage.system.effectiveIdentifier(systemLanguages: ["de_CH", "fr_CH"]) == "fr")
        #expect(AppLanguage.system.effectiveIdentifier(systemLanguages: ["en_GB", "fr_FR"]) == "en")
    }
}
