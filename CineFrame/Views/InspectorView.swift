import SwiftUI

struct InspectorView: View {
    @Environment(QueueModel.self) private var queue
    @Bindable var item: PhotoItem
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("FRAME").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            Picker("Default bars", selection: $settings.barColor) {
                Text("Black").tag(BarColor.black)
                Text("White").tag(BarColor.white)
            }
            .pickerStyle(.segmented)
            Picker("This photo", selection: Binding(
                get: { item.barColorOverride?.rawValue ?? "default" },
                set: { value in item.barColorOverride = value == "default" ? nil : BarColor(rawValue: value) }
            )) {
                Text("Use default").tag("default")
                Text("Black").tag("black")
                Text("White").tag("white")
            }
            Divider()
            Button("Reset Crop") { item.resetCrop() }
                .keyboardShortcut("r", modifiers: []).frame(maxWidth: .infinity, alignment: .leading)
            Button("Apply Crop Position to Selected") { queue.applyCropPositionToSelected() }
                .disabled(queue.selectedIDs.count < 2)
                .help("Copy the normalized crop offset to other selected photos")
            Divider()
            if case .error(let message) = item.status {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16).frame(width: 245, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .accessibilityElement(children: .contain)
    }
}
