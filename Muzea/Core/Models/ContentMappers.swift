import Foundation

// MARK: - Makeup DTO → domain

extension UserDTO {
    func toDomain() -> User {
        User(
            id: id,
            userName: userName,
            email: email,
            fullName: fullName,
            avatarUrl: avatarUrl,
            role: role,
            createdAt: createdAt,
            enabled: enabled
        )
    }
}

extension VideoDTO {
    func toDomain() -> Video {
        Video(
            id: id,
            title: title,
            description: description,
            url: url,
            thumbnailUrl: thumbnailUrl,
            fileSize: fileSize,
            durationSeconds: durationSeconds,
            views: views,
            likes: likes,
            likedByMe: likedByMe,
            uploadedBy: uploadedBy,
            uploadedAt: uploadedAt
        )
    }
}

extension NewsDTO {
    func toDomain() -> News {
        News(
            id: id,
            title: title,
            content: content,
            imageUrl: imageUrl,
            relatedVideo: relatedVideo?.toDomain(),
            author: author,
            publishedAt: publishedAt
        )
    }
}

extension PageResponse {
    func toDomain<R>(_ transform: (T) -> R) -> Page<R> {
        Page(
            content: content.map(transform),
            totalElements: totalElements,
            totalPages: totalPages,
            number: number
        )
    }
}
