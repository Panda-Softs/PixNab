import SwiftUI
import PixNabCore

/// Reusable anchored color editor. Unlike NSColorPanel, SwiftUI attaches the
/// popover to the actual button and keeps it on the same active display.
struct ColorEditorButton: View {
    @ObservedObject var model: AppController
    let title: String
    let systemImage: String
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            Label(LocalizedStringKey(title), systemImage: systemImage)
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ColorEditorPopover(model: model, onAdvanced: {
                isPresented = false
                model.showColorEditor()
            })
        }
    }
}

/// Custom, accessible channel tracks. The active channel changes along a
/// meaningful color gradient; alpha uses a transparency checkerboard.
private enum ColorChannel: CaseIterable {
    case red, green, blue, alpha

    var title: String {
        switch self {
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        case .alpha: return "Alpha"
        }
    }

    var component: KeyPath<SRGBColor, Double> {
        switch self {
        case .red: return \.red
        case .green: return \.green
        case .blue: return \.blue
        case .alpha: return \.alpha
        }
    }

    func gradient(for color: SRGBColor) -> LinearGradient {
        let start: Color
        let end: Color
        switch self {
        case .red:
            start = Color(red: 0, green: color.green, blue: color.blue)
            end = Color(red: 1, green: color.green, blue: color.blue)
        case .green:
            start = Color(red: color.red, green: 0, blue: color.blue)
            end = Color(red: color.red, green: 1, blue: color.blue)
        case .blue:
            start = Color(red: color.red, green: color.green, blue: 0)
            end = Color(red: color.red, green: color.green, blue: 1)
        case .alpha:
            start = Color(red: color.red, green: color.green, blue: color.blue).opacity(0)
            end = Color(red: color.red, green: color.green, blue: color.blue)
        }
        return LinearGradient(colors: [start, end], startPoint: .leading, endPoint: .trailing)
    }
}

private struct ColorChannelRow: View {
    let channel: ColorChannel
    let color: SRGBColor
    let value: Binding<Double>

    private let thumbWidth: CGFloat = 16

    private func setValue(_ newValue: Double) {
        value.wrappedValue = min(255, max(0, newValue.rounded()))
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(LocalizedStringKey(channel.title))
                .font(.caption.weight(.semibold))
                .frame(width: 43, alignment: .leading)

            GeometryReader { geometry in
                let travel = max(1, geometry.size.width - thumbWidth)
                let fraction = min(1, max(0, value.wrappedValue / 255))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.14))
                        .frame(height: 11)
                        .overlay {
                            if channel == .alpha {
                                Canvas { context, size in
                                    let cell: CGFloat = 5
                                    for row in 0..<2 {
                                        for column in 0..<Int(ceil(size.width / cell)) {
                                            let rect = CGRect(x: CGFloat(column) * cell,
                                                              y: CGFloat(row) * cell,
                                                              width: cell, height: cell)
                                            context.fill(Path(rect), with: .color(
                                                (row + column).isMultiple(of: 2)
                                                ? .white.opacity(0.35) : .black.opacity(0.25)))
                                        }
                                    }
                                }
                                .clipShape(Capsule())
                            }
                        }
                        .overlay(Capsule().fill(channel.gradient(for: color)))
                        .overlay(Capsule().strokeBorder(.primary.opacity(0.12)))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(.regularMaterial)
                        .frame(width: thumbWidth, height: 24)
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.primary.opacity(0.22)))
                        .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                        .offset(x: travel * fraction)
                }
                .frame(height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    setValue(Double((drag.location.x - thumbWidth / 2) / travel) * 255)
                })
            }
            .frame(height: 28)
            .focusable()
            .focusEffectDisabled()
            .onMoveCommand { direction in
                switch direction {
                case .left: setValue(value.wrappedValue - 1)
                case .right: setValue(value.wrappedValue + 1)
                default: break
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(LocalizedStringKey(channel.title)))
            .accessibilityValue(Text("\(Int(value.wrappedValue.rounded())) / 255"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: setValue(value.wrappedValue + 1)
                case .decrement: setValue(value.wrappedValue - 1)
                @unknown default: break
                }
            }

            Text("\(Int(value.wrappedValue.rounded()))")
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
                .frame(width: 30, alignment: .trailing)
        }
    }
}

/// The native wheel uses the same HSL coordinates, eight radial color layers,
/// centered lightness-band handle, and marker hierarchy as the standalone ES6
/// reference. It shares the existing sRGB model with the rest of PixNab.
private struct HarmonyWheel: View {
    let base: SRGBColor
    let kind: ColorHarmonyKind
    let onPick: (SRGBColor) -> Void

    @State private var leftArc = false
    // HSL is not uniquely recoverable from sRGB when L=0/1 or S=0.
    // Preserve the wheel's hue/saturation while the outer ring visits black or
    // white, instead of accidentally turning the color into grayscale.
    @State private var rememberedHue: Double?
    @State private var rememberedSaturation: Double?
    @State private var dragOrigin: ColorWheelGeometry.InteractionZone?
    @State private var lastDragZone: ColorWheelGeometry.InteractionZone = .inactive
    private let diameter: CGFloat = 350
    private let ringBand: CGFloat = 12
    private let separator: CGFloat = 13

    private var palette: [SRGBColor] {
        ColorHarmonyPalette.colors(for: base, kind: kind)
    }

    private var currentHSL: (h: Double, s: Double, l: Double) {
        let raw = base.hsl
        let hue = raw.s < 0.000001 ? (rememberedHue ?? raw.h) : raw.h
        let saturation = raw.l < 0.000001 || raw.l > 0.999999
            ? (rememberedSaturation ?? raw.s) : raw.s
        return (hue, saturation, raw.l)
    }

    private func pick(hue: Double, saturation: Double, lightness: Double) {
        rememberedHue = hue
        rememberedSaturation = saturation
        onPick(SRGBColor(hue: hue, saturation: saturation,
                         lightness: lightness, alpha: base.alpha))
    }

    private var ringGradient: LinearGradient {
        let hsl = currentHSL
        return LinearGradient(stops: [
            .init(color: .black, location: 0),
            .init(color: SRGBColor(hue: hsl.h, saturation: hsl.s,
                                   lightness: 0.5).swiftUIColor, location: 0.5),
            .init(color: SRGBColor(hue: hsl.h, saturation: hsl.s,
                                   lightness: 0.95).swiftUIColor, location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }

    private func selectDisk(_ point: CGPoint, innerDiameter: CGFloat) {
        let hsl = ColorWheelGeometry.hueSaturation(
            at: WheelPoint(x: Double(point.x), y: Double(point.y)),
            diameter: Double(innerDiameter), fallbackHue: currentHSL.h)
        // Reference behavior: selecting hue/saturation resets HSL lightness to 50%.
        pick(hue: hsl.hue, saturation: hsl.saturation, lightness: 0.5)
    }

    /// One continuous drag owns the wheel. Lightness drags latch to the ring
    /// after mouse-down: the narrow visual band must not be a radial movement
    /// constraint. Disk drags may still cross onto the ring (and back) without
    /// another click, retaining the last control in the transparent gap.
    private func selectWheel(_ point: CGPoint, innerDiameter: CGFloat) {
        let position = WheelPoint(x: Double(point.x), y: Double(point.y))
        let currentZone = ColorWheelGeometry.interactionZone(
            at: position, diameter: Double(diameter),
            ringBand: Double(ringBand), separator: Double(separator))
        if dragOrigin == nil {
            dragOrigin = currentZone
            lastDragZone = currentZone
        }
        let zone = ColorWheelGeometry.dragZone(
            startedIn: dragOrigin ?? .inactive,
            previous: lastDragZone, current: currentZone)
        lastDragZone = zone
        switch zone {
        case .disk:
            let inset = (diameter - innerDiameter) / 2
            selectDisk(CGPoint(x: point.x - inset, y: point.y - inset), innerDiameter: innerDiameter)
        case .ring:
            // Only the angle matters once the drag began on the ring.
            selectRing(point, ringDiameter: diameter)
        case .inactive:
            break
        }
    }

    private func selectRing(_ point: CGPoint, ringDiameter: CGFloat) {
        let next = ColorWheelGeometry.lightness(
            at: WheelPoint(x: Double(point.x), y: Double(point.y)),
            diameter: Double(ringDiameter))
        leftArc = next.leftArc
        let current = currentHSL
        pick(hue: current.h, saturation: current.s, lightness: next.value)
    }

    var body: some View {
        let innerDiameter = diameter - 2 * (ringBand + separator)
        let current = currentHSL
        let handle = ColorWheelGeometry.ringPoint(
            lightness: current.l, leftArc: leftArc,
            diameter: Double(diameter), bandWidth: Double(ringBand))

        let ringFrame = diameter - ringBand

        ZStack {
            // Render only the colored band, not a filled circle. This keeps the
            // separator area transparent so the sheet background remains visible
            // between the outer lightness ring and the inner chromatic disk.
            Circle()
                .stroke(ringGradient, lineWidth: ringBand)
                .frame(width: ringFrame, height: ringFrame)

            // Keep separate focusable accessibility targets for keyboard
            // navigation. Pointer interaction is routed once by the wheel.
            Circle()
                .stroke(Color.black.opacity(0.001), lineWidth: ringBand + 8)
                .frame(width: ringFrame, height: ringFrame)
                .accessibilityLabel(Text("Lightness ring"))
                .accessibilityValue(Text("\(Int((current.l * 100).rounded())) percent"))
                .accessibilityHint(Text("Drag along the outer ring to change lightness"))
                .focusable()
                .focusEffectDisabled()
                .onMoveCommand { direction in
                    let delta: Double
                    switch direction {
                    case .up: delta = 0.001
                    case .down: delta = -0.001
                    default: return
                    }
                    pick(hue: current.h, saturation: current.s,
                         lightness: min(1, max(0, current.l + delta)))
                }

            ZStack {
                ColorWheelDisk()
                    .frame(width: innerDiameter, height: innerDiameter)
                    .clipShape(Circle())

                Circle().fill(Color.black.opacity(0.001))
                    .contentShape(Circle())
                    .accessibilityLabel(Text("Hue and saturation picker"))
                    .accessibilityHint(Text("Drag horizontally to change hue, and radially to change saturation"))
                    .focusable()
                    .focusEffectDisabled()
                    .onMoveCommand { direction in
                        var hue = current.h
                        var saturation = current.s
                        switch direction {
                        case .left: hue -= 0.5
                        case .right: hue += 0.5
                        case .up: saturation = min(1, saturation + 0.005)
                        case .down: saturation = max(0, saturation - 0.005)
                        default: return
                        }
                        pick(hue: hue, saturation: saturation, lightness: current.l)
                    }

                ForEach(palette.indices, id: \.self) { index in
                    let hue = ColorHarmonyPalette.hues(for: current.h, kind: kind)[index]
                    let point = ColorWheelGeometry.diskPoint(
                        hue: hue, saturation: current.s,
                        diameter: Double(innerDiameter))
                    Circle()
                        .strokeBorder(.white, lineWidth: index == 0 ? 5 : 2)
                        .frame(width: index == 0 ? 24 : 12,
                               height: index == 0 ? 24 : 12)
                        .shadow(color: index == 0 ? .black.opacity(0.2) : .clear,
                                radius: index == 0 ? 4 : 0, y: 2)
                        .position(x: CGFloat(point.x), y: CGFloat(point.y))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: innerDiameter, height: innerDiameter)

            Circle().fill(Color.white)
                .frame(width: 12, height: 12)
                .shadow(color: .black.opacity(0.16), radius: 2)
                .position(x: CGFloat(handle.x), y: CGFloat(handle.y))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(width: diameter, height: diameter)
        // Capture mouse-down and subsequent movement on one common surface.
        // A drag can cross the transparent gap without losing ownership.
        .contentShape(Circle())
        .highPriorityGesture(DragGesture(minimumDistance: 0)
            .onChanged { selectWheel($0.location, innerDiameter: innerDiameter) }
            .onEnded { _ in
                dragOrigin = nil
                lastDragZone = .inactive
            })
    }
}

/// Canvas reproduces the eight overlapping radial gradients from the supplied
/// CSS. The gradient stops interpolate each hue towards neutral 128 gray.
/// No embedded JavaScript, remote images, or web views are required.
private struct ColorWheelDisk: View {
    private let centers: [(Double, Double)] = [
        (0.5, 0), (0.853553390593, 0.146446609407),
        (1, 0.5), (0.853553390593, 0.853553390593),
        (0.5, 1), (0.146446609407, 0.853553390593),
        (0, 0.5), (0.146446609407, 0.146446609407)
    ]
    private let locations: [Double] = [0, 0.1, 0.2, 0.3, 0.4, 0.5]
    private let intensities: [Double] = [1, 0.9, 0.8, 0.6, 0.3, 0]
    private let opacities: [Double] = [1, 0.8, 0.6, 0.4, 0.2, 0]

    var body: some View {
        Canvas(opaque: false) { context, size in
            let fullRect = CGRect(origin: .zero, size: size)
            // CSS background-image layers paint from first (top) to last (back).
            for index in centers.indices.reversed() {
                let center = CGPoint(x: CGFloat(centers[index].0) * size.width,
                                     y: CGFloat(centers[index].1) * size.height)
                let farX = max(center.x, size.width - center.x)
                let farY = max(center.y, size.height - center.y)
                let radius = hypot(farX, farY)
                let rgb = SRGBColor(hue: Double(index * 45), saturation: 1, lightness: 0.5)
                let stops = locations.indices.map { stop -> Gradient.Stop in
                    let intensity = intensities[stop]
                    let mix = { (component: Double) -> Double in
                        0.5 + (component - 0.5) * intensity
                    }
                    return Gradient.Stop(
                        color: Color(red: mix(rgb.red), green: mix(rgb.green),
                                     blue: mix(rgb.blue)).opacity(opacities[stop]),
                        location: CGFloat(locations[stop]))
                }
                context.fill(Path(fullRect), with: .radialGradient(
                    Gradient(stops: stops), center: center,
                    startRadius: 0, endRadius: radius))
            }
        }
    }
}

/// The only harmony picker in PixNab. It lives in the dedicated color-wheel
/// sheet, not in the compact RGBA popover. Palette math remains in PixNabCore.
private struct HarmonyPicker: View {
    @ObservedObject var model: AppController
    @State private var harmonyKind: ColorHarmonyKind = .complementary

    private var palette: [SRGBColor] {
        ColorHarmonyPalette.colors(for: model.selectedColor, kind: harmonyKind)
    }

    private func label(for color: SRGBColor) -> String {
        ColorFormatter.format(color, as: color.alpha < 1 ? .cssHexAlpha : .cssHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Picker("Palette type", selection: $harmonyKind) {
                ForEach(ColorHarmonyKind.allCases) { option in
                    Text(LocalizedStringKey(option.title)).tag(option)
                }
            }
            .accessibilityLabel(Text("Palette type"))

            HarmonyWheel(base: model.selectedColor, kind: harmonyKind,
                         onPick: model.changeSelectedColor)
                .frame(maxWidth: .infinity)

            HStack(spacing: 5) {
                ForEach(palette.indices, id: \.self) { index in
                    let color = palette[index]
                    let code = label(for: color)
                    Button { model.changeSelectedColor(color) } label: {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(color.swiftUIColor)
                                .frame(height: 42)
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.primary.opacity(0.12)))
                            Text(code)
                                .font(.system(size: 11, design: .monospaced))
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(Text("Use as selected color"))
                    .accessibilityLabel(Text("Use color \(code)"))
                    .contextMenu {
                        Button("Use as selected color") { model.changeSelectedColor(color) }
                        Button("Copy Color") { model.copyHarmonyColor(color) }
                        Button("Save Color") { model.saveHarmonyColor(color) }
                    }
                }
            }

            HStack(spacing: 10) {
                Button { model.copyHarmonyPalette(palette) } label: {
                    Label("Copy Palette", systemImage: "doc.on.doc")
                }
                Menu {
                    Button("Save to Color History") { model.saveHarmonyPalette(palette) }
                    Button("Save to My Palettes") { model.saveHarmonyToLibrary(palette, kind: harmonyKind) }
                } label: {
                    Label("Save Palette", systemImage: "plus.square.on.square")
                }
                Menu {
                    Button("Adobe Swatch Exchange (ASE)…") {
                        model.exportAdobeSwatches(colors: palette, name: "Palette", fileFormat: .ase)
                    }
                    Button("Adobe Color Swatch (ACO)…") {
                        model.exportAdobeSwatches(colors: palette, name: "Palette", fileFormat: .aco)
                    }
                } label: {
                    Label("Export Palette", systemImage: "square.and.arrow.up")
                }
            }
            .controlSize(.small)
            Text("Click a swatch to select it; right-click to copy or save a color.")
                .font(.caption2).foregroundStyle(.secondary)
            Text("Harmonies are HSL suggestions in sRGB, not captured P3 measurements.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct ColorHarmonyEditor: View {
    @ObservedObject var model: AppController
    @ObservedObject var store: LocalStore

    init(model: AppController) {
        self.model = model
        self.store = model.store
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Color Wheel").font(.title2.bold())
                    Spacer()
                    Button { model.closeHarmonyWheel() } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Close"))
                    .help(Text("Close"))
                    .keyboardShortcut(.cancelAction)
                }
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(model.selectedColor.swiftUIColor(sourceP3: model.selectedSourceP3))
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected color").font(.caption).foregroundStyle(.secondary)
                        Text("#" + ColorFormatter.hex(model.selectedColor))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button { model.copySelected() } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                HarmonyPicker(model: model)
            }
            .padding(16)
        }
        .frame(width: 470, height: 690)
        .preferredColorScheme(store.preferences.appearance.colorScheme)
        .environment(\.locale, AppLocalization.locale(for: store.preferences.language))
    }
}

struct ColorEditorPopover: View {
    @ObservedObject var model: AppController
    let onAdvanced: () -> Void
    @State private var input = ""
    @State private var invalidInput = false
    private func channel(_ component: KeyPath<SRGBColor, Double>) -> Binding<Double> {
        Binding(
            get: { model.selectedColor[keyPath: component] * 255 },
            set: { newValue in
                let old = model.selectedColor
                let newChannel = max(0, min(255, newValue.rounded())) / 255
                let color = SRGBColor(
                    red: component == \.red ? newChannel : old.red,
                    green: component == \.green ? newChannel : old.green,
                    blue: component == \.blue ? newChannel : old.blue,
                    alpha: component == \.alpha ? newChannel : old.alpha
                )
                model.changeSelectedColor(color)
            }
        )
    }

    private func syncInput() {
        let color = model.selectedColor
        input = "#" + ColorFormatter.hex(color)
        if color.rgbaBytes[3] != 255 {
            input += String(format: "%02x", color.rgbaBytes[3])
        }
        invalidInput = false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(model.selectedColor.swiftUIColor(sourceP3: model.selectedSourceP3))
                        .frame(width: 52, height: 52)
                        .overlay(RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(.secondary.opacity(0.3)))
                        .accessibilityLabel("Selected color")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Edit Color").font(.headline)
                        Text("sRGB · 8-bit channels").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                ForEach(ColorChannel.allCases, id: \.self) { component in
                    ColorChannelRow(channel: component,
                                    color: model.selectedColor,
                                    value: channel(component.component))
                }
                HStack(spacing: 8) {
                    TextField("#RRGGBB or #RRGGBBAA", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit(applyInput)
                        .accessibilityLabel("Color code")
                    Button("Apply", action: applyInput)
                }
                if invalidInput {
                    Text("Enter a valid HEX, RGB, or HSL color.")
                        .font(.caption).foregroundStyle(.red)
                }
                Divider()
                HStack {
                    Button("macOS Color Panel…", action: onAdvanced)
                    Spacer()
                    Button { model.copySelected() } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
        }
        .padding(16)
        .frame(width: 348)
        .onAppear(perform: syncInput)
        .onChange(of: model.selectedColor) { _, _ in syncInput() }
    }

    private func applyInput() {
        invalidInput = !model.setSelectedFromText(input)
        if !invalidInput { syncInput() }
    }
}
