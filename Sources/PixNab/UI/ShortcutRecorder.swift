import AppKit
import SwiftUI
import PixNabCore

/// Reusable recorder for real Carbon global hotkeys. The button only observes
/// key events while focused, not system-wide; no Accessibility permission needed.
struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: Hotkey
    let accessibilityLabel: String
    let language: AppLanguage
    let onChange: (Hotkey) -> Bool
    let onBegin: () -> Void
    let onEnd: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureButton {
        let button = ShortcutCaptureButton(frame: .zero)
        button.bezelStyle = .rounded
        button.onChange = onChange
        button.onBegin = onBegin
        button.onEnd = onEnd
        button.current = shortcut
        button.language = language
        button.setAccessibilityLabel(AppLocalization.string(accessibilityLabel, language: language))
        return button
    }

    func updateNSView(_ button: ShortcutCaptureButton, context: Context) {
        button.onChange = onChange
        button.onBegin = onBegin
        button.onEnd = onEnd
        button.current = shortcut
        button.language = language
        button.setAccessibilityLabel(AppLocalization.string(accessibilityLabel, language: language))
    }
}

final class ShortcutCaptureButton: NSButton {
    var onChange: ((Hotkey) -> Bool)?
    var onBegin: (() -> Void)?
    var onEnd: (() -> Void)?
    var current = Hotkey(keyCode: 8, modifiers: 0x0900) {
        didSet { if !recording { title = HotkeyDisplay.label(for: current) } }
    }
    var language: AppLanguage = .system {
        didSet { if recording { title = AppLocalization.string("Press shortcut…", language: language) } }
    }
    private var recording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        target = self
        action = #selector(beginRecording)
        title = HotkeyDisplay.label(for: current)
    }
    required init?(coder: NSCoder) { fatalError("Programmatic view only") }
    override var acceptsFirstResponder: Bool { true }

    @objc private func beginRecording() {
        guard !recording else { return }
        recording = true
        onBegin?()
        title = AppLocalization.string("Press shortcut…", language: language)
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        guard !event.isARepeat else { return }
        if event.keyCode == 53 { endRecording(); return } // Escape cancels.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= 0x0100 }
        if flags.contains(.shift) { modifiers |= 0x0200 }
        if flags.contains(.option) { modifiers |= 0x0800 }
        if flags.contains(.control) { modifiers |= 0x1000 }
        let proposed = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        guard HotkeyPolicy.isSafe(proposed), onChange?(proposed) == true else {
            NSSound.beep()
            title = AppLocalization.string("Try another shortcut…", language: language)
            return
        }
        current = proposed
        endRecording()
    }

    override func resignFirstResponder() -> Bool {
        endRecording()
        return super.resignFirstResponder()
    }

    private func endRecording() {
        guard recording else { return }
        recording = false
        title = HotkeyDisplay.label(for: current)
        onEnd?()
    }
}
