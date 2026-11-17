import Foundation

/// Очистка дискового кэша без пользовательских данных: outbox, черновики,
/// ключи и токены не трогаем.
final class CacheManager {
    private let directories: [URL]
    private let clearActions: [() async -> Void]
    private let fileManager = FileManager.default

    init(directories: [URL], clearActions: [() async -> Void] = []) {
        self.directories = directories
        self.clearActions = clearActions
    }

    func totalSizeBytes() -> Int64 {
        directories.reduce(0) { partial, directory in
            partial + size(of: directory)
        }
    }

    func clear() async {
        for directory in directories {
            guard let items = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else { continue }
            for item in items {
                try? fileManager.removeItem(at: item)
            }
        }
        URLCache.shared.removeAllCachedResponses()
        for action in clearActions {
            await action()
        }
    }

    private func size(of directory: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}
