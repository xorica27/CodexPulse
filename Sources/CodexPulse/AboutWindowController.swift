import AppKit
import SwiftUI

@MainActor
final class AboutWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About CodexPulse"
        window.contentView = NSHostingView(rootView: AboutView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

private struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .cornerRadius(16)

            Text("CodexPulse")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Version \(version)")
                .foregroundStyle(.secondary)

            Text("CodexPulse runs locally and reads Codex rate-limit data from the local Codex app helper. It does not send your usage data anywhere.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link("View Releases", destination: URL(string: "https://github.com/xorica27/CodexPulse/releases/latest")!)
        }
        .padding(24)
        .frame(width: 420, height: 260)
    }
}
