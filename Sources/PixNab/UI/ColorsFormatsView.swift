import AppKit
import SwiftUI
import PixNabCore

struct ColorsFormatsView: View {
    @ObservedObject var model: AppController
    @ObservedObject var store: LocalStore
    @State private var search = ""
    @State private var favoritesOnly = false
    @State private var historySearch = ""
    @State private var favoriteFormatsOnly = false
    @State private var colorInput = ""
    @State private var inputError = false
    @State private var confirmClear = false

    init(model: AppController) { self.model = model; self.store = model.store }
    private var visibleColors: [PickedColor] {
        ColorHistoryQuery.filter(store.history.items, text: historySearch,
                                 favoritesOnly: favoritesOnly)
    }
    private var formats: [ColorOutputFormat] {
        let formats = favoriteFormatsOnly ? store.preferences.favoriteFormats : ColorOutputFormat.allCases
        return formats.filter { search.isEmpty || AppLocalization.string($0.title, language: store.preferences.language).localizedStandardContains(search) }
    }
    private func value(_ format: ColorOutputFormat) -> String {
        ColorFormatter.format(model.selectedColor, as: format, options: store.preferences.formatting,
                              sourceP3: model.selectedSourceP3)
    }

    private func syncInput() {
        colorInput = "#" + ColorFormatter.hex(model.selectedColor)
        if model.selectedColor.rgbaBytes[3] != 255 {
            colorInput += String(format: "%02x", model.selectedColor.rgbaBytes[3])
        }
        inputError = false
    }
    private func applyColorInput() {
        inputError = !model.setSelectedFromText(colorInput)
        if !inputError { syncInput() }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Colors & Formats").font(.title2.bold())
                Spacer()
                Button { model.showHarmonyWheel() } label: {
                    Label("Color Wheel", systemImage: "circle.hexagongrid")
                }
                Button { model.showColorStudio() } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .help("Color Studio")
                .accessibilityLabel(Text("Open Color Studio"))
                Button { model.copySelected() } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }.padding(16)
            Divider()
            HStack(spacing: 10) {
                Text("Color").font(.caption.weight(.semibold))
                TextField("#HEX, rgb(…), hsl(…), lab(…), oklab(…), color(display-p3 …)", text: $colorInput, onCommit: applyColorInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityLabel("Edit color value")
                Button("Apply") { applyColorInput() }
                    .disabled(colorInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button { model.saveSelectedToHistory() } label: {
                    Label("Save Color", systemImage: "plus.square")
                }.help("Save current color to history")
                if inputError { Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).help("Enter a valid HEX or supported CSS color") }
            }.padding(.horizontal, 16).padding(.vertical, 10)
            HStack(spacing: 8) {
                if let p3 = model.selectedSourceP3 {
                    Text("Display P3 values retained (captured or entered)")
                    if p3.isOutsideSRGBGamut {
                        Label("Outside sRGB gamut — sRGB formats clip", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("sRGB color — no captured P3 provenance")
                }
                if let profile = model.selectedDisplayProfileName {
                    Text("Screen profile: \(profile)")
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            .font(.caption2).foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 16).padding(.bottom, 4)
            HStack(alignment: .center, spacing: 12) {
                Button { favoritesOnly.toggle() } label: {
                    Image(systemName: favoritesOnly ? "star.fill" : "clock.arrow.circlepath")
                        .font(.title2).frame(width: 26)
                }
                .buttonStyle(.plain)
                .help(favoritesOnly ? "Show recent colors" : "Show favorites")
                .keyboardShortcut("f", modifiers: .command)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 5) {
                        if visibleColors.isEmpty {
                            Text(historySearch.isEmpty ? "No colors picked yet" : "No matching colors")
                                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
                        }
                        ForEach(visibleColors) { item in
                            ColorChip(color: item.color,
                                      selected: model.selectedColor.rgbaBytes == item.color.rgbaBytes &&
                                          model.selectedSourceP3 == item.sourceP3,
                                      favorite: item.isFavorite,
                                      displayProfileName: item.displayProfileName,
                                      sourceP3: item.sourceP3,
                                      onSelect: { model.selectFromHistory(item) },
                                      onFavorite: { store.toggleFavorite(item.id) },
                                      onDelete: { store.remove(item.id) })
                        }
                    }.padding(.vertical, 4)
                }.scrollIndicators(.hidden)
                Button {
                    model.toggleFavoriteForSelected()
                } label: { Image(systemName: "star") }
                    .help("Toggle favorite for current color")
                    .keyboardShortcut("f", modifiers: .control)
            }.padding(.horizontal, 16).frame(height: 70)
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                TextField("Search color history (HEX or RGB)", text: $historySearch)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search color history")
                Text(String(format: AppLocalization.string(visibleColors.count == 1 ? "%d color" : "%d colors",
                                             language: store.preferences.language), visibleColors.count))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                if !historySearch.isEmpty {
                    Button { historySearch = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Clear history search")
                }
            }.padding(.horizontal, 16).padding(.bottom, 8)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Type to filter formats", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                }
                RoundedRectangle(cornerRadius: 4).fill(model.selectedColor.swiftUIColor(sourceP3: model.selectedSourceP3))
                    .frame(width: 22, height: 22).overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.secondary.opacity(0.4)))
            }
            .padding(10)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 16)
            HStack {
                Text("Output Formats").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Toggle("Favorites Only", isOn: $favoriteFormatsOnly)
                    .toggleStyle(.checkbox).font(.caption)
            }.padding(.horizontal, 16).padding(.top, 10)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    if formats.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(favoriteFormatsOnly ? "No matching favorite formats" : "No matching formats")
                                .font(.headline)
                            Text("Try another search or show all output formats.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Show All Formats") { search = ""; favoriteFormatsOnly = false }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                    ForEach(formats) { format in
                        HStack(spacing: 6) {
                            FormatValueRow(format: format, value: value(format),
                                           selected: model.chosenFormat == format) {
                                model.copySelected(format: format)
                            }
                            Button {
                                store.preferences.toggleFavoriteFormat(format)
                            } label: {
                                Image(systemName: store.preferences.favoriteFormats.contains(format) ? "star.fill" : "star")
                            }
                            .buttonStyle(.borderless)
                            .help(store.preferences.favoriteFormats.contains(format) ? "Remove favorite format" : "Favorite this format")
                            .accessibilityLabel(Text("Toggle favorite for \(AppLocalization.string(format.title, language: store.preferences.language))"))
                        }
                    }
                }.padding(12)
            }
            Divider()
            HStack(spacing: 12) {
                ColorEditorButton(model: model, title: "Color Editor", systemImage: "circle.lefthalf.filled")
                Button("Copy Session (\(store.lastPickSession.count))") { model.copyLastSession() }
                    .disabled(store.lastPickSession.count == 0)
                    .help("Copy the last pick session, even after restarting PixNab")
                Menu("Export ASE") {
                    Button("Selected Color…") { model.exportAdobeSwatches(session: false) }
                    Button("Last Pick Session…") { model.exportAdobeSwatches(session: true) }
                        .disabled(store.lastPickSession.count == 0)
                    Divider()
                    Button("Selected Color (ACO)…") { model.exportAdobeSwatches(session: false, fileFormat: .aco) }
                    Button("Last Pick Session (ACO)…") { model.exportAdobeSwatches(session: true, fileFormat: .aco) }
                        .disabled(store.lastPickSession.count == 0)
                }
                .help("Export Adobe Swatch Exchange files for Photoshop and Illustrator")
                Button("Clear Recents") { confirmClear = true }
                    .disabled(store.history.items.isEmpty)
                Spacer()
                Text(model.message ?? "Select a format to copy")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }.padding(12)
        }
        .frame(minWidth: 520, minHeight: 400)
        .onAppear { syncInput() }
        .onChange(of: model.selectedColor) { _, _ in syncInput() }
        .confirmationDialog("Clear recent colors?", isPresented: $confirmClear) {
            Button("Clear Recents", role: .destructive) { store.clearRecents() }
        } message: {
            Text("Favorites will be preserved. Other colors cannot be restored.")
        }
        .preferredColorScheme(store.preferences.appearance.colorScheme)
        .environment(\.locale, AppLocalization.locale(for: store.preferences.language))
    }
}

extension AppearanceMode {
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
}
