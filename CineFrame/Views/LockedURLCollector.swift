import Foundation

final class LockedURLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    func append(_ url: URL) { lock.lock(); storage.append(url); lock.unlock() }
    var values: [URL] { lock.lock(); defer { lock.unlock() }; return storage }
}
