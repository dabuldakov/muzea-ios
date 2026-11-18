import Foundation

/// Временные файлы для шаринга скачанных вложений.
enum AttachmentFiles {
    static func write(data: Data, fileName: String, directory: URL? = nil) -> URL? {
        let safeName = sanitize(fileName)
        let targetDirectory = directory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("attachments", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: targetDirectory,
                withIntermediateDirectories: true
            )
            FileProtection.apply(toDirectory: targetDirectory)
            let url = targetDirectory.appendingPathComponent(safeName)
            try data.write(to: url, options: .atomic)
            FileProtection.apply(to: url)
            return url
        } catch {
            return nil
        }
    }

    static func sanitize(_ fileName: String) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "._- ()"))
        let cleaned = fileName.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }
        let result = String(cleaned)
        if result.isEmpty || result == "." || result == ".." {
            return "attachment"
        }
        return result
    }
}
