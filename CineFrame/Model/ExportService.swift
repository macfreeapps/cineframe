import Foundation

struct ExportRequest: Sendable {
    let itemID: UUID
    let sourceURL: URL
    let crop: NormalizedRect?
    let barColor: BarColor
    let outputDirectory: URL
    let configuration: ExportConfiguration
}

struct ExportOutcome: Sendable {
    let itemID: UUID
    let outputURL: URL?
    let errorMessage: String?
    var succeeded: Bool { outputURL != nil }
}

actor ExportService {
    static let shared = ExportService()

    func run(_ requests: [ExportRequest], maxConcurrent: Int,
             onCompletion: @escaping @Sendable (ExportOutcome) async -> Void) async {
        await withTaskGroup(of: ExportOutcome.self) { group in
            var iterator = requests.makeIterator()
            let concurrency = min(max(1, maxConcurrent), max(1, requests.count))
            for _ in 0..<concurrency {
                if let request = iterator.next() { group.addTask { Self.perform(request) } }
            }
            while let outcome = await group.next() {
                await onCompletion(outcome)
                guard !Task.isCancelled, let request = iterator.next() else { continue }
                group.addTask { Self.perform(request) }
            }
        }
    }

    private nonisolated static func perform(_ request: ExportRequest) -> ExportOutcome {
        if Task.isCancelled { return ExportOutcome(itemID: request.itemID, outputURL: nil, errorMessage: "Cancelled") }
        let inputScope = request.sourceURL.startAccessingSecurityScopedResource()
        defer { if inputScope { request.sourceURL.stopAccessingSecurityScopedResource() } }
        do {
            let result = try ImageExporter.export(sourceURL: request.sourceURL,
                                                  normalizedCrop: request.crop,
                                                  barColor: request.barColor,
                                                  outputDirectory: request.outputDirectory,
                                                  configuration: request.configuration)
            return ExportOutcome(itemID: request.itemID, outputURL: result.outputURL, errorMessage: nil)
        } catch is CancellationError {
            return ExportOutcome(itemID: request.itemID, outputURL: nil, errorMessage: "Cancelled")
        } catch {
            return ExportOutcome(itemID: request.itemID, outputURL: nil, errorMessage: error.localizedDescription)
        }
    }
}
