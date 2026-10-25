import AppKit
import CaptureCore
import NeyKit

/// Capture dentro do NeyHub. Linka só CaptureCore e NeyKit (nunca NeyKitApp).
final class CaptureEntry: NSObject, NeyPlugin {
    private lazy var app = CaptureApp(defaults: AppDefaults.forApp("local.capture"), hosted: true,
                                      version: PluginLocation.version(dso: #dsohandle))

    var contractVersion: Int { neyPluginContractVersion }

    func start(host: NeyHost) {
        app.onOpenPermissions = { host.openPermissions() }
        app.start()
    }

    func stop() { app.stop() }
    func setMenuBarVisible(_ visible: Bool) { app.setMenuBarVisible(visible) }
    func makeScreen() -> NSViewController? { nil }
    func makeSettings() -> NSViewController { app.makeSettings() }
}

@_cdecl("neyhub_plugin_v1") public func neyhubPluginV1() -> UnsafeMutableRawPointer {
    Unmanaged.passRetained(CaptureEntry()).toOpaque()
}
