import Foundation

/// Interprets picker input in one place so clicks and keyboard selection agree.
/// Command takes precedence over Option: a continuous pick must never open a
/// separate window above the active full-screen magnifier.
public enum PickAction: Equatable, Sendable {
    case finish
    case chooseFormat
    case continuePicking

    public static func resolve(command: Bool, option: Bool) -> Self {
        if command { return .continuePicking }
        if option { return .chooseFormat }
        return .finish
    }
}

/// An ordered series of colors selected during one activation of the picker.
/// Repeated colors are intentional selections, unlike deduplicated history.
/// Separator for exporting a multi-pick session. The original capture order is preserved.
public enum SessionSeparator: String, CaseIterable, Codable, Identifiable, Sendable {
    case newLine, blankLine, commaSpace

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .newLine: return "One per line"
        case .blankLine: return "Blank line between colors"
        case .commaSpace: return "Comma-separated"
        }
    }
    public var text: String {
        switch self {
        case .newLine: return "\n"
        case .blankLine: return "\n\n"
        case .commaSpace: return ", "
        }
    }
}

public struct PickSession: Codable, Sendable {
    public private(set) var colors: [SRGBColor] = []
    /// Kept in lockstep with colors; nil for legacy or manually entered colors.
    public private(set) var sourceP3: [DisplayP3Color?] = []
    public init() {}

    private enum CodingKeys: String, CodingKey { case colors, sourceP3 }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        colors = try container.decodeIfPresent([SRGBColor].self, forKey: .colors) ?? []
        let decoded = try container.decodeIfPresent([DisplayP3Color?].self, forKey: .sourceP3) ?? []
        // Older sessions contain colors only. Reject misaligned metadata rather
        // than attributing a wide-gamut value to the wrong picked color.
        sourceP3 = decoded.count == colors.count ? decoded : Array(repeating: nil, count: colors.count)
    }

    public mutating func append(_ color: SRGBColor, sourceP3: DisplayP3Color? = nil) {
        // Bound memory and clipboard size even when the magnifier stays open.
        if colors.count == 500 { colors.removeFirst(); self.sourceP3.removeFirst() }
        colors.append(color)
        self.sourceP3.append(sourceP3)
    }

    public var count: Int { colors.count }
    public var last: SRGBColor? { colors.last }

    /// Removes only this session's last selection. The persistent color history
    /// remains untouched because the same color may predate this session.
    @discardableResult
    public mutating func undoLast() -> SRGBColor? {
        guard !colors.isEmpty else { return nil }
        sourceP3.removeLast()
        return colors.popLast()
    }

    public var lastSourceP3: DisplayP3Color? { sourceP3.last ?? nil }

    public func formatted(as format: ColorOutputFormat, options: FormattingOptions = .init(),
                          separator: SessionSeparator = .newLine) -> String {
        colors.enumerated().map { index, color in
            ColorFormatter.format(color, as: format, options: options, sourceP3: sourceP3[index])
        }
            .joined(separator: separator.text)
    }
}
