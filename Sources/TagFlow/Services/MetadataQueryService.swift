import Foundation
import Combine

/// Wraps NSMetadataQuery to search files by Finder tag via Spotlight.
final class MetadataQueryService: NSObject, ObservableObject {
    private var query: NSMetadataQuery?
    private var completionHandler: (([URL]) -> Void)?

    /// Finds all files tagged with the given tag name.
    /// Results are delivered asynchronously; updates continue until `stopQuery()` is called.
    func startQuery(forTagName tagName: String, onResults: @escaping ([URL]) -> Void) {
        stopQuery()
        self.completionHandler = onResults

        let q = NSMetadataQuery()
        // CONTAINS matches both "TagName" and "TagName\nN" (color variant)
        q.predicate = NSPredicate(format: "%K CONTAINS %@", "kMDItemUserTags", tagName)
        q.searchScopes = [NSMetadataQueryLocalComputerScope]
        q.sortDescriptors = [NSSortDescriptor(key: kMDItemDisplayName as String, ascending: true)]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinish(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: q
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: q
        )

        self.query = q
        // NSMetadataQuery must start on main thread (requires run loop)
        DispatchQueue.main.async { q.start() }
    }

    func stopQuery() {
        guard let q = query else { return }
        q.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: q)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: q)
        query = nil
        completionHandler = nil
    }

    @objc private func queryDidFinish(_ notification: Notification) {
        deliverResults()
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        deliverResults()
    }

    private func deliverResults() {
        guard let q = query else { return }
        q.disableUpdates()
        defer { q.enableUpdates() }

        let urls: [URL] = (0..<q.resultCount).compactMap { index in
            guard let item = q.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: kMDItemPath as String) as? String else {
                return nil
            }
            return URL(fileURLWithPath: path)
        }
        DispatchQueue.main.async { [weak self] in
            self?.completionHandler?(urls)
        }
    }
}
