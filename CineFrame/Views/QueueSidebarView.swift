import AppKit
import SwiftUI

struct QueueSidebarView: View {
    @Environment(QueueModel.self) private var queue

    var body: some View {
        @Bindable var queue = queue
        List(selection: $queue.selectedIDs) {
            ForEach(queue.items) { item in
                QueueRow(item: item)
                    .tag(item.id)
                    .accessibilityLabel("\(item.url.lastPathComponent), \(item.status.title)")
            }
            .onMove { source, destination in queue.items.move(fromOffsets: source, toOffset: destination) }
            .onDelete { offsets in queue.removeItems(ids: Set(offsets.map { queue.items[$0].id })) }
        }
        .listStyle(.sidebar)
        .navigationTitle("Queue · \(queue.items.count)")
        .onMoveCommand { direction in
            guard !queue.items.isEmpty else { return }
            let current = queue.items.firstIndex { $0.id == queue.activeItemID } ?? 0
            let target: Int
            switch direction {
            case .up: target = max(0, current - 1)
            case .down: target = min(queue.items.count - 1, current + 1)
            default: return
            }
            queue.selectedIDs = [queue.items[target].id]
            queue.activeItemID = queue.items[target].id
        }
        .onChange(of: queue.selectedIDs) { oldSelection, newSelection in
            let newlySelected = queue.items.first { newSelection.contains($0.id) && !oldSelection.contains($0.id) }
            if let newlySelected { queue.activeItemID = newlySelected.id }
            else if let first = queue.items.first(where: { newSelection.contains($0.id) }) { queue.activeItemID = first.id }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { ContentView.openFiles(using: queue) } label: { Label("Add Photos", systemImage: "plus") }
                    .help("Add photos to the queue")
            }
        }
    }
}

private struct QueueRow: View {
    @Bindable var item: PhotoItem

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let preview = item.preview {
                    Image(decorative: preview, scale: 1).resizable().scaledToFill()
                } else {
                    Rectangle().fill(.quaternary).overlay { ProgressView().controlSize(.small) }
                }
            }
            .frame(width: 58, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                    .font(.system(size: 12, weight: .medium))
                HStack(spacing: 5) {
                    statusSymbol
                        .font(.system(size: 10, weight: .semibold))
                    Text(item.status.title).font(.caption2).lineLimit(1)
                }
                .foregroundStyle(statusColor)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var statusSymbol: some View {
        switch item.status {
        case .autoCrop: Image(systemName: "crop")
        case .adjusted: Image(systemName: "slider.horizontal.3")
        case .exporting: ProgressView().controlSize(.mini)
        case .exported: Image(systemName: "checkmark.circle.fill")
        case .error: Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .error: .red
        case .exported: .green
        default: .secondary
        }
    }
}
