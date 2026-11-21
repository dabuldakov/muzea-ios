import Foundation

/// Прямая загрузка файла по presigned PUT в MinIO.
///
/// Используется отдельная URLSession без Authorization: ссылка уже подписана
/// (SigV4), и добавленный Bearer-заголовок ломает подпись. В отличие от
/// Android здесь нет отдельного HTTP-клиента, но принцип тот же.
final class PresignedUploader: NSObject {
    private var progressHandler: ((Int) -> Void)?
    private let configuration: URLSessionConfiguration

    init(configuration: URLSessionConfiguration = .ephemeral) {
        self.configuration = configuration
        super.init()
    }

    func put(
        data: Data,
        to url: URL,
        contentType: String,
        onProgress: @escaping (Int) -> Void
    ) async throws {
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")

        progressHandler = onProgress
        let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
        defer {
            progressHandler = nil
            session.finishTasksAndInvalidate()
        }

        let (_, response) = try await session.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(0, L10n.uploadFailed)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(http.statusCode, L10n.uploadFailed)
        }
        onProgress(100)
    }
}

extension PresignedUploader: URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let percent = Int((Double(totalBytesSent) / Double(totalBytesExpectedToSend)) * 100)
        progressHandler?(min(100, max(0, percent)))
    }
}
