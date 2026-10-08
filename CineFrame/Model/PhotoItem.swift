import AppKit
import Observation

enum PhotoStatus: Equatable {
    case autoCrop
    case adjusted
    case exporting
    case exported(URL)
    case error(String)

    var title: String {
        switch self {
        case .autoCrop: "Auto crop"
        case .adjusted: "Adjusted"
        case .exporting: "Exporting…"
        case .exported: "Exported"
        case .error: "Error"
        }
    }
}

@Observable @MainActor
final class PhotoItem: Identifiable {
    let id = UUID()
    let url: URL
    var preview: CGImage?
    var orientedSize = PixelSize(width: 0, height: 0)
    var autoCropNormalized = NormalizedRect.unit
    var userCropNormalized: NormalizedRect?
    var barColorOverride: BarColor?
    var status: PhotoStatus = .autoCrop
    var bookmark: Data?

    var crop: NormalizedRect { userCropNormalized ?? autoCropNormalized }

    init(url: URL) {
        self.url = url
        bookmark = try? url.bookmarkData(options: .withSecurityScope,
                                         includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func setCrop(_ crop: NormalizedRect) {
        userCropNormalized = crop
        status = .adjusted
    }

    func resetCrop() {
        userCropNormalized = nil
        status = .autoCrop
    }
}
