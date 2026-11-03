import AppKit
import SwiftUI
import Carbon
import ServiceManagement
import PixNabCore

extension SRGBColor {
    init?(nsColor: NSColor) {
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return nil }
        self.init(red: Double(rgb.redComponent), green: Double(rgb.greenComponent),
                  blue: Double(rgb.blueComponent), alpha: Double(rgb.alphaComponent))
    }
    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
    var swiftUIColor: Color { Color(nsColor: nsColor) }
    func nsColor(sourceP3: DisplayP3Color?) -> NSColor {
        guard let sourceP3 else { return nsColor }
        return NSColor(displayP3Red: sourceP3.red, green: sourceP3.green,
                       blue: sourceP3.blue, alpha: alpha)
    }
    func swiftUIColor(sourceP3: DisplayP3Color?) -> Color {
        Color(nsColor: nsColor(sourceP3: sourceP3))
    }
}


/// Resolve PixNab strings from its existing .lproj catalog without changing
/// the process-wide AppleLanguages setting. SwiftUI uses the matching locale
/// environment, while AppKit's NSMenu and NSWindow need explicit lookup.
enum AppLocalization {
    private static let frenchBundle: Bundle? = {
        guard let path = Bundle.main.path(forResource: "fr", ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }()

    static func locale(for language: AppLanguage) -> Locale {
        Locale(identifier: language.effectiveIdentifier())
    }

    static func string(_ key: String, language: AppLanguage) -> String {
        string(key, locale: locale(for: language))
    }

    static func string(_ key: String, locale: Locale) -> String {
        guard locale.identifier.lowercased().hasPrefix("fr"),
              let bundle = frenchBundle else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

@MainActor
final class LocalStore: ObservableObject {
    @Published var history: ColorHistory {
        didSet { persist(history, key: "history.v1") }
    }
    @Published var preferences: AppPreferences {
        didSet { schedulePreferencesWrite() }
    }
    @Published private(set) var paletteLibrary: PaletteLibrary {
        didSet { persist(paletteLibrary, key: "palettes.v1") }
    }
    @Published private(set) var lastPickSession: PickSession {
        didSet { persist(lastPickSession, key: "pickSession.v1") }
    }
    private let defaults: UserDefaults
    private var pendingPreferencesWrite: DispatchWorkItem?
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.history = Self.read(ColorHistory.self, key: "history.v1", from: defaults) ?? ColorHistory()
        self.paletteLibrary = Self.read(PaletteLibrary.self, key: "palettes.v1", from: defaults) ?? PaletteLibrary()
        self.preferences = Self.read(AppPreferences.self, key: "settings.v1", from: defaults) ?? AppPreferences()
        self.lastPickSession = Self.read(PickSession.self, key: "pickSession.v1", from: defaults) ?? PickSession()
        // The OS owns the login item state, which can be modified outside PixNab.
        self.preferences.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    private static func read<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    private func persist<T: Encodable>(_ object: T, key: String) {
        guard let data = try? JSONEncoder().encode(object) else { return }
        defaults.set(data, forKey: key)
    }
    /// A SwiftUI slider may emit dozens of intermediate values per second.
    /// Coalesce the disk writes without delaying UI updates; shutdown flushes.
    private func schedulePreferencesWrite() {
        pendingPreferencesWrite?.cancel()
        let write = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingPreferencesWrite = nil
            self.persist(self.preferences, key: "settings.v1")
        }
        pendingPreferencesWrite = write
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: write)
    }

    func flushPreferences() {
        pendingPreferencesWrite?.cancel()
        pendingPreferencesWrite = nil
        persist(preferences, key: "settings.v1")
    }

    func rememberSession(_ session: PickSession) { lastPickSession = session }
    func toggleFavorite(_ id: UUID) { history.toggleFavorite(id: id) }
    func add(_ color: SRGBColor, displayProfileName: String? = nil,
             sourceP3: DisplayP3Color? = nil) {
        history.add(color, displayProfileName: displayProfileName, sourceP3: sourceP3)
    }
    /// Apply a complete harmony palette with one published history update and
    /// one persistence write, preserving the visual ordering of its swatches.
    func addPalette(_ colors: [SRGBColor]) {
        guard !colors.isEmpty else { return }
        var updated = history
        updated.addPalette(colors)
        history = updated
    }
    func setFavorite(_ color: SRGBColor, favorite: Bool, sourceP3: DisplayP3Color? = nil) {
        history.setFavorite(color, favorite: favorite, sourceP3: sourceP3)
    }
    func clearRecents() { history.clearRecents() }
    func remove(_ id: UUID) { history.remove(id: id) }

    /// Named palettes are persisted independently of captured-color history.
    /// A single write publishes a complete, validated change to the library.
    @discardableResult
    func saveNamedPalette(name: String, category: PaletteCategory,
                          swatches: [PaletteSwatch]) -> UUID? {
        var library = paletteLibrary
        guard let id = library.add(name: name, category: category, swatches: swatches) else { return nil }
        paletteLibrary = library
        return id
    }

    @discardableResult
    func renamePalette(_ id: UUID, name: String) -> Bool {
        var library = paletteLibrary
        guard library.rename(id, to: name) else { return false }
        paletteLibrary = library
        return true
    }

    @discardableResult
    func removePalette(_ id: UUID) -> Bool {
        var library = paletteLibrary
        guard library.remove(id) else { return false }
        paletteLibrary = library
        return true
    }

    @discardableResult
    func duplicatePalette(_ id: UUID) -> UUID? {
        var library = paletteLibrary
        guard let duplicate = library.duplicate(id) else { return nil }
        paletteLibrary = library
        return duplicate
    }

    @discardableResult
    func movePaletteSwatch(_ id: UUID, from: Int, to: Int) -> Bool {
        var library = paletteLibrary
        guard library.moveSwatch(id, from: from, to: to) else { return false }
        paletteLibrary = library
        return true
    }

    @discardableResult
    func appendPaletteSwatch(_ id: UUID, swatch: PaletteSwatch) -> Bool {
        var library = paletteLibrary
        guard library.addSwatch(id, swatch: swatch) else { return false }
        paletteLibrary = library
        return true
    }

    @discardableResult
    func deletePaletteSwatch(_ id: UUID, index: Int) -> Bool {
        var library = paletteLibrary
        guard library.removeSwatch(id, at: index) else { return false }
        paletteLibrary = library
        return true
    }

    @discardableResult
    func setPaletteCategory(_ id: UUID, category: PaletteCategory) -> Bool {
        var library = paletteLibrary
        guard library.changeCategory(id, to: category) else { return false }
        paletteLibrary = library
        return true
    }

    /// Non-destructive merge of a user-supplied backup. Reject oversized or
    /// invalid libraries at the model boundary before publishing a new value.
    @discardableResult
    func importPaletteLibrary(_ imported: PaletteLibrary) -> Int? {
        var library = paletteLibrary
        guard let count = library.merge(imported) else { return nil }
        paletteLibrary = library
        return count
    }

    func updateLaunchAtLogin(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
        preferences.launchAtLogin = enabled
    }
}

/// Uses OS-managed Carbon hotkeys, not an accessibility event tap.
@MainActor
final class HotkeyManager {
    private var handler: EventHandlerRef?
    private var registrations: [EventHotKeyRef] = []
    var onPick: (() -> Void)?
    var onFormats: (() -> Void)?

    init() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size,
                nil, &hotkeyID)
            guard status == noErr else { return status }
            let owner = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            // Carbon dispatches hotkey events on the main application event loop.
            guard hotkeyID.signature == OSType(0x504E4142) else { return noErr }
            let actionID = hotkeyID.id
            Task { @MainActor in
                if actionID == 1 { owner.onPick?() }
                if actionID == 2 { owner.onFormats?() }
            }
            return noErr
        }
        let result = InstallEventHandler(GetApplicationEventTarget(), callback,
            1, &event, opaque, &handler)
        if result != noErr { NSLog("PixNab: failed to install hotkey handler (%d)", result) }
    }

    private var activeShortcuts: [Hotkey] = []
    private var suspended = false

    /// Temporarily release our system hotkeys so the shortcut recorder can
    /// receive the original keys. Otherwise Carbon swallows already bound keys.
    func suspend() {
        guard !suspended else { return }
        suspended = true
        releaseRegistrations()
    }

    @discardableResult
    func resume() -> Bool {
        guard suspended else { return true }
        suspended = false
        guard !activeShortcuts.isEmpty else { return true }
        if install(activeShortcuts) { return true }
        activeShortcuts = []
        return false
    }

    @discardableResult
    func register(_ preferences: AppPreferences) -> Bool {
        let requested = [preferences.pickShortcut, preferences.formatsShortcut]
        guard HotkeyPolicy.isValidPair(requested[0], requested[1]) else { return false }
        if requested == activeShortcuts { return true }
        if suspended {
            // Check actual OS registration (including other apps), then release
            // immediately so the recorder retains exclusive keyboard focus.
            guard install(requested) else { return false }
            releaseRegistrations()
            activeShortcuts = requested
            return true
        }
        let old = activeShortcuts
        releaseRegistrations()
        if install(requested) { activeShortcuts = requested; return true }
        activeShortcuts = install(old) ? old : []
        return false
    }

    private func install(_ shortcuts: [Hotkey]) -> Bool {
        var pending: [EventHotKeyRef] = []
        for (index, hotkey) in shortcuts.enumerated() {
            let id = EventHotKeyID(signature: OSType(0x504E4142), id: UInt32(index + 1))
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(hotkey.keyCode, hotkey.modifiers, id,
                                                GetApplicationEventTarget(), 0, &reference)
            guard status == noErr, let reference else {
                pending.forEach { UnregisterEventHotKey($0) }
                return false
            }
            pending.append(reference)
        }
        registrations = pending
        return true
    }
    private func releaseRegistrations() {
        registrations.forEach { UnregisterEventHotKey($0) }
        registrations.removeAll()
    }

    func stop() {
        releaseRegistrations()
        suspended = false
        activeShortcuts.removeAll()
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }
}
