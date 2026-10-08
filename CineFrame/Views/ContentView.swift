import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(QueueModel.self) private var queue
    @Environment(AppSettings.self) private var settings
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if settings.quickMode {
                QuickModeView()
            } else if queue.items.isEmpty {
                DropZoneView(title: "Drop photos here",
                             subtitle: "Make a 2.39:1 cinematic crop with balanced 16:9 letterboxing.\nYour originals are always kept untouched.",
                             actionTitle: "Open…",
                             onOpen: { Self.openFiles(using: queue) })
            } else {
                NavigationSplitView {
                    QueueSidebarView()
                } detail: {
                    if let item = queue.activeItem {
                        HStack(spacing: 0) {
                            CropEditorView(item: item)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            Divider()
                            InspectorView(item: item, settings: settings)
                        }
                    } else {
                        ContentUnavailableView("Choose a photo", systemImage: "photo")
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .toolbar { editorToolbar }
            }
        }
        .frame(minWidth: settings.quickMode ? 380 : 900,
               minHeight: settings.quickMode ? 300 : 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 3)
                    .padding(8).allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            receive(providers, quick: settings.quickMode)
        }
        .onDeleteCommand { queue.removeSelected() }
    }

    @ToolbarContentBuilder private var editorToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { Self.openFiles(using: queue) } label: { Label("Open", systemImage: "plus") }
                .help("Open photos (⌘O)")
            Button { queue.resetActiveCrop() } label: { Label("Reset Crop", systemImage: "arrow.counterclockwise") }
                .disabled(queue.activeItem == nil)
        }
        ToolbarItem(placement: .principal) { ExportProgressView() }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                Task { await queue.exportSelected() }
            } label: { Label("Export", systemImage: "square.and.arrow.up") }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(queue.activeItem == nil || queue.isExporting)

            Button {
                Task { await queue.exportAll() }
            } label: { Label("Export All", systemImage: "square.stack.3d.up") }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(queue.items.isEmpty || queue.isExporting)

            Toggle(isOn: Binding(get: { settings.quickMode }, set: { settings.quickMode = $0 })) {
                Label("Quick Mode", systemImage: "bolt")
            }
            .toggleStyle(.button)
            .keyboardShortcut("q", modifiers: [.command, .option])
            SettingsLink { Label("Settings", systemImage: "gearshape") }
        }
    }

    static func openFiles(using queue: QueueModel) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Open"
        if panel.runModal() == .OK { queue.importURLs(panel.urls) }
    }

    private func receive(_ providers: [NSItemProvider], quick: Bool) -> Bool {
        let group = DispatchGroup()
        let collectedURLs = LockedURLCollector()
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL? = {
                    if let url = item as? URL { return url }
                    if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
                    if let url = item as? NSURL { return url as URL }
                    return nil
                }()
                if let url { collectedURLs.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) { queue.importURLs(collectedURLs.values, forceQuickMode: quick) }
        return true
    }
}
