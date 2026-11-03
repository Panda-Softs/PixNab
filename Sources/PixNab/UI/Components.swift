import SwiftUI
import PixNabCore

struct ColorChip: View {
    @Environment(\.locale) private var locale
    let color: SRGBColor
    var selected = false
    var favorite = false
    /// Source display profile label attached to this history entry, if available.
    var displayProfileName: String? = nil
    var sourceP3: DisplayP3Color? = nil
    var onSelect: () -> Void
    var onFavorite: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSelect) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.swiftUIColor(sourceP3: sourceP3))
                    .frame(width: 46, height: 46)
                    .overlay(alignment: .topTrailing) {
                        if favorite { Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(.white)
                            .shadow(color: .black, radius: 2).padding(4) }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 5)
                        .stroke(selected ? Color.accentColor : Color.primary.opacity(0.14), lineWidth: selected ? 3 : 1))
            }
            .buttonStyle(.plain)
            .help("\(AppLocalization.string("Screen profile", locale: locale)): \(displayProfileName ?? AppLocalization.string("Unavailable", locale: locale)) · \(AppLocalization.string(sourceP3 != nil ? "P3 sample retained" : "sRGB output", locale: locale))")
            .accessibilityLabel("\(AppLocalization.string("Color", locale: locale)) #\(ColorFormatter.hex(color))")
            .accessibilityValue("\(AppLocalization.string(selected ? "Selected" : "Not selected", locale: locale))\(favorite ? ", " + AppLocalization.string("favorite", locale: locale) : "")")
            .accessibilityHint(Text("Selects this color. More actions are available in the context menu."))
            .contextMenu {
                if let onFavorite {
                    Button(favorite ? "Remove Favorite" : "Add Favorite", action: onFavorite)
                }
                if let onDelete {
                    Button("Remove from History", role: .destructive, action: onDelete)
                }
            }
        }
    }
}

struct SectionHeading: View {
    @Environment(\.locale) private var locale
    let title: String
    var body: some View { Text(AppLocalization.string(title, locale: locale).uppercased()).font(.caption.weight(.semibold))
        .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader) }
}

struct PreferenceRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(LocalizedStringKey(title))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 180, alignment: .trailing)
                .foregroundStyle(.secondary)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 5)
    }
}

struct FormatValueRow: View {
    @Environment(\.locale) private var locale
    let format: ColorOutputFormat
    let value: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(format.title)).font(.body.weight(.medium))
                Text(value).font(.system(.callout, design: .monospaced))
                    .foregroundStyle(selected ? Color.white.opacity(0.9) : Color.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            .foregroundStyle(selected ? Color.white : Color.primary)
        }.buttonStyle(.plain)
          .accessibilityLabel("\(AppLocalization.string(format.title, locale: locale)): \(value)")
          .accessibilityValue(Text(LocalizedStringKey(selected ? "Current output format" : "Available format")))
          .accessibilityHint(Text("Copies this format to the clipboard"))
    }
}
