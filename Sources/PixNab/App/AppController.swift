import AppKit
import SwiftUI
import ScreenCaptureKit
import CoreGraphics
import CoreVideo
import UniformTypeIdentifiers
import PixNabCore

@MainActor
final class AppController: NSObject, ObservableObject, NSMenuDelegate, NSWindowDelegate {
    let store = LocalStore()
    @Published var selectedColor = SRGBColor(red8: 94, green8: 94, blue8: 94)
    @Published private(set) var selectedSourceP3: DisplayP3Color?
    @Published private(set) var selectedDisplayProfileName: String?
    @Published var chosenFormat: ColorOutputFormat = .cssHex
    @Published var studioSection: ColorStudioSection = .discover
    @Published var studioPaletteID = "harbor"
    @Published var studioComparisonCandidate: PaletteSwatch?
    @Published var studioScaleCandidate: PaletteSwatch?
    @Published var message: String?
    @Published private(set) var picking = false

    private var statusItem: NSStatusItem?
    private let hotkeys = HotkeyManager()
    private let capture = ScreenCaptureEngine()
    private let overlay = MagnifierOverlay()
    private var formatWindow: NSWindow?
    private var harmonyWheelWindow: NSWindow?
    private var colorStudioWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var colorEditorOpened = false
    private var pickingTimer: Timer?
    private var activePickSession = PickSession()
    private var captureTask: Task<Void, Never>?
    private var frame: CVPixelBuffer?
    private var currentSample: SampledPixel?
    private var lastRenderedPoint: NSPoint?
    private var frameRevision: UInt64 = 0
    private var lastRenderKey: MagnifierRenderKey?
    private var keyOffsetX = 0
    private var keyOffsetY = 0
    private var currentScreenID: NSNumber?
    private var pendingDisplayID: NSNumber?
    private var pointerScreenID: NSNumber?
    private var captureRequest: UInt64 = 0
    private var captureRequiresRestart = false
    private var displayObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var isStopping = false

    override init() {
        super.init()
        chosenFormat = store.preferences.defaultFormat
        if let first = store.history.items.first {
            selectedColor = first.color
            selectedSourceP3 = first.sourceP3
            selectedDisplayProfileName = first.displayProfileName
        }
        hotkeys.onPick = { [weak self] in self?.pickColor() }
        hotkeys.onFormats = { [weak self] in self?.showFormats() }
        overlay.onPick = { [weak self] action in self?.confirmPick(action: action) }
        overlay.onCancel = { [weak self] in self?.cancelPick() }
        overlay.onUndo = { [weak self] in self?.undoLastPick() }
        overlay.onMove = { [weak self] dx, dy in self?.move(dx: dx, dy: dy) }
        overlay.onZoom = { [weak self] change in self?.changeZoom(change) }
        overlay.onRadius = { [weak self] change in self?.changeRadius(change) }
        overlay.onNextFormat = { [weak self] delta in self?.cycleFormat(delta) }
        overlay.onCopyImage = { [weak self] in self?.copyLensImage() }
        overlay.onPrecisionChanged = { [weak self] in self?.render() }
        capture.onFrame = { [weak self] buffer in
            guard let self, self.picking else { return }
            self.frame = buffer
            self.frameRevision &+= 1
            self.render()
        }
        capture.onError = { [weak self] error in
            guard let self, self.picking else { return }
            self.failCapture(error)
        }
    }

    func launch() {
        NSApp.setActivationPolicy(.accessory)
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.displayConfigurationChanged() }
            }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.displayConfigurationChanged() }
            }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: "PixNab")
        statusItem?.button?.toolTip = tr("PixNab — Pick a color")
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
        if !hotkeys.register(store.preferences) { message = tr("A global shortcut is already used by another application.") }
    }

    private func tr(_ key: String) -> String {
        AppLocalization.string(key, language: store.preferences.language)
    }

    private func trf(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: AppLocalization.locale(for: store.preferences.language),
               arguments: arguments)
    }

    /// Refresh native window titles when the user changes the language.
    /// The NSMenu is rebuilt with the same preference on its next opening.
    func refreshLocalizedWindows() {
        statusItem?.button?.toolTip = tr("PixNab — Pick a color")
        formatWindow?.title = tr("Colors & Formats — PixNab")
        harmonyWheelWindow?.title = tr("Color Wheel")
        colorStudioWindow?.title = tr("Color Studio — PixNab")
        settingsWindow?.title = tr("PixNab Preferences")
        aboutWindow?.title = tr("About PixNab")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        add("Pick Color", to: menu, action: #selector(pickAction), key: "")
        add("Colors & Formats…", to: menu, action: #selector(formatsAction), key: "")
        add("Color Wheel…", to: menu, action: #selector(colorWheelAction), key: "")
        add("Color Studio…", to: menu, action: #selector(colorStudioAction), key: "")
        let copyAs = NSMenuItem(title: tr("Copy Selected Color As"), action: nil, keyEquivalent: "")
        let copyMenu = NSMenu(title: tr("Copy Selected Color As"))
        let favoriteFormats = store.preferences.favoriteFormats
        for format in (favoriteFormats.isEmpty ? ColorOutputFormat.allCases : favoriteFormats) {
            let choice = NSMenuItem(title: tr(format.title), action: #selector(copyAsFormatAction(_:)), keyEquivalent: "")
            choice.target = self
            choice.representedObject = format.rawValue
            choice.state = chosenFormat == format ? .on : .off
            copyMenu.addItem(choice)
        }
        copyAs.submenu = copyMenu
        menu.addItem(copyAs)
        let adobe = NSMenuItem(title: tr("Export Adobe Swatches"), action: nil, keyEquivalent: "")
        let adobeMenu = NSMenu(title: tr("Export Adobe Swatches"))
        let selected = NSMenuItem(title: tr("Selected Color…"), action: #selector(exportSelectedASEAction), keyEquivalent: "")
        selected.target = self
        adobeMenu.addItem(selected)
        let session = NSMenuItem(title: tr("Last Pick Session…"), action: #selector(exportSessionASEAction), keyEquivalent: "")
        session.target = self
        session.isEnabled = store.lastPickSession.count > 0
        adobeMenu.addItem(session)
        adobeMenu.addItem(.separator())
        let selectedACO = NSMenuItem(title: tr("Selected Color (ACO)…"), action: #selector(exportSelectedACOAction), keyEquivalent: "")
        selectedACO.target = self
        adobeMenu.addItem(selectedACO)
        let sessionACO = NSMenuItem(title: tr("Last Pick Session (ACO)…"), action: #selector(exportSessionACOAction), keyEquivalent: "")
        sessionACO.target = self
        sessionACO.isEnabled = store.lastPickSession.count > 0
        adobeMenu.addItem(sessionACO)
        adobe.submenu = adobeMenu
        menu.addItem(adobe)
        let multiPickHint = NSMenuItem(title: tr("⌘-click to collect · ⌘Z to undo"), action: nil, keyEquivalent: "")
        multiPickHint.isEnabled = false
        menu.addItem(multiPickHint)
        if store.lastPickSession.count > 0 {
            let sessionItem = NSMenuItem(
                title: String(format: tr("Copy Last Pick Session (%d Colors)"), store.lastPickSession.count),
                action: #selector(copyLastSessionAction), keyEquivalent: "")
            sessionItem.target = self
            menu.addItem(sessionItem)
        }
        if message == tr("A global shortcut is already used by another application.") ||
           message == "A global shortcut is already used by another application." {
            let warning = NSMenuItem(title: tr("⚠ Global shortcut conflict — check Preferences"), action: nil, keyEquivalent: "")
            warning.isEnabled = false
            menu.addItem(warning)
        }
        menu.addItem(.separator())
        let colors = Array(store.history.items.prefix(8))
        let header = NSMenuItem(title: tr("Recently Picked Colors"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        if colors.isEmpty {
            let empty = NSMenuItem(title: tr("No colors yet"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for entry in colors {
            let code = ColorFormatter.format(entry.color, as: chosenFormat,
                                              options: store.preferences.formatting, sourceP3: entry.sourceP3)
            let item = NSMenuItem(title: code, action: #selector(historyAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry.id.uuidString
            item.image = swatchImage(entry.color.nsColor(sourceP3: entry.sourceP3))
            menu.addItem(item)
        }
        let favorites = NSMenuItem(title: tr("Favorite Colors"), action: nil, keyEquivalent: "")
        let favoritesMenu = NSMenu(title: tr("Favorite Colors"))
        if store.history.favorites.isEmpty {
            let item = NSMenuItem(title: tr("No favorites yet"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            favoritesMenu.addItem(item)
        } else {
            for entry in store.history.favorites.prefix(30) {
                let item = NSMenuItem(
                    title: ColorFormatter.format(entry.color, as: chosenFormat,
                                                 options: store.preferences.formatting, sourceP3: entry.sourceP3),
                    action: #selector(historyAction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = entry.id.uuidString
                item.image = swatchImage(entry.color.nsColor(sourceP3: entry.sourceP3))
                favoritesMenu.addItem(item)
            }
        }
        favorites.submenu = favoritesMenu
        menu.addItem(favorites)
        if !store.history.items.isEmpty {
            let clear = NSMenuItem(title: tr("Clear Recent Colors…"), action: #selector(clearRecentsAction), keyEquivalent: "")
            clear.target = self
            menu.addItem(clear)
        }
        menu.addItem(.separator())
        add("Preferences…", to: menu, action: #selector(settingsAction), key: ",")
        add("About PixNab…", to: menu, action: #selector(aboutAction), key: "")
        menu.addItem(.separator())
        add("Quit PixNab", to: menu, action: #selector(quitAction), key: "q")
    }

    private func add(_ title: String, to menu: NSMenu, action: Selector, key: String) {
        let item = NSMenuItem(title: tr(title), action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }
    private func swatchImage(_ color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 15, height: 15))
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 15, height: 15)).fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 15, height: 15)).stroke()
        image.unlockFocus()
        return image
    }
    @objc private func pickAction() { pickColor() }
    @objc private func formatsAction() { showFormats() }
    @objc private func colorWheelAction() { showHarmonyWheel() }
    @objc private func colorStudioAction() { showColorStudio() }
    @objc private func settingsAction() { showSettings() }
    @objc private func aboutAction() { showAbout() }
    @objc private func quitAction() {
        Task { @MainActor in
            await shutdownGracefully()
            NSApp.terminate(nil)
        }
    }
    @objc private func clearRecentsAction() {
        let confirm = NSAlert()
        confirm.messageText = tr("Clear recent colors?")
        confirm.informativeText = tr("Favorite colors will be kept. Other recent colors cannot be restored.")
        confirm.addButton(withTitle: tr("Clear Recents"))
        confirm.addButton(withTitle: tr("Cancel"))
        if confirm.runModal() == .alertFirstButtonReturn { store.clearRecents() }
    }
    @objc private func copyAsFormatAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let format = ColorOutputFormat(rawValue: raw) else { return }
        copySelected(format: format)
    }
    @objc private func copyLastSessionAction() { copyLastSession() }
    @objc private func exportSelectedASEAction() { exportAdobeSwatches(session: false) }
    @objc private func exportSessionASEAction() { exportAdobeSwatches(session: true) }
    @objc private func exportSelectedACOAction() { exportAdobeSwatches(session: false, fileFormat: .aco) }
    @objc private func exportSessionACOAction() { exportAdobeSwatches(session: true, fileFormat: .aco) }
    @objc private func historyAction(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let uuid = UUID(uuidString: value),
              let entry = store.history.items.first(where: { $0.id == uuid }) else { return }
        // Preserve the original captured P3 components and display ICC label.
        selectFromHistory(entry)
        copySelected()
    }

    func pickColor() {
        guard !picking, !isStopping else { return }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            showError("Screen Recording access is required. Enable PixNab in System Settings → Privacy & Security → Screen & System Audio Recording, then restart PixNab if requested.")
            return
        }
        picking = true
        capture.targetFPS = store.preferences.captureFrameRate.rawValue
        activePickSession = PickSession()
        captureRequiresRestart = false
        captureRequest &+= 1
        keyOffsetX = 0; keyOffsetY = 0
        currentScreenID = nil; pendingDisplayID = nil; pointerScreenID = nil
        frame = nil; currentSample = nil; lastRenderedPoint = nil; lastRenderKey = nil
        overlay.clearPreview()
        overlay.show()
        pickingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(capture.targetFPS), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    /// Screen topology changes can invalidate both the capture stream and
    /// the virtual desktop's overlay geometry. Restart on the current display
    /// instead of sampling a stale physical pixel buffer.
    private func displayConfigurationChanged() {
        guard picking else { return }
        overlay.refreshDisplayLayout()
        captureRequiresRestart = true
        captureTask?.cancel()
        captureRequest &+= 1
        currentScreenID = nil
        pendingDisplayID = nil
        pointerScreenID = nil
        keyOffsetX = 0; keyOffsetY = 0
        frame = nil; currentSample = nil; lastRenderedPoint = nil; lastRenderKey = nil
        overlay.clearPreview()
        tick()
    }

    private func tick() {
        guard picking else { return }
        // Device-independent fn flag (NSEvent.ModifierFlags.function). The overlay
        // intentionally passes events through while fn is held.
        let modifiers = NSEvent.modifierFlags
        overlay.setHover(modifiers.contains(.function))
        overlay.setMultiPickIndicator(modifiers.contains(.command))
        // Arrow-key offsets are physical pixels relative to the screen under
        // the real pointer. Carrying them to a screen with another scaling
        // factor would sample the wrong physical pixel.
        let pointer = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }),
           let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
           id != pointerScreenID {
            keyOffsetX = 0
            keyOffsetY = 0
            pointerScreenID = id
        }
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            // A disconnected monitor may leave the pointer outside every current
            // NSScreen for a short period. Never select from the old display.
            currentSample = nil
            lastRenderKey = nil
            overlay.clearPreview()
            return
        }
        if number != currentScreenID && number != pendingDisplayID {
            pendingDisplayID = number
            frame = nil; currentSample = nil; lastRenderKey = nil
            overlay.clearPreview()
            captureTask?.cancel()
            captureRequest &+= 1
            let request = captureRequest
            let forceRestart = captureRequiresRestart
            captureRequiresRestart = false
            captureTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.capture.start(on: screen, forceRestart: forceRestart)
                    guard self.picking, self.captureRequest == request, !Task.isCancelled else { return }
                    self.currentScreenID = number
                    self.pendingDisplayID = nil
                } catch {
                    if !Task.isCancelled && self.captureRequest == request { self.failCapture(error.localizedDescription) }
                }
            }
        }
        if frame != nil && NSEvent.mouseLocation != lastRenderedPoint { render() }
    }

    private func render() {
        let pointer = NSEvent.mouseLocation
        guard picking, let expectedID = currentScreenID,
              let buffer = frame,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }),
              (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == expectedID else { return }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard let cursorPixel = DisplayGeometry.pixel(at: pointer, on: screen,
                                                      pixelWidth: width, pixelHeight: height),
              let pixel = PixelNavigation.moved(cursorPixel, dx: keyOffsetX,
                                               dy: keyOffsetY, width: width, height: height),
              let center = PixelGeometry.center(
                  of: pixel, displayX: Double(screen.frame.minX),
                  displayY: Double(screen.frame.minY),
                  widthPoints: Double(screen.frame.width),
                  heightPoints: Double(screen.frame.height),
                  widthPixels: width, heightPixels: height) else { return }
        let renderKey = MagnifierRenderKey(frameRevision: frameRevision, pixel: pixel,
            radius: sampleRadius, zoom: store.preferences.zoom,
            precise: overlay.precisionActive, format: chosenFormat,
            showsLabel: store.preferences.showColorLabel, sessionCount: activePickSession.count)
        guard lastRenderKey != renderKey else { return }
        guard let sample = capture.sample(buffer, at: pixel, radius: sampleRadius) else {
            return
        }
        currentSample = sample
        lastRenderedPoint = pointer
        lastRenderKey = renderKey
        let value = ColorFormatter.format(sample.color, as: chosenFormat,
                                         options: store.preferences.formatting, sourceP3: sample.sourceP3)
        overlay.update(sample, location: NSPoint(x: center.x, y: center.y),
                       format: chosenFormat, value: value,
                       showLabel: store.preferences.showColorLabel, diameter: lensDiameter,
                       pickedCount: activePickSession.count)
    }

    private var lensDiameter: CGFloat {
        // The capture-area control changes lens size; zoom changes pixel scale.
        CGFloat(max(220, min(490, 300 + (store.preferences.captureRadius - 22) * 3)))
    }
    private var sampleRadius: Int {
        Int(ceil(lensDiameter / CGFloat(2 * (overlay.precisionActive ? 15 : max(2, store.preferences.zoom)))))
    }
    private func move(dx: Int, dy: Int) {
        keyOffsetX = max(-1_000_000, min(1_000_000, keyOffsetX + dx))
        keyOffsetY = max(-1_000_000, min(1_000_000, keyOffsetY + dy))
        render()
    }
    private func changeZoom(_ amount: Int) {
        let next = max(2, min(15, store.preferences.zoom + amount))
        guard next != store.preferences.zoom else { return }
        store.preferences.zoom = next
        render()
    }
    private func changeRadius(_ amount: Int) {
        let next = max(9, min(80, store.preferences.captureRadius + amount))
        guard next != store.preferences.captureRadius else { return }
        store.preferences.captureRadius = next
        render()
    }
    /// Shared by the magnifier's keys and the Colors & Formats toolbar.
    func cycleFormat(_ delta: Int) {
        let formats = ColorOutputFormat.allCases
        guard let index = formats.firstIndex(of: chosenFormat) else { return }
        chosenFormat = formats[(index + delta + formats.count) % formats.count]
        render()
    }
    private func copyLensImage() {
        guard let image = overlay.snapshot() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        endPick()
    }
    /// Command+click/Return stores a color without dismissing the magnifier.
    /// The final ordinary click closes the lens and copies all colors from this
    /// session, one formatted value per line. Option+click opens Formats for the
    /// last color, while the full session remains available in the menu.
    private func confirmPick(action: PickAction) {
        guard let sample = currentSample else { return }
        let color = sample.color
        activePickSession.append(color, sourceP3: sample.sourceP3)
        store.add(color, displayProfileName: sample.displayProfileName, sourceP3: sample.sourceP3)
        select(color, sourceP3: sample.sourceP3, displayProfileName: sample.displayProfileName)
        store.rememberSession(activePickSession)

        if action == .continuePicking {
            copyToClipboard(activePickSession.formatted(as: chosenFormat,
                                                        options: store.preferences.formatting,
                                                        separator: store.preferences.sessionSeparator))
            render()
            return
        }

        let shouldChooseFormat = action == .chooseFormat || store.preferences.chooseFormatAfterPick
        endPick()
        if shouldChooseFormat {
            showFormats()
        } else {
            copyToClipboard(formattedLastSession())
        }
    }
    private func formattedLastSession() -> String {
        store.lastPickSession.formatted(as: chosenFormat, options: store.preferences.formatting,
                                        separator: store.preferences.sessionSeparator)
    }

    /// Command-Z / Delete undo only the current multi-pick session. Existing
    /// history entries (including favorites) are intentionally never deleted.
    private func undoLastPick() {
        guard picking, activePickSession.undoLast() != nil else { return }
        store.rememberSession(activePickSession)
        if let previous = activePickSession.last { select(previous, sourceP3: activePickSession.lastSourceP3) }
        if activePickSession.count > 0 { copyToClipboard(formattedLastSession()) }
        else { message = tr("Selection removed · no colors in this session") }
        render()
    }

    func copyLastSession() {
        guard store.lastPickSession.count > 0 else { return }
        copyToClipboard(formattedLastSession())
    }

    /// ASE and ACO share a single save workflow and the same sRGB source.
    enum AdobeFileFormat { case ase, aco
        var extensionName: String { self == .ase ? "ase" : "aco" }
        var name: String { self == .ase ? "Adobe Swatch Exchange" : "Adobe Color Swatch" }
    }

    func exportAdobeSwatches(session: Bool, fileFormat: AdobeFileFormat = .ase) {
        let colors = session ? store.lastPickSession.colors : [selectedColor]
        exportAdobeSwatches(colors: colors, name: session ? "Session" : "Color", fileFormat: fileFormat)
    }

    /// Export a generated palette through the exact same ASE/ACO encoder and
    /// save dialog used for selected colors and real multi-pick sessions.
    func exportAdobeSwatches(colors: [SRGBColor], name: String, fileFormat: AdobeFileFormat = .ase) {
        guard !colors.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = trf("Export %@", fileFormat.name)
        panel.prompt = tr("Export")
        panel.nameFieldStringValue = "PixNab \(name).\(fileFormat.extensionName)"
        if let fileType = UTType(filenameExtension: fileFormat.extensionName, conformingTo: .data) {
            panel.allowedContentTypes = [fileType]
        }
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data: Data
            switch fileFormat {
            case .ase:
                let swatches = colors.enumerated().map { index, color in
                    AdobeSwatch(name: "PixNab \(index + 1) #\(ColorFormatter.hex(color))", color: color)
                }
                data = AdobeSwatchExchange.encode(swatches)
            case .aco:
                data = try AdobeColorSwatch.encode(colors)
            }
            try data.write(to: url, options: .atomic)
            message = trf(colors.count == 1 ? "Exported %d %@ swatch" : "Exported %d %@ swatches", colors.count, fileFormat.name)
        } catch { showError(trf("Unable to export swatches: %@", error.localizedDescription)) }
    }

    func cancelPick() { endPick() }
    private func endPick(stopCapture: Bool = true) {
        picking = false
        pickingTimer?.invalidate(); pickingTimer = nil
        captureRequest &+= 1
        let endingRequest = captureRequest
        captureTask?.cancel(); captureTask = nil
        overlay.close()
        frame = nil; currentSample = nil; lastRenderedPoint = nil; lastRenderKey = nil
        overlay.clearPreview()
        currentScreenID = nil; pendingDisplayID = nil; pointerScreenID = nil
        // A queued stop from an older session must not terminate a newly started pick.
        if stopCapture {
            Task { [weak self] in
                guard let self, self.captureRequest == endingRequest, !self.picking else { return }
                await self.capture.stop()
            }
        }
    }
    private func failCapture(_ description: String) {
        guard picking else { return }
        endPick()
        showError(trf("Screen capture failed: %@", description))
    }

    func showColorEditor() {
        colorEditorOpened = true
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.color = selectedColor.nsColor
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        // Keep the advanced macOS panel near Colors & Formats, not in a remote corner.
        // Native NSColorPanel is a floating window; the inline editor is the actual popover.
        if let window = formatWindow, let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            let preferredX = window.frame.maxX + 12
            let leftX = window.frame.minX - size.width - 12
            let x = preferredX + size.width <= visible.maxX ? preferredX :
                (leftX >= visible.minX ? leftX : window.frame.maxX - size.width)
            let y = window.frame.maxY - size.height
            panel.setFrameOrigin(NSPoint(x: max(visible.minX, min(x, visible.maxX - size.width)),
                                         y: max(visible.minY, min(y, visible.maxY - size.height))))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        guard let updated = SRGBColor(nsColor: sender.color) else { return }
        // Editing in the native panel produces a new sRGB value: previous P3
        // attribution must not survive it, even if fallback RGB bytes match.
        guard updated != selectedColor || selectedSourceP3 != nil else { return }
        select(updated)
    }

    func select(_ color: SRGBColor, sourceP3: DisplayP3Color? = nil,
                displayProfileName: String? = nil) {
        selectedColor = color
        selectedSourceP3 = sourceP3
        selectedDisplayProfileName = displayProfileName
        // Keep the shared native editor synchronized without event recursion.
        if colorEditorOpened, NSColorPanel.shared.isVisible,
           let panelColor = SRGBColor(nsColor: NSColorPanel.shared.color), panelColor != color {
            NSColorPanel.shared.color = color.nsColor
        }
    }
    func selectFromHistory(_ entry: PickedColor) {
        select(entry.color, sourceP3: entry.sourceP3, displayProfileName: entry.displayProfileName)
    }
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        message = text.contains("\n") ? tr("Copied multiple colors") : trf("Copied %@", text)
    }
    func copySelected(format: ColorOutputFormat? = nil) {
        let format = format ?? chosenFormat
        let text = ColorFormatter.format(selectedColor, as: format, options: store.preferences.formatting,
                                         sourceP3: selectedSourceP3)
        copyToClipboard(text)
        chosenFormat = format
        store.preferences.defaultFormat = format
    }
    func toggleFavoriteForSelected() {
        store.setFavorite(selectedColor, favorite: !store.history.isFavorite(selectedColor,
                             sourceP3: selectedSourceP3), sourceP3: selectedSourceP3)
    }
    func saveSelectedToHistory() {
        store.add(selectedColor, displayProfileName: selectedDisplayProfileName, sourceP3: selectedSourceP3)
    }
    func setSelectedFromText(_ text: String) -> Bool {
        guard let parsed = ColorParser.parseDetailed(text) else { return false }
        select(parsed.color, sourceP3: parsed.sourceP3)
        return true
    }
    func changeSelectedColor(_ newColor: SRGBColor) { select(newColor) }

    /// Harmony suggestions are sRGB values, never attributed to a P3 capture.
    /// Copying a swatch does not change the active color or output format.
    func copyHarmonyColor(_ color: SRGBColor) {
        copyToClipboard(ColorFormatter.format(color, as: color.alpha < 1 ? .cssHexAlpha : .cssHex))
    }

    func saveHarmonyColor(_ color: SRGBColor) {
        store.add(color)
        message = tr("Saved harmony color")
    }

    /// Reuse the existing pick-session formatter and configured separator,
    /// without replacing the last actual screen-pick session.
    func copyHarmonyPalette(_ colors: [SRGBColor]) {
        guard !colors.isEmpty else { return }
        var paletteSession = PickSession()
        for color in colors { paletteSession.append(color) }
        copyToClipboard(paletteSession.formatted(
            as: chosenFormat, options: store.preferences.formatting,
            separator: store.preferences.sessionSeparator))
    }

    func saveHarmonyPalette(_ colors: [SRGBColor]) {
        guard !colors.isEmpty else { return }
        store.addPalette(colors)
        message = trf("Saved %d harmony colors", colors.count)
    }

    /// Accessor for controlled swatch/scale copy. No hidden format preference changes.
    func copyDesignText(_ text: String) { copyToClipboard(text) }

    /// Export CSS/JSON/SwiftUI tokens using a native atomic-save workflow.
    func exportDesignText(_ text: String, suggestedName: String, ext: String) {
        let panel = NSSavePanel()
        panel.title = tr("Export Design Tokens")
        panel.prompt = tr("Export")
        panel.nameFieldStringValue = "\(suggestedName).\(ext)"
        panel.canCreateDirectories = true
        if let fileType = UTType(filenameExtension: ext, conformingTo: .text) {
            panel.allowedContentTypes = [fileType]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            message = tr("Design tokens exported")
        } catch { showError(trf("Unable to export swatches: %@", error.localizedDescription)) }
    }

    /// User-controlled portable backup, separate from settings and history.
    /// Import merges atomically and cannot replace an existing palette by UUID.
    func exportPaletteLibraryBackup() {
        let panel = NSSavePanel()
        panel.title = tr("Export Palette Library")
        panel.nameFieldStringValue = "PixNab-palettes.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(store.paletteLibrary).write(to: url, options: .atomic)
        } catch { showError(trf("Unable to export swatches: %@", error.localizedDescription)) }
    }

    func importPaletteLibraryBackup() {
        let panel = NSOpenPanel()
        panel.title = tr("Import Palette Library")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0 && size <= 8_000_000 else {
                showError("Palette backup is empty or exceeds 8 MB.")
                return
            }
            let data = try Data(contentsOf: url)
            guard data.count <= 8_000_000 else {
                showError("Palette backup is empty or exceeds 8 MB.")
                return
            }
            let imported = try JSONDecoder().decode(PaletteLibrary.self, from: data)
            guard let count = store.importPaletteLibrary(imported) else {
                showError("Palette backup is invalid or the library limit would be exceeded.")
                return
            }
            message = trf("Imported %d palettes", count)
        } catch { showError(trf("Unable to import palette library: %@", error.localizedDescription)) }
    }

    /// Save generated harmony colors as a real named library entry, not as
    /// unrelated history colors. Generated colors carry no P3 provenance.
    func saveHarmonyToLibrary(_ colors: [SRGBColor], kind: ColorHarmonyKind) {
        let name = "\(kind.title) #\(ColorFormatter.hex(selectedColor))"
        let swatches = colors.enumerated().map {
            PaletteSwatch(name: $0.offset == 0 ? "Base" : "Harmony \($0.offset)", color: $0.element)
        }
        if store.saveNamedPalette(name: name, category: .generated, swatches: swatches) != nil {
            showColorStudio(.library)
        } else {
            showError("Unable to save palette. Check its name and size.")
        }
    }

    /// The Studio is a standalone native window; opening it never shows the
    /// formats browser or wheel as a side effect.
    func showColorStudio(_ section: ColorStudioSection = .discover) {
        studioSection = section
        if colorStudioWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 740),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.title = tr("Color Studio — PixNab")
            window.minSize = NSSize(width: 760, height: 570)
            window.contentView = NSHostingView(rootView: ColorStudioView(model: self))
            window.center()
            window.isReleasedWhenClosed = false
            colorStudioWindow = window
        }
        bringFront(colorStudioWindow)
    }

    /// The wheel is an independent window. Opening it must not create or
    /// activate the Colors & Formats window, whether invoked from the status
    /// menu or from an already-open format browser.
    func showHarmonyWheel() {
        if harmonyWheelWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 690),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.title = tr("Color Wheel")
            window.titleVisibility = .hidden // The wheel has its own visible heading.
            window.contentView = NSHostingView(rootView: ColorHarmonyEditor(model: self))
            window.center()
            window.isReleasedWhenClosed = false
            harmonyWheelWindow = window
        }
        bringFront(harmonyWheelWindow)
    }

    func closeHarmonyWheel() {
        harmonyWheelWindow?.close()
    }

    func showFormats() {
        if formatWindow == nil {
            let view = ColorsFormatsView(model: self)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 530),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.title = tr("Colors & Formats — PixNab")
            window.minSize = NSSize(width: 520, height: 400)
            window.contentView = NSHostingView(rootView: view)
            window.center()
            window.isReleasedWhenClosed = false
            formatWindow = window
        }
        bringFront(formatWindow)
    }
    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 530),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = tr("PixNab Preferences")
            window.contentView = NSHostingView(rootView: PreferencesView(model: self))
            window.center(); window.isReleasedWhenClosed = false
            window.delegate = self
            settingsWindow = window
        }
        bringFront(settingsWindow)
    }
    func showAbout() {
        if aboutWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 185),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = tr("About PixNab")
            window.contentView = NSHostingView(rootView: VStack(spacing: 12) {
                Image(systemName: "eyedropper").font(.largeTitle)
                Text("PixNab").font(.title.bold())
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Development") · macOS").font(.caption)
                Text("Color your world.")
                    .font(.caption2).multilineTextAlignment(.center)
            }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity))
            window.center(); window.isReleasedWhenClosed = false
            aboutWindow = window
        }
        bringFront(aboutWindow)
    }
    private func bringFront(_ window: NSWindow?) {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        // Closing Preferences must never leave global shortcuts suspended.
        if let window = notification.object as? NSWindow, window === settingsWindow {
            if !hotkeys.resume() {
                message = tr("Unable to restore global shortcuts. Reopen Preferences and choose another combination.")
            }
        }
    }
    func suspendHotkeysForRecording() { hotkeys.suspend() }
    func resumeHotkeysAfterRecording() {
        if !hotkeys.resume() {
            showError("Unable to restore global shortcuts. Another application may be using them. Choose new shortcuts in Preferences.")
        }
    }
    func applyHotkeys(_ pick: Hotkey, formats: Hotkey) -> Bool {
        var candidate = store.preferences
        candidate.pickShortcut = pick; candidate.formatsShortcut = formats
        guard hotkeys.register(candidate) else { showError("Shortcut conflict: choose different combinations."); return false }
        store.preferences = candidate
        if message == tr("A global shortcut is already used by another application.") ||
           message == "A global shortcut is already used by another application." { message = nil }
        return true
    }
    func resetInterfacePreferences() {
        var defaults = AppPreferences()
        // Login-item registration is OS-level state; do not alter it as a side effect
        // of resetting UI/shortcut preferences.
        defaults.launchAtLogin = store.preferences.launchAtLogin
        guard hotkeys.register(defaults) else {
            showError("Cannot restore default shortcuts because another application is using them.")
            return
        }
        store.preferences = defaults
        chosenFormat = defaults.defaultFormat
        refreshLocalizedWindows()
    }
    func showError(_ messageKey: String, detail: String) {
        showError(trf(messageKey, detail))
    }

    func showError(_ text: String) {
        message = tr(text)
        let alert = NSAlert()
        alert.messageText = "PixNab"
        alert.informativeText = tr(text)
        alert.alertStyle = .warning
        alert.addButton(withTitle: tr("OK"))
        alert.runModal()
    }
    func shutdown() {
        store.flushPreferences()
        if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) }
        displayObserver = nil
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
        endPick()
        hotkeys.stop()
    }

    private func shutdownGracefully() async {
        guard !isStopping else { return }
        isStopping = true
        store.flushPreferences()
        if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) }
        displayObserver = nil
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
        // endPick() invalidates the session and releases the overlay immediately.
        // Awaiting the native capture stop before terminating avoids leaving an
        // in-flight ScreenCaptureKit operation at process exit.
        endPick(stopCapture: false)
        await capture.stop()
        hotkeys.stop()
    }
}
