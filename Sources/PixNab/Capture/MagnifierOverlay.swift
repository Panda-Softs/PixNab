import AppKit
import PixNabCore

/// Draw-only lens. Capture, clipboard actions and app state live in AppController.
final class MagnifierSurface: NSView {
    var patch: CGImage? { didSet { needsDisplay = true } }
    var color: SRGBColor = .init(red: 0, green: 0, blue: 0) { didSet { if oldValue != color { needsDisplay = true } } }
    var formatLabel = "CSS Hex" { didSet { if oldValue != formatLabel { needsDisplay = true } } }
    var value = "#000000" { didSet { if oldValue != value { needsDisplay = true } } }
    var showsLabel = true { didSet { if oldValue != showsLabel { needsDisplay = true } } }
    var precisionActive = false { didSet { if oldValue != precisionActive { needsDisplay = true } } }
    var multiPickActive = false { didSet { if oldValue != multiPickActive { needsDisplay = true } } }
    var pickedCount = 0 { didSet { if oldValue != pickedCount { needsDisplay = true } } }
    var diameter: CGFloat = 320 { didSet { if oldValue != diameter { needsDisplay = true } } }
    private var cachedGrid: (width: Int, diameter: CGFloat, path: NSBezierPath)?

    private func gridPath(width: Int, diameter: CGFloat) -> NSBezierPath {
        if let cachedGrid, cachedGrid.width == width, cachedGrid.diameter == diameter {
            return cachedGrid.path
        }
        let path = NSBezierPath()
        let cell = diameter / CGFloat(max(1, width))
        if width > 1 {
            for n in 1..<width {
                let offset = CGFloat(n) * cell
                path.move(to: NSPoint(x: offset, y: 0))
                path.line(to: NSPoint(x: offset, y: diameter))
                path.move(to: NSPoint(x: 0, y: offset))
                path.line(to: NSPoint(x: diameter, y: offset))
            }
        }
        cachedGrid = (width, diameter, path)
        return path
    }

    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        // The lens view contains *only* the circle. No extra vertical region is
        // reserved for labels: the lens can reach the bottom edge of a display.
        let disc = NSRect(x: (bounds.width - diameter) / 2,
                          y: (bounds.height - diameter) / 2,
                          width: diameter, height: diameter)
        let circle = NSBezierPath(ovalIn: disc)
        NSGraphicsContext.saveGraphicsState()
        circle.addClip()
        NSColor(white: 0.13, alpha: 0.97).setFill()
        disc.fill()
        if patch == nil {
            let loading: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.82)
            ]
            let text = "Waiting for screen…" as NSString
            let size = text.size(withAttributes: loading)
            text.draw(at: NSPoint(x: disc.midX - size.width / 2,
                                  y: disc.midY - size.height / 2), withAttributes: loading)
        }
        if let patch {
            NSGraphicsContext.current?.imageInterpolation = .none
            let image = NSImage(cgImage: patch, size: NSSize(width: patch.width, height: patch.height))
            image.draw(in: disc, from: .zero, operation: .copy, fraction: 1)
            let side = CGFloat(patch.width)
            let cell = diameter / max(1, side)
            if cell >= 7 {
                // The same grid is reused across frames until zoom/diameter changes.
                let grid = gridPath(width: patch.width, diameter: diameter)
                NSGraphicsContext.saveGraphicsState()
                // Translate the context, not the cached path: repeated transforms
                // would otherwise accumulate over successive frames.
                let transform = NSAffineTransform()
                transform.translateX(by: disc.minX, yBy: disc.minY)
                transform.concat()
                NSColor(white: 0, alpha: 0.16).setStroke()
                grid.lineWidth = 0.5
                grid.stroke()
                NSGraphicsContext.restoreGraphicsState()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        // Precision wins when multiple modifiers are held; otherwise Command
        // highlights the existing lens border without changing sampling.
        let highlighted = precisionActive || multiPickActive
        (precisionActive ? NSColor.systemYellow :
            multiPickActive ? NSColor.systemBlue : NSColor(white: 0.94, alpha: 0.95)).setStroke()
        circle.lineWidth = highlighted ? 2.5 : 1.4
        circle.stroke()

        let dimension = CGFloat(max(1, patch?.width ?? 41))
        let pixelWidth = diameter / dimension
        let activeCell = NSRect(x: disc.midX - pixelWidth / 2,
                                y: disc.midY - pixelWidth / 2,
                                width: pixelWidth, height: pixelWidth)
        NSColor.black.setStroke()
        NSBezierPath(rect: activeCell.insetBy(dx: -1, dy: -1)).stroke()
        NSColor.white.setStroke()
        NSBezierPath(rect: activeCell).stroke()

        if showsLabel, let label = MagnifierLensGeometry.labelFrame(diameter: Double(diameter)) {
            // Bottom-center, entirely inside the circular boundary and clear of
            // the central crosshair. This is an overlay, not a second panel.
            let rect = NSRect(x: CGFloat(label.x), y: CGFloat(label.y),
                              width: CGFloat(label.width), height: CGFloat(label.height))
            NSGraphicsContext.saveGraphicsState()
            circle.addClip()
            NSColor(white: 0.02, alpha: 0.22).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()

            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.95)
            shadow.shadowBlurRadius = 3
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byTruncatingMiddle
            let title: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: precisionActive ? NSColor.systemYellow : NSColor.white,
                .paragraphStyle: paragraph,
                .shadow: shadow
            ]
            let code: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraph,
                .shadow: shadow
            ]
            let titleText = (precisionActive ? "PRECISION · " : "") +
                            (pickedCount > 0 ? "\(pickedCount) SAVED · " : "") + formatLabel
            let inset: CGFloat = 6
            let textWidth = rect.width - 2 * inset
            NSAttributedString(string: titleText, attributes: title)
                .draw(with: NSRect(x: rect.minX + inset, y: rect.minY + 22,
                                   width: textWidth, height: 15),
                      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
            NSAttributedString(string: value, attributes: code)
                .draw(with: NSRect(x: rect.minX + inset, y: rect.minY + 4,
                                   width: textWidth, height: 17),
                      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}

/// A transparent input surface across the virtual desktop. A short click picks;
/// holding the primary button or Control temporarily enables pixel precision.
final class PickerCaptureView: NSView {
    var onSelect: ((PickAction) -> Void)?
    var onCancel: (() -> Void)?
    var onKey: ((NSEvent) -> Void)?
    var onScroll: ((Int, Bool) -> Void)?
    var onPrecision: ((Bool) -> Void)?
    private var holdTimer: Timer?
    private var holding = false
    private var longPressPrecision = false
    private var pinchAccumulator: CGFloat = 0
    private var scrollAccumulator = ScrollStepAccumulator()

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override func mouseDown(with event: NSEvent) {
        holding = true
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.38, repeats: false) { [weak self] _ in
            guard let self, self.holding else { return }
            self.longPressPrecision = true
            self.onPrecision?(true)
        }
    }
    override func mouseUp(with event: NSEvent) {
        guard holding else { return }
        holding = false
        holdTimer?.invalidate()
        holdTimer = nil
        longPressPrecision = false
        onPrecision?(event.modifierFlags.contains(.control) || event.modifierFlags.contains(.shift))
        onSelect?(PickAction.resolve(command: event.modifierFlags.contains(.command),
                                     option: event.modifierFlags.contains(.option)))
    }
    override func rightMouseDown(with event: NSEvent) { onCancel?() }
    override func keyDown(with event: NSEvent) { onKey?(event) }
    override func flagsChanged(with event: NSEvent) {
        onPrecision?(longPressPrecision || event.modifierFlags.contains(.control) || event.modifierFlags.contains(.shift))
    }
    override func scrollWheel(with event: NSEvent) {
        let steps = scrollAccumulator.consume(delta: Double(event.scrollingDeltaY),
                                              precise: event.hasPreciseScrollingDeltas)
        guard steps != 0 else { return }
        let option = event.modifierFlags.contains(.option)
        for _ in 0..<abs(steps) { onScroll?(steps > 0 ? 1 : -1, option) }
    }
    override func magnify(with event: NSEvent) {
        // Trackpad pinch is a continuous relative scale gesture. Quantize it to
        // the same zoom steps used by keyboard and scroll wheel so all input
        // paths share the existing zoom limit and preference persistence.
        pinchAccumulator += event.magnification
        let steps = max(-4, min(4, Int(pinchAccumulator / 0.08)))
        if steps != 0 {
            for _ in 0..<abs(steps) { onScroll?(steps > 0 ? 1 : -1, false) }
            pinchAccumulator -= CGFloat(steps) * 0.08
        }
        if event.phase == .ended || event.phase == .cancelled { pinchAccumulator = 0 }
    }
    func stopTracking() {
        pinchAccumulator = 0
        scrollAccumulator.reset()
        holdTimer?.invalidate()
        holdTimer = nil
        holding = false
        longPressPrecision = false
    }
}

final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class MagnifierOverlay {
    private var panel: PickerPanel?
    private var root: PickerCaptureView?
    private var lens: MagnifierSurface?
    private(set) var precisionActive = false
    private var multiPickActive = false
    private var hoverActive = false
    var onPick: ((PickAction) -> Void)?
    var onCancel: (() -> Void)?
    var onUndo: (() -> Void)?
    var onMove: ((Int, Int) -> Void)?
    var onZoom: ((Int) -> Void)?
    var onRadius: ((Int) -> Void)?
    var onNextFormat: ((Int) -> Void)?
    var onCopyImage: (() -> Void)?
    var onPrecisionChanged: (() -> Void)?

    func show() {
        guard panel == nil else { return }
        let fullRect = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        guard !fullRect.isNull else { return }
        let window = PickerPanel(contentRect: fullRect, styleMask: [.borderless],
                                 backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.isMovable = false
        window.acceptsMouseMovedEvents = true
        let root = PickerCaptureView(frame: NSRect(origin: .zero, size: fullRect.size))
        root.onSelect = { [weak self] action in self?.onPick?(action) }
        root.onCancel = { [weak self] in self?.onCancel?() }
        root.onKey = { [weak self] event in self?.handle(event) }
        root.onScroll = { [weak self] amount, option in
            guard let self else { return }
            if option { self.onRadius?(amount * 2) }
            else { self.onZoom?(amount) }
        }
        root.onPrecision = { [weak self] enabled in
            guard let self else { return }
            if self.precisionActive != enabled {
                self.precisionActive = enabled
                self.onPrecisionChanged?()
            }
        }
        let lens = MagnifierSurface(frame: NSRect(x: 0, y: 0, width: 323, height: 323))
        root.addSubview(lens)
        window.contentView = root
        self.panel = window
        self.root = root
        self.lens = lens
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(root)
    }

    /// Update the Command indicator independently of capture frames and mouse motion.
    /// This avoids a stale border when the pointer is stationary.
    func setMultiPickIndicator(_ enabled: Bool) {
        guard multiPickActive != enabled else { return }
        multiPickActive = enabled
        lens?.multiPickActive = enabled
    }

    /// Hold fn to let scrolling and pointer events reach the application below.
    /// Sampling continues through the already-running ScreenCaptureKit stream.
    func setHover(_ enabled: Bool) {
        guard let panel, hoverActive != enabled else { return }
        hoverActive = enabled
        panel.ignoresMouseEvents = enabled
        if !enabled {
            panel.makeKeyAndOrderFront(nil)
            if let root { panel.makeFirstResponder(root) }
        }
    }

    func update(_ sample: SampledPixel, location: NSPoint, format: ColorOutputFormat,
                value: String, showLabel: Bool, diameter: CGFloat, pickedCount: Int) {
        guard let panel, let lens else { return }
        lens.diameter = diameter
        lens.precisionActive = precisionActive
        lens.multiPickActive = multiPickActive
        lens.pickedCount = pickedCount
        let frame = panel.frame
        // Clamp to the *active display* rather than the virtual desktop's
        // bounding rectangle (which can contain gaps on multi-screen setups).
        let display = NSScreen.screens.first(where: { $0.frame.contains(location) })?.frame ?? frame
        guard let placement = MagnifierLensGeometry.frame(
            center: ScreenPoint(x: Double(location.x), y: Double(location.y)),
            diameter: Double(diameter),
            viewport: LensViewport(x: Double(display.minX), y: Double(display.minY),
                                   width: Double(display.width), height: Double(display.height)))
        else { return }
        lens.frame = NSRect(x: CGFloat(placement.x) - frame.minX,
                            y: CGFloat(placement.y) - frame.minY,
                            width: CGFloat(placement.width), height: CGFloat(placement.height))
        lens.patch = sample.patch
        lens.color = sample.color
        lens.formatLabel = format.title
        lens.value = value
        lens.showsLabel = showLabel
    }

    /// Re-fit the existing capture panel when monitors are connected, removed or
    /// rearranged, without creating a second responder or leaking windows.
    func refreshDisplayLayout() {
        guard let panel, let root else { return }
        let fullRect = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        guard !fullRect.isNull else { return }
        panel.setFrame(fullRect, display: false)
        root.frame = NSRect(origin: .zero, size: fullRect.size)
    }

    /// Never retain a previous monitor's preview while capture is reconnecting.
    func clearPreview() {
        guard let lens, lens.patch != nil else { return }
        lens.patch = nil
    }

    func snapshot() -> NSImage? {
        guard let lens, let bitmap = lens.bitmapImageRepForCachingDisplay(in: lens.bounds) else { return nil }
        lens.cacheDisplay(in: lens.bounds, to: bitmap)
        let image = NSImage(size: lens.bounds.size)
        image.addRepresentation(bitmap)
        return image
    }

    func close() {
        root?.stopTracking()
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        root = nil
        lens = nil
        precisionActive = false
        multiPickActive = false
        hoverActive = false
    }

    private func handle(_ event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let option = event.modifierFlags.contains(.option)
        let amount = shift ? 10 : 1
        // Undo is available without leaving the magnifier. Handle the virtual
        // key codes before character parsing so both keyboard layouts work.
        if (event.keyCode == 6 && event.modifierFlags.contains(.command)) ||
            event.keyCode == 51 || event.keyCode == 117 {
            onUndo?()
            return
        }
        switch event.keyCode {
        case 53: onCancel?()
        case 36, 76, 49:
            onPick?(PickAction.resolve(command: event.modifierFlags.contains(.command), option: option))
        case 123: onMove?(-amount, 0)
        case 124: onMove?(amount, 0)
        case 125: onMove?(0, amount)
        case 126: onMove?(0, -amount)
        case 48: onNextFormat?(1)
        default:
            let character = event.charactersIgnoringModifiers?.lowercased() ?? ""
            switch character {
            case "+", "=": option ? onRadius?(2) : onZoom?(1)
            case "-", "_": option ? onRadius?(-2) : onZoom?(-1)
            case "[": onNextFormat?(-1)
            case "]": onNextFormat?(1)
            case "p": onCopyImage?()
            default: NSSound.beep()
            }
        }
    }
}
