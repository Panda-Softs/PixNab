import AppKit
import SwiftUI
import PixNabCore

/// A separate, focused workspace: opening it never opens the color wheel or
/// Colors & Formats. All controls work on the existing shared color state.
enum ColorStudioSection: String, CaseIterable, Identifiable {
    case discover, library, scales, compare
    var id: String { rawValue }
    var title: String {
        switch self {
        case .discover: return "Discover Palettes"
        case .library: return "My Palettes"
        case .scales: return "Color Scales"
        case .compare: return "Compare Colors"
        }
    }
    var symbol: String {
        switch self {
        case .discover: return "square.grid.2x2"
        case .library: return "books.vertical"
        case .scales: return "slider.horizontal.3"
        case .compare: return "arrow.left.arrow.right"
        }
    }
}

/// A single editing vocabulary across the Studio: HEX/CSS text, native macOS
/// color panel, and explicit sources. Editing a local field never changes the
/// global PixNab color; the header is the only always-global control.
private struct StudioSelection: Equatable {
    var color: SRGBColor
    var sourceP3: DisplayP3Color?
    init(_ color: SRGBColor, sourceP3: DisplayP3Color? = nil) {
        self.color = color; self.sourceP3 = sourceP3
    }
    init(_ swatch: PaletteSwatch) { self.init(swatch.color, sourceP3: swatch.sourceP3) }
}

private struct StudioColorControl: View {
    @ObservedObject var model: AppController
    @Binding var selection: StudioSelection
    let title: String
    var historyPick: ((PickedColor) -> Void)? = nil
    var isGlobal = false
    @State private var input = ""
    @State private var inputError = false

    private var sourcePalette: CuratedPalette? {
        PaletteCatalog.all.first { $0.id == model.studioPaletteID }
    }
    private var nativePicker: Binding<Color> {
        Binding(get: { selection.color.swiftUIColor(sourceP3: selection.sourceP3) },
                set: { newColor in
                    guard let updated = SRGBColor(nsColor: NSColor(newColor)) else { return }
                    // Native editor values are a fresh edit, not a P3 source capture.
                    selection = StudioSelection(updated)
                    inputError = false
                })
    }
    private func apply() {
        guard let parsed = ColorParser.parseDetailed(input) else { inputError = true; return }
        selection = StudioSelection(parsed.color, sourceP3: parsed.sourceP3)
        inputError = false
    }
    private func setHistory(_ item: PickedColor) {
        if let historyPick { historyPick(item) }
        else { selection = StudioSelection(item.color, sourceP3: item.sourceP3) }
        inputError = false
    }
    private func syncInput() {
        input = "#" + ColorFormatter.hex(selection.color)
        inputError = false
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                Text(LocalizedStringKey(title)).font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                RoundedRectangle(cornerRadius: 6)
                    .fill(selection.color.swiftUIColor(sourceP3: selection.sourceP3))
                    .frame(width: 29, height: 29)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.14)))
                    .accessibilityLabel(Text("Selected color preview"))
                ColorPicker("macOS color picker", selection: nativePicker, supportsOpacity: true)
                    .labelsHidden()
                    .help("Choose a color visually using the macOS color panel")
                Menu {
                    if !isGlobal {
                        Button("Active PixNab Color") {
                            selection = StudioSelection(model.selectedColor, sourceP3: model.selectedSourceP3)
                        }
                    }
                    if !model.store.history.items.isEmpty {
                        Menu("Recent Captures") {
                            ForEach(Array(model.store.history.items.prefix(20))) { item in
                                Button("#" + ColorFormatter.hex(item.color)) { setHistory(item) }
                            }
                        }
                    }
                    if let palette = sourcePalette {
                        Menu {
                            ForEach(palette.swatches.indices, id: \.self) { i in
                                let swatch = palette.swatches[i]
                                Button(swatch.name + " · #" + ColorFormatter.hex(swatch.color)) {
                                    selection = StudioSelection(swatch)
                                }
                            }
                        } label: {
                            Text("Selected Palette") + Text(": " + palette.name)
                        }
                    }
                } label: { Label("Choose from…", systemImage: "square.grid.2x2") }
                    .help("Choose from the active color, captured history or selected palette")
                if selection.sourceP3 != nil {
                    Text("P3").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                TextField("#RRGGBB or CSS color", text: $input)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(apply)
                    .accessibilityLabel(Text(LocalizedStringKey(title)))
                Button("Apply") { apply() }
                    .help("Apply the entered color to this field")
            }
            if inputError {
                Label("Invalid color. Enter HEX, rgb(), hsl() or a supported CSS color.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .onAppear(perform: syncInput)
        .onChange(of: selection) { _, _ in syncInput() }
    }
}

struct ColorStudioView: View {
    @ObservedObject var model: AppController
    @ObservedObject var store: LocalStore
    init(model: AppController) { self.model = model; self.store = model.store }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Color Studio").font(.title2.bold())
                    Text("Explore 300 web themes, edit colors, compare and export")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.pickColor() } label: {
                    Label("Pick from screen", systemImage: "eyedropper")
                }.controlSize(.small)
                Label("300 web palettes", systemImage: "square.grid.3x3")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8)

            StudioColorControl(model: model, selection: Binding(
                get: { StudioSelection(model.selectedColor, sourceP3: model.selectedSourceP3) },
                set: { model.select($0.color, sourceP3: $0.sourceP3) }),
                title: "Active PixNab Color", historyPick: { model.selectFromHistory($0) },
                isGlobal: true)
                .padding(.horizontal, 20)
                .padding(.bottom, 5)
            Text("The active color is shared with PixNab. Scale and comparison colors can be edited independently.")
                .font(.caption2).foregroundStyle(.secondary)
                .padding(.horizontal, 20).padding(.bottom, 10)

            Picker("Studio", selection: $model.studioSection) {
                ForEach(ColorStudioSection.allCases) { section in
                    Label(LocalizedStringKey(section.title), systemImage: section.symbol).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20).padding(.bottom, 14)
            Divider()

            Group {
                switch model.studioSection {
                case .discover: StudioDiscoverView(model: model)
                case .library: StudioLibraryView(model: model)
                case .scales: StudioScalesView(model: model)
                case .compare: StudioCompareView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 760, minHeight: 570)
        .preferredColorScheme(store.preferences.appearance.colorScheme)
        .environment(\.locale, AppLocalization.locale(for: store.preferences.language))
    }
}

private struct StudioSwatches: View {
    let swatches: [PaletteSwatch]
    var height: CGFloat = 52
    var body: some View {
        HStack(spacing: 4) {
            ForEach(swatches.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 5)
                    .fill(swatches[index].color.swiftUIColor(sourceP3: swatches[index].sourceP3))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.08)))
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .help("\(swatches[index].name) · #\(ColorFormatter.hex(swatches[index].color))")
                    .accessibilityLabel(Text("\(swatches[index].name): #\(ColorFormatter.hex(swatches[index].color))"))
            }
        }
    }
}

/// A website *simulation*, never an accessibility claim about an external site.
/// Contrast is calculated from the actual proposed opaque sRGB text/background.
private struct StudioWebsitePreview: View {
    @Environment(\.locale) private var locale
    let swatches: [PaletteSwatch]
    private var background: SRGBColor { swatches.first?.color ?? SRGBColor(red: 1, green: 1, blue: 1) }
    private var foreground: SRGBColor { swatches.count > 1 ? swatches[1].color : SRGBColor(red: 0, green: 0, blue: 0) }
    private var primary: SRGBColor { swatches.count > 2 ? swatches[2].color : foreground }
    private var accent: SRGBColor { swatches.count > 3 ? swatches[3].color : primary }
    private var surface: SRGBColor { swatches.count > 4 ? swatches[4].color : background }
    private var contrast: Double { ColorAccessibility.contrastRatio(background, foreground) }
    private var buttonText: SRGBColor {
        let white = SRGBColor(red: 1, green: 1, blue: 1)
        let black = SRGBColor(red: 0, green: 0, blue: 0)
        return ColorAccessibility.contrastRatio(primary, white) >= ColorAccessibility.contrastRatio(primary, black)
            ? white : black
    }
    private var buttonContrast: Double { ColorAccessibility.contrastRatio(primary, buttonText) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Website preview").font(.headline)
                Spacer()
                Text(String(format: AppLocalization.string("Text contrast %.2f:1", locale: locale),
                            locale: locale, arguments: [contrast]))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(contrast >= 4.5 ? Color.green : Color.orange)
                    .accessibilityLabel(Text(String(format: AppLocalization.string("Text contrast %.2f to 1", locale: locale),
                                                               locale: locale, arguments: [contrast])))
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 5) {
                        Circle().fill(accent.swiftUIColor).frame(width: 12, height: 12)
                        Text("STUDIO").font(.caption.bold())
                    }
                    Spacer()
                    Text("Product    Features    About").font(.caption2)
                }
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Make your next idea shine.")
                            .font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                        Text("A realistic preview of a landing-page color hierarchy.")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                        Text("Explore the product")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(buttonText.swiftUIColor)
                            .padding(.horizontal, 11).padding(.vertical, 8)
                            .background(primary.swiftUIColor, in: RoundedRectangle(cornerRadius: 7))
                    }
                    Spacer(minLength: 4)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(surface.swiftUIColor)
                        .frame(width: 140, height: 94)
                        .overlay {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3).fill(primary.swiftUIColor)
                                    .frame(width: 80, height: 8)
                                RoundedRectangle(cornerRadius: 3).fill(accent.swiftUIColor)
                                    .frame(width: 104, height: 8)
                                RoundedRectangle(cornerRadius: 3).fill(primary.swiftUIColor.opacity(0.4))
                                    .frame(width: 60, height: 8)
                            }
                        }
                }
            }
            .foregroundStyle(foreground.swiftUIColor)
            .padding(19)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
            .background(background.swiftUIColor, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.12)))
            HStack(spacing: 12) {
                Label(contrast >= 4.5 ? "Normal text AA" : "Normal text: check contrast",
                      systemImage: contrast >= 4.5 ? "checkmark.circle" : "exclamationmark.triangle")
                Text(String(format: AppLocalization.string("CTA contrast %.2f:1", locale: locale),
                            locale: locale, arguments: [buttonContrast]))
            }
            .font(.caption2)
            .foregroundStyle(contrast >= 4.5 && buttonContrast >= 4.5 ? Color.secondary : Color.orange)
            Text("Contrast indicators use opaque sRGB and the WCAG 2.x ratio; verify actual components and states.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct StudioDiscoverView: View {
    @ObservedObject var model: AppController
    @ObservedObject private var store: LocalStore
    @State private var query = ""
    @State private var category: PaletteCategory?
    @State private var recipeFilter = false
    @State private var featuredFilter = false
    @State private var saveError = false
    init(model: AppController) { self.model = model; self.store = model.store }

    private var results: [CuratedPalette] {
        PaletteCatalog.all.filter { item in
            (category == nil || item.category == category) &&
                (!recipeFilter || item.isGenerated) &&
                (!featuredFilter || !item.isGenerated) &&
                (query.isEmpty || [item.name, item.summary, item.category.title, item.credit]
                    .contains { $0.localizedStandardContains(query) })
        }
    }

    var body: some View {
        // Compute the 300-palette search result once for this render pass.
        let results = self.results
        let selected = results.first(where: { $0.id == model.studioPaletteID }) ?? results.first
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Palette collection").font(.headline)
                    Spacer()
                    Text("\(results.count) / \(PaletteCatalog.all.count)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                TextField("Search palettes, styles, use cases…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search palettes")
                Menu {
                    Button("All Categories") { category = nil }
                    Divider()
                    ForEach(PaletteCategory.allCases.filter { $0 != .generated }) { option in
                        Button(LocalizedStringKey(option.title)) { category = option }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(LocalizedStringKey(category?.title ?? "All Categories"))
                        Spacer()
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                }
                .menuStyle(.borderlessButton)
                Link("Explore more on Adobe Color", destination: URL(string: "https://color.adobe.com/")!)
                    .font(.caption)
                Picker("Collection", selection: Binding(
                    get: { featuredFilter ? 1 : (recipeFilter ? 2 : 0) },
                    set: { value in featuredFilter = value == 1; recipeFilter = value == 2 })) {
                    Text("All").tag(0)
                    Text("Featured").tag(1)
                    Text("Design recipes").tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(results) { palette in
                            Button { model.studioPaletteID = palette.id } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(palette.name).font(.subheadline.weight(.semibold))
                                        Spacer()
                                        if palette.id == selected?.id { Image(systemName: "checkmark.circle.fill") }
                                    }
                                    StudioSwatches(swatches: palette.swatches, height: 23)
                                    HStack {
                                        Text(LocalizedStringKey(palette.category.title))
                                        Spacer()
                                        Text(palette.isGenerated ? "Recipe" : "Featured")
                                    }.font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(9)
                                .background(palette.id == selected?.id ? Color.accentColor.opacity(0.13) : Color.secondary.opacity(0.055),
                                            in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(palette.name), \(palette.category.title)")
                        }
                    }.padding(.vertical, 3)
                }
            }
            .padding(17)
            .frame(width: 280)
            Divider()
            if let palette = selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey(palette.category.title))
                                .font(.caption.weight(.semibold)).foregroundStyle(.tint)
                            Text(palette.name).font(.title.bold())
                            Text(LocalizedStringKey(palette.summary)).foregroundStyle(.secondary)
                        }
                        StudioSwatches(swatches: palette.swatches, height: 75)
                        Text("Use sets the active PixNab color. Compare opens an independent A/B comparison.")
                            .font(.caption2).foregroundStyle(.secondary)
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(palette.swatches.indices, id: \.self) { index in
                                let swatch = palette.swatches[index]
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(LocalizedStringKey(swatch.name)).font(.caption2.weight(.medium)).lineLimit(1)
                                    Text("#" + ColorFormatter.hex(swatch.color))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Button("Use") { model.select(swatch.color, sourceP3: swatch.sourceP3) }
                                        .help("Set this swatch as the active PixNab color")
                                    Button("Compare") {
                                        model.studioComparisonCandidate = swatch
                                        model.studioSection = .compare
                                    }
                                    .help("Compare the active PixNab color with this swatch")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        StudioWebsitePreview(swatches: palette.swatches)
                        Button {
                            if let primary = palette.swatches.first(where: { $0.name == "Primary" }) {
                                model.studioScaleCandidate = primary
                                model.studioSection = .scales
                            }
                        } label: {
                            Label("Create a scale from Primary", systemImage: "slider.horizontal.3")
                        }
                        HStack(spacing: 9) {
                            Button { model.copyHarmonyPalette(palette.swatches.map(\.color)) } label: {
                                Label("Copy Palette", systemImage: "doc.on.doc")
                            }
                            Button {
                                let id = store.saveNamedPalette(name: palette.name, category: palette.category,
                                    swatches: palette.swatches)
                                if id != nil { model.studioSection = .library } else { saveError = true }
                            } label: {
                                Label("Save to My Palettes", systemImage: "plus.square.on.square")
                            }.buttonStyle(.borderedProminent)
                            Menu("Export") {
                                Button("ASE…") {
                                    model.exportAdobeSwatches(colors: palette.swatches.map(\.color),
                                                             name: palette.name, fileFormat: .ase)
                                }
                                Button("ACO…") {
                                    model.exportAdobeSwatches(colors: palette.swatches.map(\.color),
                                                             name: palette.name, fileFormat: .aco)
                                }
                                Divider()
                                Button("Copy CSS Tokens") {
                                    model.copyDesignText(PaletteTokenExporter.export(palette.swatches, name: palette.name, as: .css))
                                }
                                Button("CSS Tokens…") {
                                    model.exportDesignText(PaletteTokenExporter.export(palette.swatches, name: palette.name, as: .css),
                                                           suggestedName: ColorScaleGenerator.slugify(palette.name), ext: "css")
                                }
                                Button("JSON Tokens…") {
                                    model.exportDesignText(PaletteTokenExporter.export(palette.swatches, name: palette.name, as: .json),
                                                           suggestedName: ColorScaleGenerator.slugify(palette.name), ext: "json")
                                }
                                Button("SwiftUI Tokens…") {
                                    model.exportDesignText(PaletteTokenExporter.export(palette.swatches, name: palette.name, as: .swiftUI),
                                                           suggestedName: ColorScaleGenerator.slugify(palette.name), ext: "swift")
                                }
                            }
                        }
                        HStack(spacing: 7) {
                            Image(systemName: "info.circle").foregroundStyle(.secondary)
                            Text(palette.credit).font(.caption).foregroundStyle(.secondary)
                            if let address = palette.sourceURL, let link = URL(string: address) {
                                Link("Official palette source", destination: link).font(.caption)
                            }
                        }
                        if palette.isGenerated {
                            Text("Design recipe: an original PixNab composition, not a third-party or hand-curated Adobe theme.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Text("Built-in palettes are design starting points, not guarantees of accessible UI. Check each text/button pairing.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }.padding(23)
                }
                .alert("Cannot save palette", isPresented: $saveError) {
                    Button("OK", role: .cancel) { }
                } message: { Text("The palette library is full or the name is invalid.") }
            } else {
                ContentUnavailableView("No matching palettes", systemImage: "paintpalette",
                                       description: Text("Try another search or choose all categories."))
            }
        }
        .onChange(of: selected?.id) { _, newID in
            if let newID, model.studioPaletteID != newID { model.studioPaletteID = newID }
        }
    }
}

private struct StudioLibraryView: View {
    @ObservedObject var model: AppController
    @ObservedObject private var store: LocalStore
    @State private var selectedID: UUID?
    @State private var editingName = ""
    @State private var filter = ""
    @State private var confirmDelete = false
    @State private var saveError = false
    init(model: AppController) { self.model = model; self.store = model.store }

    private var filtered: [NamedPalette] {
        store.paletteLibrary.items.filter { filter.isEmpty || $0.name.localizedStandardContains(filter) ||
            $0.category.title.localizedStandardContains(filter) }
    }
    private var selected: NamedPalette? {
        filtered.first(where: { $0.id == selectedID }) ?? filtered.first
    }
    private func syncName() { editingName = selected?.name ?? "" }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("My Palettes").font(.headline)
                    Spacer()
                    Text("\(store.paletteLibrary.items.count)").font(.caption).foregroundStyle(.secondary)
                }
                TextField("Find a saved palette…", text: $filter)
                    .textFieldStyle(.roundedBorder)
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { item in
                            Button { selectedID = item.id; editingName = item.name } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(item.name).font(.subheadline.bold()).lineLimit(1)
                                        Spacer()
                                        if item.id == selected?.id { Image(systemName: "checkmark.circle.fill") }
                                    }
                                    StudioSwatches(swatches: item.swatches, height: 24)
                                    Text(LocalizedStringKey(item.category.title)).font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(9)
                                .background(item.id == selected?.id ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.055),
                                            in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Button { model.studioSection = .discover } label: {
                    Label("Discover more palettes", systemImage: "plus")
                }
                HStack(spacing: 8) {
                    Button { model.importPaletteLibraryBackup() } label: {
                        Label("Import…", systemImage: "square.and.arrow.down")
                    }
                    Button { model.exportPaletteLibraryBackup() } label: {
                        Label("Backup…", systemImage: "square.and.arrow.up")
                    }.disabled(store.paletteLibrary.items.isEmpty)
                }.controlSize(.small)
            }.padding(17).frame(width: 280)
            Divider()
            if let palette = selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Named palette").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                                HStack {
                                    TextField("Palette name", text: $editingName)
                                        .font(.title2.bold()).textFieldStyle(.roundedBorder)
                                        .accessibilityLabel("Rename palette")
                                        .onSubmit { _ = store.renamePalette(palette.id, name: editingName) }
                                    Button("Rename") {
                                        if !store.renamePalette(palette.id, name: editingName) { saveError = true }
                                    }
                                }
                            }
                            Menu {
                                ForEach(PaletteCategory.allCases) { option in
                                    Button(LocalizedStringKey(option.title)) {
                                        store.setPaletteCategory(palette.id, category: option)
                                    }
                                }
                            } label: {
                                Label(LocalizedStringKey(palette.category.title), systemImage: "tag")
                            }
                        }
                        StudioSwatches(swatches: palette.swatches, height: 66)
                        Text("Click a color to use it; right-click for a copy action. Reorder the swatches below.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(palette.swatches.indices, id: \.self) { index in
                            let swatch = palette.swatches[index]
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(swatch.color.swiftUIColor(sourceP3: swatch.sourceP3))
                                    .frame(width: 33, height: 31)
                                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.1)))
                                Text(LocalizedStringKey(swatch.name)).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                                Text("#"+ColorFormatter.hex(swatch.color))
                                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                                Button("Use") { model.select(swatch.color, sourceP3: swatch.sourceP3) }
                                    .help("Set active PixNab color")
                                Button("Compare") {
                                    model.studioComparisonCandidate = swatch
                                    model.studioSection = .compare
                                }
                                Button { model.copyDesignText("#" + ColorFormatter.hex(swatch.color)) } label: {
                                    Image(systemName: "doc.on.doc")
                                }.accessibilityLabel("Copy \(swatch.name)")
                                Button { _ = store.movePaletteSwatch(palette.id, from: index, to: index-1) } label: {
                                    Image(systemName: "arrow.up")
                                }.disabled(index == 0).accessibilityLabel("Move swatch up")
                                Button { _ = store.movePaletteSwatch(palette.id, from: index, to: index+1) } label: {
                                    Image(systemName: "arrow.down")
                                }.disabled(index == palette.swatches.count-1).accessibilityLabel("Move swatch down")
                                Button { _ = store.deletePaletteSwatch(palette.id, index: index) } label: {
                                    Image(systemName: "minus.circle")
                                }.disabled(palette.swatches.count <= 1).accessibilityLabel("Remove swatch")
                            }
                        }
                        HStack(spacing: 9) {
                            Button { _ = store.appendPaletteSwatch(palette.id,
                                swatch: PaletteSwatch(name: "Color \(palette.swatches.count+1)",
                                                      color: model.selectedColor, sourceP3: model.selectedSourceP3)) } label: {
                                Label("Add Active Color", systemImage: "plus")
                            }.disabled(palette.swatches.count >= 32)
                            Button { model.copyHarmonyPalette(palette.swatches.map(\.color)) } label: {
                                Label("Copy Palette", systemImage: "doc.on.doc")
                            }
                            Menu("Export") {
                                Button("ASE…") { model.exportAdobeSwatches(colors: palette.swatches.map(\.color), name: palette.name, fileFormat: .ase) }
                                Button("ACO…") { model.exportAdobeSwatches(colors: palette.swatches.map(\.color), name: palette.name, fileFormat: .aco) }
                                Divider()
                                Button("Copy CSS Tokens") { model.copyDesignText(PaletteTokenExporter.export(palette.swatches, name: palette.name, as: .css)) }
                                Button("CSS Tokens…") { model.exportDesignText(PaletteTokenExporter.export(palette.swatches, name: palette.name, as: .css), suggestedName: ColorScaleGenerator.slugify(palette.name), ext: "css") }
                                Button("JSON Tokens…") { model.exportDesignText(PaletteTokenExporter.export(palette.swatches, name: palette.name, as: .json), suggestedName: ColorScaleGenerator.slugify(palette.name), ext: "json") }
                                Button("SwiftUI Tokens…") { model.exportDesignText(PaletteTokenExporter.export(palette.swatches, name: palette.name, as: .swiftUI), suggestedName: ColorScaleGenerator.slugify(palette.name), ext: "swift") }
                            }
                        }
                        Divider()
                        HStack {
                            Button { _ = store.duplicatePalette(palette.id) } label: {
                                Label("Duplicate", systemImage: "square.on.square")
                            }
                            Spacer()
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Label("Delete Palette", systemImage: "trash")
                            }
                        }
                    }.padding(23)
                }
                .confirmationDialog("Delete palette?", isPresented: $confirmDelete) {
                    Button("Delete Palette", role: .destructive) {
                        _ = store.removePalette(palette.id)
                        selectedID = nil
                        syncName()
                    }
                } message: { Text("The saved palette cannot be restored.") }
                .alert("Cannot rename palette", isPresented: $saveError) {
                    Button("OK", role: .cancel) { }
                } message: { Text("A name between 1 and 100 characters is required.") }
                .onAppear { syncName() }
                .onChange(of: selected?.id) { _, _ in syncName() }
            } else {
                ContentUnavailableView("No saved palettes", systemImage: "books.vertical",
                                       description: Text("Save a curated palette, a harmony or a generated scale to start your library."))
            }
        }
    }
}

private struct StudioScalesView: View {
    @ObservedObject var model: AppController
    @ObservedObject private var store: LocalStore
    @State private var name = "brand"
    @State private var base = StudioSelection(SRGBColor(red8: 50, green8: 101, blue8: 220))
    @State private var format: ColorScaleFormat = .css
    @State private var saveError = false
    @State private var initialized = false
    init(model: AppController) { self.model = model; self.store = model.store }
    private var fileExtension: String {
        switch format { case .css: return "css"; case .json: return "json"; case .swiftUI: return "swift" }
    }
    private func loadCurrent() { base = StudioSelection(model.selectedColor, sourceP3: model.selectedSourceP3) }
    var body: some View {
        // Scale generation performs gamut mapping: reuse one result for swatches,
        // controls, token preview, and the copy/export actions of this render.
        let steps = ColorScaleGenerator.generate(from: base.color)
        let output = ColorScaleGenerator.export(steps, name: name, as: format)
        return ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OKLCH Color Scales").font(.title.bold())
                    Text("Start with any color. Edit its HEX, open the macOS color picker or choose from history and palettes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 15) {
                    StudioColorControl(model: model, selection: $base,
                                       title: "Scale Base Color (only for this scale)")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Token prefix").font(.subheadline.weight(.semibold))
                        TextField("brand", text: $name).textFieldStyle(.roundedBorder)
                        Text("11 steps · original color at 500").font(.caption2).foregroundStyle(.secondary)
                        Button("Load active PixNab color into scale", action: loadCurrent)
                            .font(.caption)
                    }.frame(width: 220)
                }
                VStack(alignment: .leading, spacing: 10) {
                    StudioSwatches(swatches: steps.map { PaletteSwatch(name: "\($0.number)", color: $0.color) }, height: 84)
                    HStack(spacing: 4) {
                        ForEach(steps, id: \.number) { step in
                            VStack(spacing: 5) {
                                Text("\(step.number)").font(.caption2.weight(.semibold))
                                Text("#" + ColorFormatter.hex(step.color))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Button("Use") { model.select(step.color) }
                                    .font(.caption2).help("Set this step as active PixNab color")
                            }.frame(maxWidth: .infinity)
                            .contextMenu {
                                Button("Copy Color") { model.copyDesignText("#"+ColorFormatter.hex(step.color)) }
                            }
                        }
                    }
                }
                HStack {
                    Text("Export design tokens").font(.headline)
                    Spacer()
                    Picker("Format", selection: $format) {
                        Text("CSS").tag(ColorScaleFormat.css)
                        Text("JSON").tag(ColorScaleFormat.json)
                        Text("SwiftUI").tag(ColorScaleFormat.swiftUI)
                    }.pickerStyle(.segmented).frame(width: 260)
                }
                ScrollView(.horizontal) {
                    Text(output)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
                .background(Color.secondary.opacity(0.065), in: RoundedRectangle(cornerRadius: 10))
                HStack(spacing: 10) {
                    Button { model.copyDesignText(output) } label: {
                        Label("Copy Tokens", systemImage: "doc.on.doc")
                    }.buttonStyle(.borderedProminent)
                    Button { model.exportDesignText(output, suggestedName: ColorScaleGenerator.slugify(name), ext: fileExtension) } label: {
                        Label("Export File…", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        let swatches = steps.map { PaletteSwatch(name: "\($0.number)", color: $0.color) }
                        if store.saveNamedPalette(name: name, category: .generated, swatches: swatches) != nil {
                            model.studioSection = .library
                        } else { saveError = true }
                    } label: { Label("Save in My Palettes", systemImage: "plus.square") }
                }
                if base.sourceP3?.isOutsideSRGBGamut == true {
                    Label("Selected P3 color is outside sRGB; this scale uses its sRGB preview.", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                Text("Generated scales use OKLCH chroma reduction in sRGB. Review final text contrast, hover and disabled states.")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(23)
        }
        .alert("Cannot save palette", isPresented: $saveError) {
            Button("OK", role: .cancel) { }
        } message: { Text("Enter a name between 1 and 100 characters; the library must have fewer than 500 palettes.") }
        .onAppear {
            guard !initialized else { return }
            initialized = true
            if let candidate = model.studioScaleCandidate { base = StudioSelection(candidate) }
            else { loadCurrent() }
        }
        .onChange(of: model.studioScaleCandidate) { _, candidate in
            if let candidate { base = StudioSelection(candidate) }
        }
    }
}

private struct StudioCompareView: View {
    @ObservedObject var model: AppController
    @State private var first = StudioSelection(SRGBColor(red8: 94, green8: 94, blue8: 94))
    @State private var second = StudioSelection(SRGBColor(red8: 50, green8: 101, blue8: 220))
    @State private var initialized = false
    init(model: AppController) { self.model = model }
    private var score: Double {
        ColorDifference.deltaE2000(first.color, second.color,
            sourceP3A: first.sourceP3, sourceP3B: second.sourceP3)
    }
    private var okScore: Double { ColorDifference.deltaEOK(first.color, second.color) }
    private func loadActiveIntoA() { first = StudioSelection(model.selectedColor, sourceP3: model.selectedSourceP3) }
    private func loadActiveIntoB() { second = StudioSelection(model.selectedColor, sourceP3: model.selectedSourceP3) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare Two Colors").font(.title.bold())
                    Text("A and B are independent. Choose a color with HEX, the macOS picker, recent captures or the selected palette.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 14) {
                    comparisonCard(title: "Color A", selection: $first)
                    comparisonCard(title: "Color B", selection: $second)
                }
                HStack(spacing: 10) {
                    Button("Swap A ↔ B") { let old = first; first = second; second = old }
                    Button("Load active into A", action: loadActiveIntoA)
                    Button("Load active into B", action: loadActiveIntoB)
                    Spacer()
                }
                .controlSize(.small)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Color difference ΔE00").font(.headline)
                            Text(String(format: "%.4f", score))
                                .font(.system(size: 42, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("OKLab distance (sRGB preview)").font(.caption).foregroundStyle(.secondary)
                            Text(String(format: "%.4f", okScore))
                                .font(.system(.title3, design: .monospaced)).monospacedDigit()
                        }
                    }
                    Text("0 means identical Lab coordinates. A larger ΔE00 indicates greater modeled perceptual difference. ΔE is not a contrast score.")
                        .font(.caption).foregroundStyle(.secondary)
                    if first.sourceP3 != nil || second.sourceP3 != nil {
                        Label("P3-aware ΔE00 uses captured P3 values when available; ΔEOK uses sRGB previews.",
                              systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(17).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.065), in: RoundedRectangle(cornerRadius: 12))
                Text("The comparison does not change the active PixNab color. Use ‘Set A active’ or ‘Set B active’ explicitly.")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(23)
        }
        .onAppear {
            guard !initialized else { return }
            initialized = true
            loadActiveIntoA()
            if let candidate = model.studioComparisonCandidate {
                second = StudioSelection(candidate)
            } else if let captured = model.store.history.items.dropFirst().first {
                second = StudioSelection(captured.color, sourceP3: captured.sourceP3)
            }
        }
        .onChange(of: model.studioComparisonCandidate) { _, candidate in
            if let candidate { second = StudioSelection(candidate) }
        }
    }

    private func comparisonCard(title: String, selection: Binding<StudioSelection>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(selection.wrappedValue.color.swiftUIColor(sourceP3: selection.wrappedValue.sourceP3))
                .frame(height: 92)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.1)))
            StudioColorControl(model: model, selection: selection, title: title)
            HStack(spacing: 8) {
                Button(LocalizedStringKey(title == "Color A" ? "Set A active" : "Set B active")) {
                    model.select(selection.wrappedValue.color, sourceP3: selection.wrappedValue.sourceP3)
                }
                Button { model.copyDesignText("#"+ColorFormatter.hex(selection.wrappedValue.color)) } label: {
                    Label("Copy HEX", systemImage: "doc.on.doc")
                }
            }.controlSize(.small)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
    }
}
