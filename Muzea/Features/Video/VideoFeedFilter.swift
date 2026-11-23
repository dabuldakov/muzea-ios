import Foundation

/// Оставляет только видео самого пользователя.
/// Аналог Android `VideoFeedFilter`.
enum VideoFeedFilter {
    static func filter(_ videos: [Video], ownUsername: String?) -> [Video] {
        guard let me = ownUsername?.trimmingCharacters(in: .whitespaces), !me.isEmpty else {
            return []
        }
        return videos.filter { $0.uploadedBy.trimmingCharacters(in: .whitespaces) == me }
    }
}
