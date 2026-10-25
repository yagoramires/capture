import AppKit
import SwiftUI

/// `Capture --snapshots <pasta>`: desenha o popover (parado, gravando, sem permissão) e as configurações em PNG e sai.
public enum Snapshots {
    public static func run(into folder: URL) {
        Log.enabled = false
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sample = PopoverState(version: "0.3.0", hosted: false, needsPermission: false, needsMicrophone: false,
                                  elapsed: nil, partial: false, delay: 0, showCursor: true, showClicks: false,
                                  recordMicrophone: false, openAfter: true, prints: "Mesa", recordings: "Filmes",
                                  updateReady: true, loginItem: true)
        save(PopoverView(state: sample) { _ in }, as: "capture-popover.png", in: folder)
        save(PopoverView(state: sample, help: true) { _ in }, as: "capture-popover-ajuda.png", in: folder)
        var recording = sample
        recording.elapsed = 84
        save(PopoverView(state: recording) { _ in }, as: "capture-popover-gravando.png", in: folder)
        var blocked = sample
        blocked.needsPermission = true
        blocked.updateReady = false
        save(PopoverView(state: blocked) { _ in }, as: "capture-popover-sem-permissao.png", in: folder)
        var hosted = sample
        hosted.hosted = true
        hosted.loginItem = nil
        hosted.recordMicrophone = true
        hosted.needsMicrophone = true
        save(PopoverView(state: hosted, help: true) { _ in }, as: "capture-popover-neyhub.png", in: folder)
        save(SettingsView(version: "0.3.0", hosted: false, wantsMicrophone: { false }, menuBar: true, onMenuBar: { _ in }, act: { _ in },
                          granted: { (true, true) }).frame(width: 520),
             as: "capture-settings.png", in: folder)
        save(SettingsView(version: "0.3.0", hosted: true, wantsMicrophone: { true }, menuBar: nil, onMenuBar: { _ in }, act: { _ in },
                          granted: { (false, false) }).frame(width: 520),
             as: "capture-settings-neyhub.png", in: folder)
        print("ok \(folder.path)")
    }

    private static func save<V: View>(_ view: V, as name: String, in folder: URL) {
        MainActor.assumeIsolated {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                print("falhou \(name)"); exit(1)
            }
            try? png.write(to: folder.appendingPathComponent(name))
        }
    }
}
