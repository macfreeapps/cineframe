import SwiftUI

struct ExportProgressView: View {
    @Environment(QueueModel.self) private var queue

    var body: some View {
        if queue.isExporting {
            HStack(spacing: 10) {
                ProgressView(value: Double(queue.progressCompleted), total: Double(max(1, queue.progressTotal)))
                    .frame(maxWidth: 180)
                Text("\(queue.progressCompleted) / \(queue.progressTotal)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Button("Cancel") { queue.cancelExport() }.controlSize(.small)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Exporting, \(queue.progressCompleted) of \(queue.progressTotal)")
        } else if let status = queue.statusMessage {
            Text(status).font(.caption).lineLimit(1).foregroundStyle(.secondary)
        }
    }
}
