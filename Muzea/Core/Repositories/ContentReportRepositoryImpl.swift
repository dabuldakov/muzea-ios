import Foundation

/// Жалоба на новость/видео в makeup-сервисе.
protocol ContentReportRepository {
    func report(contentType: String, contentId: Int64, reason: String, comment: String?) async throws
}

final class ContentReportRepositoryImpl: ContentReportRepository {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func report(
        contentType: String,
        contentId: Int64,
        reason: String,
        comment: String?
    ) async throws {
        try await client.requestVoid(
            "POST",
            "/api/reports",
            body: CreateContentReportRequest(
                contentType: contentType,
                contentId: contentId,
                reason: reason,
                comment: comment
            )
        )
    }
}
