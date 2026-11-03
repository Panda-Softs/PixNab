import AppKit

/// A menu-bar-only macOS application. AppKit owns the application lifecycle;
/// SwiftUI is used only for views hosted in explicitly created windows.
///
/// Do not add an empty SwiftUI Settings scene here: macOS can present it as
/// a second, blank settings window even though PreferencesView is hosted by
/// AppController.showSettings().
@MainActor
@main
enum PixNabApp {
    // NSApplication's delegate isn't a guaranteed strong reference. Keep our
    // delegate alive for the entire process lifetime.
    private static let appDelegate = PixNabDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = appDelegate
        app.run()
    }
}

@MainActor
final class PixNabDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let application = AppController()
        controller = application
        application.launch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    // Avoid restoring a window created by the obsolete empty Settings scene
    // when upgrading from earlier builds. Users can open Preferences and
    // Colors & Formats explicitly from the status menu instead.
    func application(_ application: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        false
    }

    func application(_ application: NSApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
