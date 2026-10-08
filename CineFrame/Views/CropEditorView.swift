import SwiftUI

struct CropEditorView: View {
    @Environment(QueueModel.self) private var queue
    @Bindable var item: PhotoItem
    @State private var showResultPreview = false
    @State private var isDragging = false
    @State private var initialCrop: NormalizedRect?
    @State private var lastMagnification: CGFloat?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(item.url.lastPathComponent, systemImage: "photo")
                    .lineLimit(1).truncationMode(.middle).font(.callout.weight(.medium))
                Spacer()
                if showResultPreview {
                    Text("RESULT PREVIEW").font(.caption2.weight(.semibold)).tracking(0.7).foregroundStyle(.secondary)
                }
                Button {
                    showResultPreview.toggle()
                    queue.resultPreviewRequested = showResultPreview
                } label: {
                    Label(showResultPreview ? "Edit Crop" : "Result Preview",
                          systemImage: showResultPreview ? "crop" : "play.rectangle")
                }
                .keyboardShortcut(.space, modifiers: [])
                .help("Toggle result preview (Space)")
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            Divider()

            if let preview = item.preview {
                GeometryReader { proxy in
                    let imageRect = fittedImageRect(image: preview, in: proxy.size)
                    ZStack {
                        Color(nsColor: .windowBackgroundColor).opacity(0.92)
                        Image(decorative: preview, scale: 1).resizable().interpolation(.high)
                            .frame(width: imageRect.width, height: imageRect.height)
                            .position(x: imageRect.midX, y: imageRect.midY)
                        if showResultPreview {
                            resultImage(from: preview).resizable().interpolation(.none).scaledToFit().padding(26)
                        } else {
                            cropOverlay(imageRect: imageRect)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .simultaneousGesture(MagnificationGesture().onChanged { value in
                        let factor = value / (lastMagnification ?? 1)
                        lastMagnification = value
                        queue.scaleActiveCrop(factor: Double(factor))
                    }.onEnded { _ in lastMagnification = nil })
                    .focusable()
                    .onMoveCommand(perform: handleMoveCommand)
                }
                .padding(18)
            } else {
                ProgressView("Loading preview…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            cropInfo
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .accessibilityElement(children: .contain)
        .onChange(of: queue.resultPreviewRequested) { _, value in showResultPreview = value }
    }

    private var cropInfo: some View {
        let frame = CinematicGeometry.frame(in: item.orientedSize, normalizedCrop: item.crop)
        return HStack(spacing: 8) {
            Text("Crop \(frame.crop.width) × \(frame.crop.height)")
            Text("→").foregroundStyle(.tertiary)
            Text("Output \(frame.output.width) × \(frame.output.height)")
            Text("·").foregroundStyle(.tertiary)
            Text("Bars \(frame.topBar) px")
            Spacer()
            Text("2.39:1 → 16:9").foregroundStyle(.secondary)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 16).padding(.vertical, 10).background(.bar)
        .accessibilityElement(children: .combine)
    }

    private func cropOverlay(imageRect: CGRect) -> some View {
        let rect = CGRect(x: imageRect.minX + item.crop.x * imageRect.width,
                          y: imageRect.minY + item.crop.y * imageRect.height,
                          width: item.crop.width * imageRect.width,
                          height: item.crop.height * imageRect.height)
        return ZStack(alignment: .topLeading) {
            OutsideCropMask(cropRect: rect)
            Rectangle().strokeBorder(.white, lineWidth: 1.5)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .contentShape(Rectangle())
                .gesture(moveGesture(imageRect: imageRect))
                .accessibilityLabel("Move crop")
            if isDragging {
                Path { path in
                    for divider in [1.0 / 3.0, 2.0 / 3.0] {
                        let x = rect.minX + rect.width * divider
                        let y = rect.minY + rect.height * divider
                        path.move(to: CGPoint(x: x, y: rect.minY)); path.addLine(to: CGPoint(x: x, y: rect.maxY))
                        path.move(to: CGPoint(x: rect.minX, y: y)); path.addLine(to: CGPoint(x: rect.maxX, y: y))
                    }
                }
                .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 0.7, dash: [4, 4]))
                .allowsHitTesting(false)
            }
            ForEach(CropCorner.allCases) { corner in
                Circle().fill(.white).overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 1))
                    .frame(width: 12, height: 12).position(corner.point(in: rect))
                    .contentShape(Rectangle().size(width: 28, height: 28))
                    .gesture(resizeGesture(corner: corner, imageRect: imageRect))
                    .accessibilityElement().accessibilityLabel("Resize crop from \(corner.accessibilityName)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Use the Crop menu brackets to resize by ten pixels.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHint("Drag the crop to move it. Drag a corner to resize while keeping 2.39 to 1.")
    }

    private func moveGesture(imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if initialCrop == nil { initialCrop = item.crop }
                guard let start = initialCrop else { return }
                isDragging = true
                let x = min(max(0, start.x + value.translation.width / imageRect.width), max(0, 1 - start.width))
                let y = min(max(0, start.y + value.translation.height / imageRect.height), max(0, 1 - start.height))
                item.setCrop(NormalizedRect(x: x, y: y, width: start.width, height: start.height))
            }
            .onEnded { _ in initialCrop = nil; isDragging = false }
    }

    private func resizeGesture(corner: CropCorner, imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if initialCrop == nil { initialCrop = item.crop }
                guard let start = initialCrop, item.orientedSize.isPositive else { return }
                isDragging = true
                let maximum = CinematicGeometry.maximumCropSize(in: item.orientedSize)
                let minimum = min(maximum.width, max(320, Int((Double(item.orientedSize.width) * 0.10).rounded())))
                let sign = corner.resizesRight ? 1.0 : -1.0
                let delta = value.translation.width / imageRect.width * Double(item.orientedSize.width) * sign
                let requested = Int((start.width * Double(item.orientedSize.width) + delta).rounded())
                let width = min(max(minimum, requested), maximum.width)
                let widthNorm = Double(width) / Double(item.orientedSize.width)
                let heightNorm = Double(width) / CinematicGeometry.cropRatio / Double(item.orientedSize.height)
                let anchorX = corner.resizesRight ? start.x : start.x + start.width
                let anchorY = corner.resizesBottom ? start.y : start.y + start.height
                let x = corner.resizesRight ? anchorX : anchorX - widthNorm
                let y = corner.resizesBottom ? anchorY : anchorY - heightNorm
                item.setCrop(NormalizedRect(x: min(max(0, x), max(0, 1 - widthNorm)),
                                            y: min(max(0, y), max(0, 1 - heightNorm)),
                                            width: widthNorm, height: heightNorm))
            }
            .onEnded { _ in initialCrop = nil; isDragging = false }
    }

    private func resultImage(from preview: CGImage) -> Image {
        let size = PixelSize(width: preview.width, height: preview.height)
        let frame = CinematicGeometry.frame(in: size, normalizedCrop: item.crop)
        let rendered = try? CinematicRenderer.render(orientedImage: preview, crop: frame.crop,
                                                      barColor: item.barColorOverride ?? queue.settings.barColor)
        return rendered.map { Image(decorative: $0, scale: 1) } ?? Image(systemName: "photo")
    }

    private func fittedImageRect(image: CGImage, in bounds: CGSize) -> CGRect {
        let scale = min(bounds.width / CGFloat(image.width), bounds.height / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        return CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard let preview = item.preview else { return }
        let dx = 1 / Double(max(1, preview.width))
        let dy = 1 / Double(max(1, preview.height))
        switch direction {
        case .left: queue.nudgeActiveCrop(dx: -dx, dy: 0)
        case .right: queue.nudgeActiveCrop(dx: dx, dy: 0)
        case .up: queue.nudgeActiveCrop(dx: 0, dy: -dy)
        case .down: queue.nudgeActiveCrop(dx: 0, dy: dy)
        @unknown default: break
        }
    }
}

private struct OutsideCropMask: View {
    let cropRect: CGRect
    var body: some View {
        GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size)
            let crop = cropRect.intersection(bounds)
            Path { path in
                path.addRect(CGRect(x: 0, y: 0, width: bounds.width, height: max(0, crop.minY)))
                path.addRect(CGRect(x: 0, y: crop.maxY, width: bounds.width, height: max(0, bounds.maxY - crop.maxY)))
                path.addRect(CGRect(x: 0, y: crop.minY, width: max(0, crop.minX), height: crop.height))
                path.addRect(CGRect(x: crop.maxX, y: crop.minY, width: max(0, bounds.maxX - crop.maxX), height: crop.height))
            }
            .fill(.black.opacity(0.62))
        }
        .allowsHitTesting(false)
    }
}

private enum CropCorner: String, CaseIterable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight
    var id: String { rawValue }
    var resizesRight: Bool { self == .topRight || self == .bottomRight }
    var resizesBottom: Bool { self == .bottomLeft || self == .bottomRight }
    var accessibilityName: String { rawValue.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).lowercased() }
    func point(in rect: CGRect) -> CGPoint {
        CGPoint(x: resizesRight ? rect.maxX : rect.minX, y: resizesBottom ? rect.maxY : rect.minY)
    }
}
