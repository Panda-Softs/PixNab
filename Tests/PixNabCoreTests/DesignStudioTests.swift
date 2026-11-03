import Foundation
import Testing
@testable import PixNabCore

@Suite("Color Studio mathematical and data regression tests")
struct DesignStudioTests {
    @Test func ciede2000PublishedReferencePairs() {
        // Sharma, Wu & Dalal supplementary test data, the original Lab pairs.
        let cases: [(CIELabColor, CIELabColor, Double)] = [
            (.init(lightness: 50, a: 2.6772, b: -79.7751),
             .init(lightness: 50, a: 0, b: -82.7485), 2.0425),
            (.init(lightness: 50, a: 3.1571, b: -77.2803),
             .init(lightness: 50, a: 0, b: -82.7485), 2.8615),
            (.init(lightness: 50, a: 2.8361, b: -74.0200),
             .init(lightness: 50, a: 0, b: -82.7485), 3.4412),
            (.init(lightness: 50, a: -1.3802, b: -84.2814),
             .init(lightness: 50, a: 0, b: -82.7485), 1.0000),
            (.init(lightness: 50, a: -1.1848, b: -84.8006),
             .init(lightness: 50, a: 0, b: -82.7485), 1.0000),
            (.init(lightness: 50, a: -0.9009, b: -85.5211),
             .init(lightness: 50, a: 0, b: -82.7485), 1.0000),
            (.init(lightness: 50, a: 0, b: 0),
             .init(lightness: 50, a: -1, b: 2), 2.3669)
        ]
        for (a,b,expected) in cases {
            #expect(abs(ColorDifference.deltaE2000(a,b) - expected) < 0.00011)
            #expect(abs(ColorDifference.deltaE2000(b,a) - expected) < 0.00011)
        }
    }

    @Test func colorDifferenceIdenticalAndSymmetric() {
        for a in [SRGBColor(red8: 0, green8: 0, blue8: 0),
                  SRGBColor(red8: 255, green8: 255, blue8: 255),
                  SRGBColor(red8: 60, green8: 140, blue8: 230)] {
            #expect(abs(ColorDifference.deltaE2000(a,a)) < 0.000001)
            #expect(ColorDifference.deltaEOK(a,a) == 0)
        }
        let a = SRGBColor(red8: 200,green8: 22,blue8: 40)
        let b = SRGBColor(red8: 20,green8: 130,blue8: 201)
        #expect(abs(ColorDifference.deltaE2000(a,b) - ColorDifference.deltaE2000(b,a)) < 1e-12)
        #expect(ColorDifference.deltaE2000(a,b) > 10)
    }

    @Test func comparesOriginalDisplayP3NotClippedPreview() {
        let wide = DisplayP3Color(red: 1, green: 0, blue: 0)
        let clipped = wide.toSRGB()
        #expect(wide.isOutsideSRGBGamut)
        #expect(abs(ColorDifference.deltaE2000(clipped,clipped)) < 1e-8)
        #expect(ColorDifference.deltaE2000(clipped, clipped, sourceP3A: wide) > 0.5)
        let neutralP3 = DisplayP3Color.fromSRGB(SRGBColor(red8: 128,green8: 128,blue8: 128))
        let neutralSRGB = neutralP3.toSRGB()
        #expect(ColorDifference.deltaE2000(neutralSRGB,neutralSRGB, sourceP3A:neutralP3) < 0.03)
    }

    @Test func wcagContrastNumerics() {
        let white = SRGBColor(red: 1,green: 1,blue: 1)
        let black = SRGBColor(red: 0,green: 0,blue: 0)
        #expect(abs(ColorAccessibility.contrastRatio(white,black)-21) < 1e-8)
        #expect(ColorAccessibility.contrastRatio(black,white) == ColorAccessibility.contrastRatio(white,black))
        #expect(ColorAccessibility.contrastRatio(white,white) == 1)
        #expect(ColorAccessibility.contrastRatio(white, SRGBColor(red8: 118,green8: 118,blue8: 118)) > 4.5)
    }

    @Test func scaleKeepsAnchorAndOrderWithGamutMapping() {
        for original in [SRGBColor(red8: 50,green8: 101,blue8: 220),
                         SRGBColor(red8: 255,green8: 0,blue8: 255),
                         SRGBColor(red8: 120,green8: 120,blue8: 120),
                         SRGBColor(red8: 0,green8: 0,blue8: 0),
                         SRGBColor(red8: 255,green8: 255,blue8: 255)] {
            let steps = ColorScaleGenerator.generate(from: original)
            #expect(steps.map(\.number) == ColorScaleGenerator.levels)
            #expect(steps[5].color == original)
            let lightness = steps.map { OKLabColor.fromSRGB($0.color).lightness }
            for index in 1..<lightness.count {
                #expect(lightness[index] <= lightness[index - 1] + 0.00002)
            }
            for step in steps {
                #expect([step.color.red,step.color.green,step.color.blue].allSatisfy { $0.isFinite && (0...1).contains($0) })
            }
        }
    }

    @Test func scaleExportsSafeCodeForEachFormat() throws {
        let steps = ColorScaleGenerator.generate(from: SRGBColor(red8: 50,green8: 101,blue8: 220))
        let css = ColorScaleGenerator.export(steps, name: "Été & 🚀 / 42", as: .css)
        let json = ColorScaleGenerator.export(steps, name: "Été & 🚀 / 42", as: .json)
        let swiftUI = ColorScaleGenerator.export(steps, name: "Été & 🚀 / 42", as: .swiftUI)
        #expect(css.contains("--ete-42-500: #3265dc;"))
        let data = try #require(json.data(using: .utf8))
        let parsed = try #require(JSONSerialization.jsonObject(with: data) as? [String: [String: String]])
        #expect(parsed["ete-42"]?["500"] == "#3265dc")
        #expect(swiftUI.contains("static let shade500 = Color("))
        #expect(!swiftUI.contains("🚀"))
        #expect(ColorScaleGenerator.slugify("***") == "color")
    }

    @Test func catalogIsCompleteCategorizedCreditedAndValid() {
        let catalog = PaletteCatalog.all
        #expect(catalog.count >= 30)
        #expect(Set(catalog.map(\.id)).count == catalog.count)
        #expect(Set(catalog.map(\.category)).count == PaletteCategory.allCases.count - 1)
        #expect(catalog.allSatisfy { !$0.name.isEmpty && !$0.summary.isEmpty &&
            !$0.credit.isEmpty && $0.swatches.count == 5 })
        #expect(catalog.filter { $0.sourceURL != nil }.count >= 4)
        #expect(catalog.filter { $0.sourceURL == nil }.allSatisfy { $0.credit == "PixNab original" })
        #expect(catalog.first(where: {$0.id == "nord-selection"})?.swatches.first?.color.bytes == [46,52,64])
        #expect(catalog.first(where: {$0.id == "catppuccin-mocha"})?.swatches.first?.color.bytes == [30,30,46])
        #expect(catalog.first(where: {$0.id == "dracula"})?.swatches.first?.color.bytes == [40,42,54])
    }

    @Test func namedPalettesCreateDuplicateRenameReorderAndDelete() throws {
        let red = PaletteSwatch(name: "Red", color: SRGBColor(red8:255,green8:0,blue8:0))
        let blue = PaletteSwatch(name: "Blue", color: SRGBColor(red8:0,green8:0,blue8:255))
        var library = PaletteLibrary()
        let invalidName = library.add(name: " ", category: .saas, swatches: [red])
        #expect(invalidName == nil)
        let invalidEmpty = library.add(name: "Empty", category: .saas, swatches: [])
        #expect(invalidEmpty == nil)
        let created = library.add(name: "Brand",category: .saas,swatches:[red,blue])
        let id = try #require(created)
        let added = library.addSwatch(id, swatch: red)
        #expect(added)
        let moved = library.moveSwatch(id, from: 2, to: 0)
        #expect(moved)
        #expect(library.items[0].swatches.first?.name == "Red")
        let invalidMove = library.moveSwatch(id, from: -1, to: 0)
        #expect(!invalidMove)
        let removedSwatch = library.removeSwatch(id, at: 2)
        #expect(removedSwatch)
        let renamed = library.rename(id, to: "New Brand")
        #expect(renamed)
        let recategorized = library.changeCategory(id, to: .ecommerce)
        #expect(recategorized)
        let duplicated = library.duplicate(id)
        let copy = try #require(duplicated)
        #expect(copy != id)
        #expect(library.items[0].swatches == library.items[1].swatches)
        let removed = library.remove(id)
        #expect(removed)
        let secondRemoval = library.remove(id)
        #expect(!secondRemoval)
        let encoded = try JSONEncoder().encode(library)
        let restored = try JSONDecoder().decode(PaletteLibrary.self, from: encoded)
        #expect(restored == library)
    }

    @Test func originalP3SwatchSurvivesLibraryPersistence() throws {
        let p3 = DisplayP3Color(red:1,green:0,blue:0)
        let swatch = PaletteSwatch(name:"Captured", color:p3.toSRGB(), sourceP3:p3)
        var library = PaletteLibrary()
        _ = library.add(name:"Wide Gamut",category:.designSystems,swatches:[swatch])
        let encoded = try JSONEncoder().encode(library)
        let decoded = try JSONDecoder().decode(PaletteLibrary.self,from:encoded)
        #expect(decoded.items[0].swatches[0].sourceP3 == p3)
        #expect(decoded.items[0].swatches[0].color == swatch.color)
    }
}

@Suite("Semantic palette tokens")
struct SemanticTokenTests {
    @Test func roleKeysAreStableAndCollisionFree() throws {
        let red = SRGBColor(red8:255,green8:0,blue8:0,alpha:0.5)
        let swatches = [PaletteSwatch(name:"Primary Color",color:red),
                        PaletteSwatch(name:"Primary Color",color:red),
                        PaletteSwatch(name:"Background",color:SRGBColor(red:1,green:1,blue:1))]
        let css = PaletteTokenExporter.export(swatches,name:"Site Web",as:.css)
        #expect(css.contains("--site-web-primary-color: #ff000080;"))
        #expect(css.contains("--site-web-primary-color-2: #ff000080;"))
        let json = PaletteTokenExporter.export(swatches,name:"Site Web",as:.json)
        let data = try #require(json.data(using:.utf8))
        let parsed = try #require(JSONSerialization.jsonObject(with:data) as? [String:[String:String]])
        #expect(parsed["site-web"]?.count == 3)
    }

    @Test func trueP3OverrideOnlyForP3Capture() {
        let p3 = DisplayP3Color(red:1,green:0,blue:0)
        let swatches = [PaletteSwatch(name:"Primary",color:p3.toSRGB(),sourceP3:p3),
                        PaletteSwatch(name:"Accent",color:SRGBColor(red8:0,green8:255,blue8:0))]
        let css = PaletteTokenExporter.export(swatches,name:"Brand",as:.css)
        #expect(css.contains("@supports (color: color(display-p3 1 0 0))"))
        #expect(css.contains("--brand-primary: color(display-p3"))
        #expect(!css.contains("--brand-accent: color(display-p3"))
        let swift = PaletteTokenExporter.export(swatches,name:"Brand",as:.swiftUI)
        #expect(swift.contains("Color(.displayP3"))
        #expect(swift.contains("Color(.sRGB"))
    }
}

@Suite("Palette backup merge safety")
struct PaletteImportTests {
    @Test func mergePreservesCurrentPalettesAndRegeneratesImportedIdentities() throws {
        let swatch = PaletteSwatch(name: "Test", color: SRGBColor(red8:12,green8:34,blue8:56))
        var current = PaletteLibrary()
        var external = PaletteLibrary()
        let id = try #require({ current.add(name:"Current",category:.saas,swatches:[swatch]) }())
        let importedID = try #require({ external.add(name:"Imported",category:.generated,swatches:[swatch]) }())
        let count = current.merge(external)
        #expect(count == 1)
        #expect(current.items.count == 2)
        #expect(current.items[1].id == id)
        #expect(current.items[0].id != importedID)
        #expect(current.items[0].category == .generated)
    }
    @Test func rejectInvalidImportAtomically() {
        let color = PaletteSwatch(name: "Test", color: SRGBColor(red:1,green:1,blue:1))
        var current = PaletteLibrary()
        _ = current.add(name:"Original",category:.saas,swatches:[color])
        let before = current
        let invalid = PaletteLibrary(items:[NamedPalette(name:"",category:.saas,swatches:[color])])
        let count = current.merge(invalid)
        #expect(count == nil)
        #expect(current == before)
    }
}

@Suite("Web-design palette catalogue v0.22.0")
struct CatalogExpansionTests {
    @Test func containsExactly300IdentifiablePalettes() {
        let palettes = PaletteCatalog.all
        #expect(palettes.count == 300)
        #expect(Set(palettes.map(\.id)).count == 300)
        #expect(Set(palettes.map(\.name)).count == 300)
        #expect(palettes.filter(\.isGenerated).count == 270)
        #expect(palettes.filter { !$0.isGenerated }.count == 30)
        #expect(palettes.allSatisfy { $0.swatches.count == 5 && !$0.summary.isEmpty })
    }

    @Test func sectorCoverageAndRoleNamesRemainStable() {
        for category in PaletteCategory.allCases where category != .generated {
            let group = PaletteCatalog.all.filter { $0.category == category }
            #expect(group.count >= 30)
            #expect(group.filter(\.isGenerated).count == 30)
        }
        for recipe in PaletteCatalog.all.filter(\.isGenerated) {
            #expect(recipe.swatches.map(\.name) == ["Background", "Text", "Primary", "Accent", "Surface"])
            #expect(recipe.credit == "PixNab original")
            #expect(recipe.sourceURL == nil)
        }
    }

    @Test func recipePalettesAreUniqueAndReadable() {
        let palettes = PaletteCatalog.all.filter(\.isGenerated)
        let swatchSets = palettes.map { $0.swatches.map { ColorFormatter.hex($0.color) }.joined(separator: "|") }
        #expect(Set(swatchSets).count == 270)
        for palette in palettes {
            let colors = palette.swatches.map(\.color)
            #expect(ColorAccessibility.contrastRatio(colors[0], colors[1]) >= 7)
            #expect(ColorAccessibility.contrastRatio(colors[4], colors[1]) >= 4.5)
            #expect(colors.allSatisfy { [ $0.red, $0.green, $0.blue ].allSatisfy { $0.isFinite && (0...1).contains($0) } })
        }
    }
}
