import Foundation
import PixNabCore

/// Optional developer-facing CLI; it does not run any screen capture or access UserDefaults.
/// The GUI and CLI share exactly one color parser and one formatting implementation.
private enum Command {
    static func execute(_ arguments: [String]) -> Int32 {
        guard let action = arguments.first else { printUsage(); return 2 }
        switch action {
        case "formats":
            for item in ColorOutputFormat.allCases { print("\(item.rawValue)\t\(item.title)") }
            return 0
        case "convert":
            guard arguments.count == 3,
                  let color = ColorParser.parse(arguments[1]),
                  let format = ColorOutputFormat(rawValue: arguments[2]) else {
                fputs("Invalid color or format. Use 'formats' to list supported values.\n", stderr)
                return 2
            }
            print(ColorFormatter.format(color, as: format))
            return 0
        case "help", "--help", "-h":
            printUsage()
            return 0
        default:
            fputs("Unknown command: \(action)\n", stderr)
            printUsage()
            return 2
        }
    }
    static func printUsage() {
        print("PixNab CLI — color conversion without screen capture")
        print("  pixnab-cli formats")
        print("  pixnab-cli convert '#ff8800' cssOKLCH")
        print("  pixnab-cli convert 'rgb(94, 94, 94)' cssHex")
    }
}
exit(Command.execute(Array(CommandLine.arguments.dropFirst())))
