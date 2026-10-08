import SwiftUI

struct DropZoneView: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "viewfinder")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title).font(.title2.weight(.medium))
            Text(subtitle).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(actionTitle, action: onOpen).keyboardShortcut("o", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [7, 5]))
                .padding(24)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }
}
