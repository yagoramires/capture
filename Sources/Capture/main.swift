import AppKit
import CaptureCore
import NeyKit

let arguments = CommandLine.arguments
if arguments.contains("--selftest") {
    NeyKitSelfTest.run()
    CaptureApp.selfTest()
    print("selftest ok")
    exit(0)
}

let app = NSApplication.shared
if let flag = arguments.firstIndex(of: "--snapshots"), arguments.indices.contains(flag + 1) {
    app.setActivationPolicy(.prohibited)
    Snapshots.run(into: URL(fileURLWithPath: arguments[flag + 1]))
    exit(0)
}
let delegate = CaptureAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
