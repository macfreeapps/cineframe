import Foundation

enum CineFrameError: LocalizedError {
    case unreadableImage(URL)
    case unsupportedImage(URL)
    case renderFailed
    case destinationCreationFailed(URL)
    case exportFailed(URL)
    case outputFolderUnavailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .unreadableImage(let url): "Could not read \(url.lastPathComponent)."
        case .unsupportedImage(let url): "\(url.lastPathComponent) is not a supported image."
        case .renderFailed: "CineFrame could not render the cropped image."
        case .destinationCreationFailed(let url): "Could not create the output file at \(url.path)."
        case .exportFailed(let url): "CineFrame could not finish exporting \(url.lastPathComponent)."
        case .outputFolderUnavailable: "The selected output folder is unavailable."
        case .permissionDenied: "CineFrame does not have permission to use that folder."
        }
    }
}
