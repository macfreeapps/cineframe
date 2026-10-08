import SwiftUI

struct QuickModeView: View {
    @Environment(QueueModel.self) private var queue

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("QUICK MODE", systemImage: "bolt.fill")
                    .font(.caption.weight(.bold)).tracking(0.8)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.orange.opacity(0.14), in: Capsule())
                Spacer()
                SettingsLink { Image(systemName: "gearshape") }
                    .help("Settings")
            }
            DropZoneView(title: queue.isExporting ? "Making cinematic frames…" : "Drop to make cinematic",
                         subtitle: "Images are center-cropped and saved to your output folder.",
                         actionTitle: "Choose Photos…",
                         onOpen: { ContentView.openFiles(using: queue) })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if queue.isExporting {
                ExportProgressView().padding(.bottom, 4)
            } else if let status = queue.statusMessage {
                HStack {
                    Label(status, systemImage: "checkmark.circle.fill").font(.caption).lineLimit(1)
                    Spacer()
                    Button("Show in Finder") { queue.revealLastExport() }.controlSize(.small)
                }
            } else {
                Text("Center crop · 2.39:1 · 16:9 output · never modifies originals")
                    .font(.caption2).foregroundStyle(.secondary).padding(.bottom, 5)
            }
        }
        .padding(16)
        .frame(minWidth: 360, idealWidth: 430, maxWidth: 520, minHeight: 280, idealHeight: 330, maxHeight: 440)
    }
}
