import Foundation

public struct Hotkey: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32 // Carbon cmdKey / optionKey / shiftKey / controlKey
    public init(keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers }
}

/// Caps screen capture work only while the picker is active. The energy-saving
/// mode reduces frame delivery and Core Image sampling on slower Macs.
public enum CaptureFrameRate: Int, CaseIterable, Codable, Sendable, Identifiable {
    case energySaver = 15
    case smooth = 30
    public var id: Int { rawValue }
    public var title: String {
        switch self {
        case .energySaver: return "Energy Saver · 15 FPS"
        case .smooth: return "Smooth · 30 FPS"
        }
    }
}

public enum AppearanceMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    public var id: String { rawValue }
}

/// Language selected in Preferences. System follows macOS language priority.
/// Keep raw values stable to preserve preference documents across releases.
public enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case system, english, french
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .french: return "French"
        }
    }
    public func effectiveIdentifier(systemLanguages: [String] = Locale.preferredLanguages) -> String {
        switch self {
        case .english: return "en"
        case .french: return "fr"
        case .system:
            // If no supported language was selected in macOS, use English.
            for language in systemLanguages {
                let code = language.split(whereSeparator: { $0 == "-" || $0 == "_" })
                    .first.map(String.init)?.lowercased()
                if code == "fr" { return "fr" }
                if code == "en" { return "en" }
            }
            return "en"
        }
    }
}

/// All preference keys are optional when decoding. A new release cannot silently
/// reset a user's entire settings document just because it adds a new property.
public struct AppPreferences: Codable, Sendable {
    public var formatting = FormattingOptions()
    public var defaultFormat: ColorOutputFormat = .cssHex
    public var pickShortcut = Hotkey(keyCode: 8, modifiers: 0x0800 | 0x0100) // ⌘⌥C
    public var formatsShortcut = Hotkey(keyCode: 8, modifiers: 0x0200 | 0x0100) // ⇧⌘C
    public var zoom = 8
    public var captureFrameRate: CaptureFrameRate = .smooth
    public var captureRadius = 22
    public var showColorLabel = true
    public var chooseFormatAfterPick = false
    public var appearance: AppearanceMode = .system
    public var language: AppLanguage = .system
    public var launchAtLogin = false
    /// Applied only to multi-color session copying, not single-color output.
    public var sessionSeparator: SessionSeparator = .newLine
    /// Pin preferred code formats at the top of Colors & Formats.
    public var favoriteFormats: [ColorOutputFormat] = [.cssHex, .cssRGB, .cssHSL, .swiftUI]

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case formatting, defaultFormat, pickShortcut, formatsShortcut, zoom, captureRadius, captureFrameRate
        case showColorLabel, chooseFormatAfterPick, appearance, language, launchAtLogin, favoriteFormats, sessionSeparator
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        formatting = try values.decodeIfPresent(FormattingOptions.self, forKey: .formatting) ?? formatting
        defaultFormat = try values.decodeIfPresent(ColorOutputFormat.self, forKey: .defaultFormat) ?? defaultFormat
        pickShortcut = try values.decodeIfPresent(Hotkey.self, forKey: .pickShortcut) ?? pickShortcut
        formatsShortcut = try values.decodeIfPresent(Hotkey.self, forKey: .formatsShortcut) ?? formatsShortcut
        zoom = max(2, min(15, try values.decodeIfPresent(Int.self, forKey: .zoom) ?? zoom))
        captureFrameRate = try values.decodeIfPresent(CaptureFrameRate.self, forKey: .captureFrameRate) ?? captureFrameRate
        captureRadius = max(9, min(80, try values.decodeIfPresent(Int.self, forKey: .captureRadius) ?? captureRadius))
        showColorLabel = try values.decodeIfPresent(Bool.self, forKey: .showColorLabel) ?? showColorLabel
        chooseFormatAfterPick = try values.decodeIfPresent(Bool.self, forKey: .chooseFormatAfterPick) ?? chooseFormatAfterPick
        appearance = try values.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? appearance
        language = (try? values.decodeIfPresent(AppLanguage.self, forKey: .language)) ?? language
        launchAtLogin = try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? launchAtLogin
        sessionSeparator = try values.decodeIfPresent(SessionSeparator.self, forKey: .sessionSeparator) ?? sessionSeparator
        let saved = try values.decodeIfPresent([ColorOutputFormat].self, forKey: .favoriteFormats) ?? favoriteFormats
        favoriteFormats = saved.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }

    public mutating func toggleFavoriteFormat(_ format: ColorOutputFormat) {
        if let index = favoriteFormats.firstIndex(of: format) { favoriteFormats.remove(at: index) }
        else { favoriteFormats.append(format) }
    }
}

/// Validation before registering OS-wide shortcuts. A bare key or Shift-only
/// shortcut would steal ordinary typing in whichever app has focus.
public enum HotkeyPolicy {
    private static let command: UInt32 = 0x0100
    private static let option: UInt32 = 0x0800
    private static let control: UInt32 = 0x1000
    private static let supported: UInt32 = 0x1B00 // command, shift, option, control

    public static func isSafe(_ shortcut: Hotkey) -> Bool {
        // Modifier keys are not valid shortcuts on their own.
        let modifierKeyCodes: Set<UInt32> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        return shortcut.keyCode <= 127 && !modifierKeyCodes.contains(shortcut.keyCode) &&
        shortcut.modifiers & ~supported == 0 &&
        shortcut.modifiers & (command | option | control) != 0
    }

    public static func isValidPair(_ first: Hotkey, _ second: Hotkey) -> Bool {
        first != second && isSafe(first) && isSafe(second)
    }
}
