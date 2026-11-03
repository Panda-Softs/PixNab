import Foundation

public struct CuratedPalette: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: PaletteCategory
    public let summary: String
    public let swatches: [PaletteSwatch]
    public let credit: String
    public let sourceURL: String?
    /// True for documented PixNab recipe variations; never claim these were hand-curated externally.
    public let isGenerated: Bool
}

public enum PaletteCatalog {
    public static let all: [CuratedPalette] = {
        typealias Row = (String, String)
        func make(_ id: String, _ name: String, _ category: PaletteCategory,
                  _ summary: String, _ hex: [Row], _ credit: String = "PixNab original",
                  _ source: String? = nil) -> CuratedPalette {
            let swatches = hex.map { label, value -> PaletteSwatch in
                guard let color = ColorParser.parseHex(value) else {
                    preconditionFailure("Invalid bundled palette \(id): \(value)")
                }
                return PaletteSwatch(name: label, color: color)
            }
            return CuratedPalette(id: id, name: name, category: category, summary: summary,
                                  swatches: swatches, credit: credit, sourceURL: source, isGenerated: false)
        }
        let featured = [
            make("harbor", "Harbor SaaS", .saas, "Clear dashboards, product-led landing pages", [("Background","#F7F9FC"),("Text","#18253F"),("Primary","#3265DC"),("Accent","#17B8A6"),("Surface","#E8EFFB")]),
            make("violet-signal", "Violet Signal", .saas, "Bold AI products and developer tools", [("Background","#FBFAFF"),("Text","#22183E"),("Primary","#7248D7"),("Accent","#E3A841"),("Surface","#EDE7FC")]),
            make("cloud-console", "Cloud Console", .saas, "Enterprise interfaces and analytics", [("Background","#F4F7FA"),("Text","#1B2A36"),("Primary","#147D92"),("Accent","#E79F3F"),("Surface","#E0EDF0")]),
            make("soft-code", "Soft Code", .saas, "Friendly documentation and API products", [("Background","#F9FAFB"),("Text","#293241"),("Primary","#4B6CB7"),("Accent","#F2B880"),("Surface","#E7EEF5")]),
            make("alpine-finance", "Alpine Finance", .fintech, "Trustworthy banking and insurance", [("Background","#F7FAF8"),("Text","#15332D"),("Primary","#146B54"),("Accent","#C7943D"),("Surface","#E1EEE7")]),
            make("copper-ledger", "Copper Ledger", .fintech, "Premium finance and wealth management", [("Background","#FCFAF7"),("Text","#34271E"),("Primary","#83522D"),("Accent","#1F8274"),("Surface","#F1E7D9")]),
            make("clear-pay", "Clear Pay", .fintech, "Simple mobile-first payment flows", [("Background","#F4FAFF"),("Text","#12233B"),("Primary","#1764AD"),("Accent","#2FC3A1"),("Surface","#DDEFF9")]),
            make("citrus-shop", "Citrus Shop", .ecommerce, "Energetic retail campaigns", [("Background","#FFF9F0"),("Text","#35291F"),("Primary","#CB541D"),("Accent","#6E9A37"),("Surface","#FFE8D0")]),
            make("clay-market", "Clay Market", .ecommerce, "Warm independent shops and makers", [("Background","#FDF8F5"),("Text","#48362D"),("Primary","#AD6652"),("Accent","#52786A"),("Surface","#EFDCCF")]),
            make("mono-commerce", "Mono Commerce", .ecommerce, "Elegant monochrome product catalogs", [("Background","#FAFAF8"),("Text","#252525"),("Primary","#515151"),("Accent","#BA6E40"),("Surface","#EAEAE6")]),
            make("rose-boutique", "Rose Boutique", .ecommerce, "Beauty and premium lifestyle retail", [("Background","#FFF7F7"),("Text","#3A2331"),("Primary","#9D3C68"),("Accent","#C59B67"),("Surface","#F4E0E7")]),
            make("ink-paper", "Ink & Paper", .editorial, "Readability-first magazines and blogs", [("Background","#FCFBF6"),("Text","#232A30"),("Primary","#425E79"),("Accent","#B4553A"),("Surface","#F1EEE6")]),
            make("aurora-editorial", "Aurora Editorial", .editorial, "Cultural publications and journals", [("Background","#F8F6F2"),("Text","#252637"),("Primary","#624D8C"),("Accent","#CF865D"),("Surface","#E9E2ED")]),
            make("signal-news", "Signal News", .editorial, "News sites with confident hierarchy", [("Background","#FFFFFF"),("Text","#181B22"),("Primary","#1A58A3"),("Accent","#D94A3A"),("Surface","#E8EDF4")]),
            make("gallery-neutral", "Gallery Neutral", .portfolio, "Photography and product portfolios", [("Background","#F7F6F3"),("Text","#2A2928"),("Primary","#68604E"),("Accent","#C29065"),("Surface","#E9E6DF")]),
            make("sunset-studio", "Sunset Studio", .portfolio, "Creative agencies and bold case studies", [("Background","#FFF7F2"),("Text","#3F2743"),("Primary","#B44279"),("Accent","#EF9B5B"),("Surface","#F6E5EB")]),
            make("electric-studio", "Electric Studio", .portfolio, "Experimental creative portfolios", [("Background","#F8F8FF"),("Text","#1B1748"),("Primary","#5443C9"),("Accent","#E15793"),("Surface","#E7E3FF")]),
            make("calm-clinic", "Calm Clinic", .wellness, "Health booking and accessible wellness", [("Background","#F6FBF9"),("Text","#203E3C"),("Primary","#287C75"),("Accent","#D89D7A"),("Surface","#E1F0EA")]),
            make("lavender-day", "Lavender Day", .wellness, "Mindfulness and self-care sites", [("Background","#FBF9FE"),("Text","#342A46"),("Primary","#8164A9"),("Accent","#D0A17D"),("Surface","#EEE6F4")]),
            make("soft-bloom", "Soft Bloom", .wellness, "Beauty, cosmetics, and yoga", [("Background","#FFF9FB"),("Text","#47313D"),("Primary","#AA577F"),("Accent","#8DAE8E"),("Surface","#F6E7EE")]),
            make("deep-woods", "Deep Woods", .nature, "Sustainable businesses and eco tourism", [("Background","#F5F7F0"),("Text","#213A2C"),("Primary","#3D7151"),("Accent","#D69B58"),("Surface","#DCE8D5")]),
            make("coastal-travel", "Coastal Travel", .nature, "Destinations, hotels, and nature", [("Background","#F7FBFC"),("Text","#183A46"),("Primary","#157991"),("Accent","#DDB579"),("Surface","#E0F0EF")]),
            make("terra-journey", "Terra Journey", .nature, "Outdoor brands and adventure guides", [("Background","#FAF7F1"),("Text","#3C372B"),("Primary","#78663D"),("Accent","#BE7359"),("Surface","#EBE6D8")]),
            make("midnight-app", "Midnight App", .darkUI, "Dark developer SaaS and productivity", [("Background","#151B29"),("Text","#F1F4FB"),("Primary","#89ABFA"),("Accent","#54DCC1"),("Surface","#252F43")]),
            make("neon-grid", "Neon Grid", .darkUI, "Gaming, music and expressive UI", [("Background","#101023"),("Text","#F5F2FF"),("Primary","#AD85F7"),("Accent","#6BE8B8"),("Surface","#252044")]),
            make("carbon-console", "Carbon Console", .darkUI, "Data-rich engineering dashboards", [("Background","#161B20"),("Text","#F0F3F5"),("Primary","#67B9D3"),("Accent","#D9B56B"),("Surface","#29343E")]),
            make("nord-selection", "Nord — Web UI selection", .designSystems,
                 "Selected Nord tokens for dark web interfaces", [("Background","#2E3440"),("Text","#ECEFF4"),("Primary","#88C0D0"),("Accent","#A3BE8C"),("Surface","#3B4252")],
                 "Arctic Ice Studio / Nord", "https://www.nordtheme.com/docs/colors-and-palettes/"),
            make("catppuccin-latte", "Catppuccin Latte — UI selection", .designSystems,
                 "Selected official Latte tokens for light interfaces", [("Background","#EFF1F5"),("Text","#4C4F69"),("Primary","#1E66F5"),("Accent","#40A02B"),("Surface","#CCD0DA")],
                 "Catppuccin (MIT)", "https://catppuccin.com/palette/"),
            make("catppuccin-mocha", "Catppuccin Mocha — UI selection", .designSystems,
                 "Selected official Mocha tokens for dark interfaces", [("Background","#1E1E2E"),("Text","#CDD6F4"),("Primary","#89B4FA"),("Accent","#A6E3A1"),("Surface","#313244")],
                 "Catppuccin (MIT)", "https://catppuccin.com/palette/"),
            make("dracula", "Dracula — Web UI selection", .designSystems,
                 "Selected Dracula theme tokens for code-oriented sites", [("Background","#282A36"),("Text","#F8F8F2"),("Primary","#BD93F9"),("Accent","#50FA7B"),("Surface","#44475A")],
                 "Dracula Theme", "https://draculatheme.com/spec")
        ]
        return featured + recipePalettes
    }()

    // 270 deterministic, original PixNab web-design compositions. This is not
    // a copy of Adobe Color's user-generated themes. Each of the nine application
    // categories has ten authored color stories in three carefully bounded
    // treatments: Soft, Balanced and Vivid. Semantic swatches intentionally
    // remain in background/text/primary/accent/surface order.
    private struct Story {
        let name: String
        let primary: Double
        let accent: Double
        init(_ name: String, _ primary: Double, _ accent: Double) {
            self.name = name; self.primary = primary; self.accent = accent
        }
    }

    private static let stories: [(PaletteCategory, [Story])] = [
        (.saas, [
            Story("Polar Dashboard", 218, 185), Story("Cloud Platform", 236, 167),
            Story("Orbit Analytics", 267, 186), Story("Signal Workspace", 200, 33),
            Story("Aurora Console", 174, 274), Story("Apex Developer", 258, 24),
            Story("Nova Productivity", 211, 146), Story("Relay Collaboration", 281, 167),
            Story("Matrix Intelligence", 243, 51), Story("Pixel Infrastructure", 189, 312)
        ]),
        (.ecommerce, [
            Story("Citrus Market", 22, 134), Story("Heritage Boutique", 349, 48),
            Story("Maison Atelier", 13, 173), Story("Urban Shopfront", 240, 27),
            Story("Artisan Goods", 31, 164), Story("Copper Commerce", 17, 199),
            Story("Bloom Storefront", 326, 92), Story("Olive Marketplace", 104, 27),
            Story("Vintage Retail", 9, 152), Story("Luxe Collection", 280, 38)
        ]),
        (.fintech, [
            Story("Trust Ledger", 159, 42), Story("Vault Banking", 217, 173),
            Story("Equity Insight", 198, 41), Story("Fintech Pulse", 172, 279),
            Story("Silver Capital", 226, 32), Story("Meridian Wealth", 190, 48),
            Story("Mint Transfers", 154, 215), Story("Secure Portfolio", 206, 119),
            Story("Credit Harbor", 221, 45), Story("Emerald Balance", 167, 33)
        ]),
        (.editorial, [
            Story("Sunday Journal", 17, 208), Story("Modern Press", 215, 8),
            Story("Literary Review", 280, 40), Story("Gallery Notes", 194, 18),
            Story("Weekend Digest", 44, 206), Story("Culture Signal", 327, 167),
            Story("Archive Daily", 205, 33), Story("Paper Chronicle", 40, 147),
            Story("Independent Voice", 15, 258), Story("Editorial Type", 173, 41)
        ]),
        (.portfolio, [
            Story("Creative Current", 286, 26), Story("Artist Spectrum", 322, 183),
            Story("Frame and Form", 197, 19), Story("Digital Atelier", 267, 150),
            Story("Canvas Motion", 31, 209), Story("Studio Portfolio", 350, 167),
            Story("Brand Showcase", 237, 52), Story("Type Foundry", 165, 330),
            Story("Design Bureau", 304, 42), Story("Chromatic Agency", 18, 274)
        ]),
        (.wellness, [
            Story("Botanical Calm", 153, 24), Story("Lavender Ritual", 277, 17),
            Story("Gentle Living", 179, 327), Story("Quiet Meditation", 214, 30),
            Story("Bloom Wellness", 333, 107), Story("Mindful Haven", 159, 38),
            Story("Serene Care", 184, 300), Story("Organic Retreat", 116, 28),
            Story("Soft Therapy", 255, 29), Story("Sunlit Yoga", 39, 171)
        ]),
        (.nature, [
            Story("Mountain Journey", 139, 29), Story("Coastal Breeze", 192, 40),
            Story("Evergreen Trails", 156, 27), Story("Desert Horizon", 29, 202),
            Story("Arctic Expedition", 200, 166), Story("Wildflower Path", 88, 327),
            Story("Tropic Escape", 179, 29), Story("Forest Heritage", 121, 38),
            Story("Ocean Adventure", 211, 25), Story("Terra Explorer", 73, 192)
        ]),
        (.darkUI, [
            Story("Night Terminal", 192, 267), Story("Neon Studio", 290, 176),
            Story("Graphite Metrics", 216, 40), Story("Quantum Console", 258, 171),
            Story("Deep Ocean UI", 197, 36), Story("Nocturne Reader", 318, 44),
            Story("Midnight Gaming", 286, 127), Story("Dark Command", 160, 223),
            Story("Eclipse Workspace", 231, 337), Story("Afterhours Dashboard", 174, 41)
        ]),
        (.designSystems, [
            Story("Token Atlas", 228, 154), Story("Component Kit", 258, 42),
            Story("UI Foundation", 184, 35), Story("System Spectrum", 290, 166),
            Story("Neutral Patterns", 204, 20), Story("Adaptive Layout", 176, 305),
            Story("Interface Core", 212, 29), Story("Design Primitive", 156, 248),
            Story("Semantic Grid", 244, 45), Story("Accessible Starter", 190, 34)
        ])
    ]

    private static var recipePalettes: [CuratedPalette] {
        stories.flatMap { category, variants in
            variants.flatMap { story in
                (0..<3).map { treatment -> CuratedPalette in
                    let isDark = category == .darkUI
                    let label = ["Soft", "Balanced", "Vivid"][treatment]
                    let background = SRGBColor(hue: story.primary, saturation: isDark ? 0.22 : 0.10 + Double(treatment) * 0.03,
                                               lightness: isDark ? 0.09 + Double(treatment) * 0.018 : 0.986 - Double(treatment) * 0.016)
                    let text = SRGBColor(hue: story.primary, saturation: isDark ? 0.12 : 0.20,
                                         lightness: isDark ? 0.955 - Double(treatment) * 0.01 : 0.13 - Double(treatment) * 0.009)
                    let primary = SRGBColor(hue: story.primary, saturation: 0.57 + Double(treatment) * 0.13,
                                            lightness: isDark ? 0.72 - Double(treatment) * 0.035 : 0.41 - Double(treatment) * 0.025)
                    let accent = SRGBColor(hue: story.accent, saturation: 0.53 + Double(treatment) * 0.14,
                                           lightness: isDark ? 0.71 - Double(treatment) * 0.023 : 0.50 - Double(treatment) * 0.024)
                    let surface = SRGBColor(hue: story.primary, saturation: isDark ? 0.24 : 0.16 + Double(treatment) * 0.04,
                                            lightness: isDark ? 0.19 + Double(treatment) * 0.014 : 0.925 - Double(treatment) * 0.025)
                    let fields: [(String, SRGBColor)] = [
                        ("Background", background), ("Text", text), ("Primary", primary),
                        ("Accent", accent), ("Surface", surface)
                    ]
                    let suffix = "\(treatment)"
                    let summary = isDark
                        ? "PixNab design recipe for dark web interfaces; review final contrast and states."
                        : "PixNab design recipe for web interfaces; review final contrast and states."
                    return CuratedPalette(
                        id: "recipe-\(category.rawValue)-\(ColorScaleGenerator.slugify(story.name))-\(suffix)",
                        name: "\(story.name) · \(label)", category: category, summary: summary,
                        swatches: fields.map { PaletteSwatch(name: $0.0, color: $0.1) },
                        credit: "PixNab original", sourceURL: nil, isGenerated: true
                    )
                }
            }
        }
    }
}
