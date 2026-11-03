import AppKit
import SwiftUI
import PixNabCore

struct PreferencesView: View {
    @State private var confirmReset = false
    @ObservedObject var model: AppController
    @ObservedObject var store: LocalStore
    init(model: AppController) { self.model = model; store = model.store }

    private func binding<Value>(_ field: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(get: { store.preferences[keyPath: field] }, set: { store.preferences[keyPath: field] = $0 })
    }
    private func formatBinding<Value>(_ field: WritableKeyPath<FormattingOptions, Value>) -> Binding<Value> {
        Binding(get: { store.preferences.formatting[keyPath: field] },
                set: { store.preferences.formatting[keyPath: field] = $0 })
    }

    var body: some View {
        TabView {
            ScrollView { general.padding(22) }
                .tabItem { Label("General", systemImage: "switch.2") }
            ScrollView { appearance.padding(22) }
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            ScrollView { codeStyle.padding(22) }
                .tabItem { Label("Code Style", systemImage: "curlybraces") }
        }
        .frame(width: 660, height: 530)
        .preferredColorScheme(store.preferences.appearance.colorScheme)
        .environment(\.locale, AppLocalization.locale(for: store.preferences.language))
        .confirmationDialog("Reset interface and shortcuts?", isPresented: $confirmReset) {
            Button("Reset Settings", role: .destructive) { model.resetInterfacePreferences() }
        } message: {
            Text("Color history and your Launch at Login choice will be preserved.")
        }
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Keyboard Shortcuts")
            PreferenceRow(title: "Pick Color") {
                ShortcutRecorder(shortcut: store.preferences.pickShortcut,
                                 accessibilityLabel: "Record Pick Color shortcut",
                                 language: store.preferences.language,
                                 onChange: { shortcut in
                                     model.applyHotkeys(shortcut, formats: store.preferences.formatsShortcut)
                                 }, onBegin: { model.suspendHotkeysForRecording() },
                                 onEnd: { model.resumeHotkeysAfterRecording() })
                .frame(width: 190, height: 26)
            }
            PreferenceRow(title: "Colors & Formats") {
                ShortcutRecorder(shortcut: store.preferences.formatsShortcut,
                                 accessibilityLabel: "Record Colors and Formats shortcut",
                                 language: store.preferences.language,
                                 onChange: { shortcut in
                                     model.applyHotkeys(store.preferences.pickShortcut, formats: shortcut)
                                 }, onBegin: { model.suspendHotkeysForRecording() },
                                 onEnd: { model.resumeHotkeysAfterRecording() })
                .frame(width: 190, height: 26)
            }
            Text("Click a shortcut, then press a key combination with Command, Option or Control. Press Escape to cancel.")
                .font(.caption).foregroundStyle(.secondary)
            SectionHeading(title: "Clipboard")
            PreferenceRow(title: "Default Format") {
                Picker("Default Format", selection: Binding(
                    get: { store.preferences.defaultFormat },
                    set: { store.preferences.defaultFormat = $0; model.chosenFormat = $0 })) {
                    ForEach(ColorOutputFormat.allCases) { f in Text(LocalizedStringKey(f.title)).tag(f) }
                }.labelsHidden().frame(width: 240)
            }
            PreferenceRow(title: "After Picking") {
                Toggle("Choose from Colors & Formats", isOn: binding(\.chooseFormatAfterPick))
            }
            PreferenceRow(title: "Multi-Pick Separator") {
                Picker("Multi-Pick Separator", selection: binding(\.sessionSeparator)) {
                    ForEach(SessionSeparator.allCases) { item in Text(LocalizedStringKey(item.title)).tag(item) }
                }.labelsHidden().frame(width: 240)
            }
            Text("Command-click to keep collecting (blue lens border). Press Escape to cancel; Command-Z or Delete undoes the last pick.")
                .font(.caption).foregroundStyle(.secondary)
            SectionHeading(title: "Startup")
            PreferenceRow(title: "Launch at Login") {
                Toggle("Launch PixNab when I sign in", isOn: Binding(
                    get: { store.preferences.launchAtLogin },
                    set: { enabled in
                        do { try store.updateLaunchAtLogin(enabled) }
                        catch { model.showError("Unable to update login item: %@",
                                                detail: error.localizedDescription) }
                    }))
            }
            Button("Reset Interface and Shortcuts…") { confirmReset = true }
            Text("Custom global shortcuts use native macOS hotkey registration without Accessibility permission.")
                .font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Magnifier")
            PreferenceRow(title: "Magnification") {
                HStack {
                    Slider(value: Binding(get: { Double(store.preferences.zoom) },
                        set: { store.preferences.zoom = Int($0) }), in: 2...15, step: 1)
                    Text("\(store.preferences.zoom)×").monospacedDigit().frame(width: 32)
                }.frame(width: 300)
            }
            PreferenceRow(title: "Capture Performance") {
                Picker("Capture Performance", selection: binding(\.captureFrameRate)) {
                    ForEach(CaptureFrameRate.allCases) { mode in
                        Text(LocalizedStringKey(mode.title)).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 210)
                .help("15 FPS reduces screen-capture work. Changes apply to the next pick session.")
            }
            PreferenceRow(title: "Capture Area") {
                HStack {
                    Slider(value: Binding(get: { Double(store.preferences.captureRadius) },
                        set: { store.preferences.captureRadius = Int($0) }), in: 9...80, step: 1)
                    Text("\(max(220, min(490, 300 + (store.preferences.captureRadius - 22) * 3))) pt").monospacedDigit().frame(width: 65)
                }.frame(width: 330)
            }
            PreferenceRow(title: "Color Overlay") {
                Toggle("Display color format and value", isOn: binding(\.showColorLabel))
            }
            Text("Command-click or Command-Return to collect multiple colors without closing the magnifier. A normal click finishes and copies the complete session. Hold Command for the blue Multi-Pick indicator; hold Shift / Control for yellow precision; hold fn to scroll the underlying app. Scroll to zoom; Option + scroll changes lens size.")
                .font(.caption).foregroundStyle(.secondary)
            SectionHeading(title: "Color Accuracy")
            Text(LocalizedStringKey(ColorCaptureContract.profileExplanation))
                .font(.caption).foregroundStyle(.secondary)
            SectionHeading(title: "User Interface")
            PreferenceRow(title: "Appearance") {
                Picker("Appearance", selection: binding(\.appearance)) {
                    ForEach(AppearanceMode.allCases) { item in Text(LocalizedStringKey(item.rawValue)).tag(item) }
                }.labelsHidden().pickerStyle(.segmented).frame(width: 260)
            }
            PreferenceRow(title: "Language") {
                Picker("Language", selection: binding(\.language)) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.title)).tag(language)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
                .onChange(of: store.preferences.language) { _, _ in
                    model.refreshLocalizedWindows()
                }
            }
            Text("The magnifier is active only during color picking.")
                .font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var codeStyle: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Hexadecimal")
            PreferenceRow(title: "Hex") {
                Toggle("Uppercase", isOn: formatBinding(\.uppercaseHex))
            }
            PreferenceRow(title: "Generic Hex Prefix") {
                TextField("Optional prefix", text: formatBinding(\.hexPrefix))
                    .textFieldStyle(.roundedBorder).frame(width: 110)
            }
            PreferenceRow(title: "CSS Hex") {
                Toggle("Use shorthand when possible", isOn: formatBinding(\.cssShorthand))
            }
            SectionHeading(title: "Floating Point")
            PreferenceRow(title: "Precision") {
                Stepper(value: formatBinding(\.decimalPlaces), in: 0...8) {
                    Text(String(format: AppLocalization.string(
                        store.preferences.formatting.decimalPlaces == 1 ? "%d decimal place" : "%d decimal places",
                        language: store.preferences.language), store.preferences.formatting.decimalPlaces))
                }
            }
            PreferenceRow(title: "Formatting") {
                Toggle("Remove trailing zeros", isOn: formatBinding(\.trimTrailingZeros))
            }
            SectionHeading(title: "Separators")
            PreferenceRow(title: "Values") {
                Toggle("Comma-separated values", isOn: formatBinding(\.commaSeparated))
            }
            SectionHeading(title: "Favorite Formats")
            Text("Mark output formats with a star in Colors & Formats to pin them to your Favorites list.")
                .font(.caption).foregroundStyle(.secondary)
            Text(String(format: AppLocalization.string(store.preferences.favoriteFormats.count == 1 ? "%d format pinned" : "%d formats pinned", language: store.preferences.language), store.preferences.favoriteFormats.count))
                .font(.caption)
            SectionHeading(title: "Preview")
            Text(ColorFormatter.format(SRGBColor(red8: 94, green8: 94, blue8: 94),
                                       as: store.preferences.defaultFormat,
                                       options: store.preferences.formatting))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 9))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
