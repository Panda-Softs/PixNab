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
    // Capture the first click when the cursor moves to another display.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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
        // Apply all coalesced scroll steps as one preference update and one render.
        onScroll?(steps, option)
    }
    override func magnify(with event: NSEvent) {
        // Trackpad pinch is a continuous relative scale gesture. Quantize it to
        // the same zoom steps used by keyboard and scroll wheel so all input
        // paths share the existing zoom limit and preference persistence.
        pinchAccumulator += event.magnification
        let steps = max(-4, min(4, Int(pinchAccumulator / 0.08)))
        if steps != 0 {
            // Preserve the total zoom delta while avoiding repeated render work.
            onScroll?(steps, false)
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

/// A small, click-through window carries the lens across the boundary between
/// displays. Unlike the full-screen input surfaces, it must not be constrained
/// to a particular NSScreen.
private final class PickerLensPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

@MainActor
final class MagnifierOverlay {
    // Each physical display has its own transparent input surface. The visual
    // lens is NOT a child of these surfaces: it lives in one small, independent
    // panel that can straddle two monitors like any ordinary Mac window.
    private struct DisplayPanel {
        let panel: PickerPanel
        let root: PickerCaptureView
    }
    private var panels: [NSNumber: DisplayPanel] = [:]
    private var activeDisplayID: NSNumber?
    private var lensPanel: PickerLensPanel?
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
        guard lensPanel == nil else { return }
        guard let screen = screenUnderPointer() ?? NSScreen.screens.first else { return }
        let diameter: CGFloat = 320
        let side = diameter + CGFloat(2 * MagnifierLensGeometry.borderInset)
        let lens = MagnifierSurface(frame: NSRect(x: 0, y: 0, width: side, height: side))
        lens.autoresizingMask = [.width, .height]
        let window = PickerLensPanel(contentRect: NSRect(x: 0, y: 0, width: side, height: side),
                                     styleMask: [.borderless], backing: .buffered,
                                     defer: false, screen: screen)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.isMovable = false
        window.ignoresMouseEvents = true
        window.contentView = lens
        self.lensPanel = window
        self.lens = lens
        installInputPanels()
        NSApp.activate(ignoringOtherApps: true)
        followPointer(NSEvent.mouseLocation, on: screen, diameter: diameter)
    }

    private func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(pointer) })
    }

    private func installInputPanels() {
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            // With a screen parameter, contentRect is LOCAL to that display.
            // Passing screen.frame here would add the origin a second time on
            // the monitor left of / above / below the primary one.
            let panel = PickerPanel(contentRect: NSRect(origin: .zero, size: screen.frame.size),
                                    styleMask: [.borderless], backing: .buffered,
                                    defer: false, screen: screen)
            panel.isReleasedWhenClosed = false
            // Explicitly establish global Cocoa positioning so view conversion
            // never depends on which monitor currently owns the key window.
            panel.setFrame(screen.frame, display: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.hidesOnDeactivate = false
            panel.isMovable = false
            panel.acceptsMouseMovedEvents = true
            panel.ignoresMouseEvents = hoverActive

            let root = PickerCaptureView(frame: NSRect(origin: .zero, size: screen.frame.size))
            root.onSelect = { [weak self] action in self?.onPick?(action) }
            root.onCancel = { [weak self] in self?.onCancel?() }
            root.onKey = { [weak self] event in self?.handle(event) }
            root.onScroll = { [weak self] amount, option in
                guard let self else { return }
                if option { self.onRadius?(amount * 2) }
                else { self.onZoom?(amount) }
            }
            root.onPrecision = { [weak self] enabled in
                guard let self, self.precisionActive != enabled else { return }
                self.precisionActive = enabled
                self.onPrecisionChanged?()
            }
            panel.contentView = root
            panels[id] = DisplayPanel(panel: panel, root: root)
            panel.orderFrontRegardless()
        }
        lensPanel?.orderFrontRegardless()
    }

    /// Called every picker timer cycle, independent of ScreenCaptureKit frames.
    /// The visible lens crosses a monitor seam CONTINUOUSLY, even while the
    /// stream is switching between the two displays.
    func followPointer(_ point: NSPoint, on screen: NSScreen, diameter: CGFloat) {
        guard lensPanel != nil else { return }
        if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            activateScreen(id)
        }
        moveLens(to: point, diameter: diameter)
    }

    private func activateScreen(_ id: NSNumber) {
        guard let target = panels[id] else { return }
        if activeDisplayID != id {
            let previous = activeDisplayID
            activeDisplayID = id
            if let previous {
                panels[previous]?.root.stopTracking()
                let modifierPrecision = NSEvent.modifierFlags.contains(.control)
                    || NSEvent.modifierFlags.contains(.shift)
                if precisionActive != modifierPrecision {
                    precisionActive = modifierPrecision
                    onPrecisionChanged?()
                }
            }
            if !hoverActive {
                target.panel.makeKeyAndOrderFront(nil)
                target.panel.makeFirstResponder(target.root)
            }
            lensPanel?.orderFrontRegardless()
        }
    }

    private func moveLens(to point: NSPoint, diameter: CGFloat) {
        guard let window = lensPanel, let lens else { return }
        let displays = NSScreen.screens.map { screen in
            LensViewport(x: Double(screen.frame.minX), y: Double(screen.frame.minY),
                         width: Double(screen.frame.width), height: Double(screen.frame.height))
        }
        guard let placement = MagnifierLensGeometry.floatingFrame(
            center: ScreenPoint(x: Double(point.x), y: Double(point.y)),
            diameter: Double(diameter), displays: displays) else { return }
        let next = NSRect(x: CGFloat(placement.x), y: CGFloat(placement.y),
                          width: CGFloat(placement.width), height: CGFloat(placement.height))
        if window.frame != next { window.setFrame(next, display: true) }
        lens.diameter = diameter
    }

    /// Update the Command indicator independently of capture frames and mouse motion.
    func setMultiPickIndicator(_ enabled: Bool) {
        guard multiPickActive != enabled else { return }
        multiPickActive = enabled
        lens?.multiPickActive = enabled
    }

    /// Hold fn to let scroll and click events pass to the underlying app.
    func setHover(_ enabled: Bool) {
        guard hoverActive != enabled else { return }
        hoverActive = enabled
        for surface in panels.values { surface.panel.ignoresMouseEvents = enabled }
        if !enabled, let id = activeDisplayID, let target = panels[id] {
            target.panel.makeKeyAndOrderFront(nil)
            target.panel.makeFirstResponder(target.root)
            lensPanel?.orderFrontRegardless()
        }
    }

    func update(_ sample: SampledPixel, location: NSPoint, on screen: NSScreen,
                format: ColorOutputFormat, value: String,
                showLabel: Bool, diameter: CGFloat, pickedCount: Int) {
        guard let lens else { return }
        followPointer(location, on: screen, diameter: diameter)
        lens.precisionActive = precisionActive
        lens.multiPickActive = multiPickActive
        lens.pickedCount = pickedCount
        lens.patch = sample.patch
        lens.color = sample.color
        lens.formatLabel = format.title
        lens.value = value
        lens.showsLabel = showLabel
    }

    /// Rebuild input surfaces when topology changes; retain the ONE visible
    /// lens window and current pick session.
    func refreshDisplayLayout() {
        guard lensPanel != nil else { return }
        removeInputPanels()
        precisionActive = false
        installInputPanels()
        if let screen = screenUnderPointer() ?? NSScreen.screens.first {
            followPointer(NSEvent.mouseLocation, on: screen, diameter: lens?.diameter ?? 320)
        }
    }

    private func removeInputPanels() {
        for surface in panels.values {
            surface.root.stopTracking()
            surface.panel.orderOut(nil)
            surface.panel.close()
        }
        panels.removeAll()
        activeDisplayID = nil
    }

    /// Never retain a previous monitor's preview while capture reconnects.
    func clearPreview() {
        guard let lens, lens.patch != nil else { return }
        lens.patch = nil
    }

    func snapshot() -> NSImage? {
        guard let lens,
              let bitmap = lens.bitmapImageRepForCachingDisplay(in: lens.bounds) else { return nil }
        lens.cacheDisplay(in: lens.bounds, to: bitmap)
        let image = NSImage(size: lens.bounds.size)
        image.addRepresentation(bitmap)
        return image
    }

    func close() {
        removeInputPanels()
        lensPanel?.orderOut(nil)
        lensPanel?.close()
        lensPanel = nil
        lens = nil
        precisionActive = false
        multiPickActive = false
        hoverActive = false
    }

    private func handle(_ event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let option = event.modifierFlags.contains(.option)
        let amount = shift ? 10 : 1
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
