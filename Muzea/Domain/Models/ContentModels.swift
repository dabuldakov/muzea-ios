import Foundation

/// Доменные модели контента makeup — те же имена и поля, что в Android
/// `domain/model/ContentModels.kt`.

struct User: Identifiable, Hashable {
    let id: Int64
    let userName: String
    let email: String?
    let fullName: String?
    let avatarUrl: String?
    let role: String
    let createdAt: String?
    let enabled: Bool?
}

struct News: Identifiable, Hashable {
    let id: Int64
    let title: String
    let content: String
    let imageUrl: String?
    let relatedVideo: Video?
    let author: String
    let publishedAt: String
    var views: Int64 = 0
    var likes: Int64 = 0
    var commentsCount: Int64 = 0
    var likedByMe: Bool = false
}

struct NewsComment: Identifiable, Hashable {
    let id: Int64
    let newsId: Int64
    let content: String
    let author: String
    let createdAt: String
    let authorAvatarUrl: String? = nil
}

struct NewsCommentsPage {
    let comments: [NewsComment]
    let total: Int64
    let hasMore: Bool
    let nextBefore: Int64?
}

struct Video: Identifiable, Hashable {
    let id: Int64
    let title: String
    let description: String?
    let url: String
    let thumbnailUrl: String?
    let fileSize: Int64?
    /// Бэкенд отдаёт `durationSeconds`, а не строку `duration`.
    let durationSeconds: Double?
    let views: Int
    let likes: Int?
    let likedByMe: Bool?
    let uploadedBy: String
    let uploadedAt: String

    var fullThumbnailURL: URL? {
        guard let thumbnailUrl, !thumbnailUrl.isEmpty else { return nil }
        return ImageURL.makeup(thumbnailUrl)
    }

    var fullVideoURL: URL? {
        if url.hasPrefix("http") { return URL(string: url) }
        return ImageURL.makeup(url)
    }
}

/// Страница списка без привязки к Spring/JSON. DTO-страница маппится в неё.
struct Page<Element> {
    let content: [Element]
    let totalElements: Int64?
    let totalPages: Int?
    let number: Int?

    var isEmpty: Bool { content.isEmpty }
}
