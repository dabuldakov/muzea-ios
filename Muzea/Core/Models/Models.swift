import Foundation

// MARK: - Makeup (main backend, :8085)

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct RegisterRequest: Encodable {
    let username: String
    let email: String
    let password: String
    let fullName: String
}

struct AuthResponse: Decodable {
    let token: String
    let username: String
    let role: String?
}

struct UpdateUserRequest: Encodable {
    let fullName: String?
    let email: String?
    let enabled: Bool
}

struct UserResponse: Decodable {
    let id: Int64
    let userName: String
    let email: String
    let fullName: String?
    let avatarUrl: String?
    let role: String
    let createdAt: String?
    let enabled: Bool?
}

struct NewsResponse: Decodable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let content: String
    let imageUrl: String?
    let relatedVideo: VideoResponse?
    let author: String
    let publishedAt: String
}

struct NewsCreateResponse: Decodable {
    let id: Int64
}

struct VideoResponse: Decodable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let description: String?
    let url: String
    let thumbnailUrl: String?
    let fileSize: Int64?
    let duration: String?
    let views: Int
    let likes: Int?
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

struct PageResponse<T: Decodable>: Decodable {
    let content: [T]
    let empty: Bool?
    let first: Bool?
    let last: Bool?
    let number: Int?
    let numberOfElements: Int?
    let size: Int?
    let totalElements: Int64?
    let totalPages: Int?
}

// MARK: - Chat backend (:8086)

struct ChatAuthResponse: Decodable {
    let token: String
    let refreshToken: String?
    let userUuid: String?
    let username: String?
    let email: String?
    let avatarUrl: String?
}

struct ChatLoginRequest: Encodable {
    let username: String
    let password: String
    let deviceId: String?
    let deviceName: String?
    let deviceType: String?
}

struct ChatRegisterRequest: Encodable {
    let username: String
    let email: String
    let password: String
    let deviceId: String?
    let deviceName: String?
    let deviceType: String?
}

struct ChatUserResponse: Decodable {
    let userUuid: String
    let username: String?
    let email: String?
    let firstName: String?
    let lastName: String?
    let fullName: String?
    let avatarUrl: String?
    let isOnline: Bool?
}

struct ChatResponse: Decodable, Identifiable, Hashable {
    var id: String { chatUuid }
    let chatUuid: String
    let chatType: String?
    let title: String?
    let avatarUrl: String?
    let createdAt: String?
    let updatedAt: String?
    let participantCount: Int64?
    let lastMessage: MessagePreview?
    let unreadCount: Int64?
}

struct MessagePreview: Decodable, Hashable {
    let messageUuid: String?
    let text: String?
    let senderId: Int64?
    let senderName: String?
    let createdAt: String?
}

struct ContactResponse: Decodable, Identifiable, Hashable {
    var id: String { contactUuid }
    let contactUuid: String
    let contactUserId: Int64?
    let contactUserUuid: String?
    let username: String?
    let firstName: String?
    let lastName: String?
    let fullName: String?
    let avatarUrl: String?
    let contactName: String?
    let isOnline: Bool
    let lastSeenAt: String?
    let addedAt: String?

    var displayName: String { contactName ?? fullName ?? username ?? "Contact" }
}

struct MessageResponse: Decodable, Identifiable, Hashable {
    var id: String { messageUuid }
    let messageUuid: String
    let chatUuid: String?
    let senderId: Int64?
    let senderUuid: String?
    let senderName: String?
    let senderAvatar: String?
    let text: String?
    let messageType: String?
    let replyToMessageUuid: String?
    let isEdited: Bool?
    let isDeleted: Bool?
    let isPinned: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct UnreadCountResponse: Decodable {
    let count: Int64
}

struct AvatarResponse: Decodable {
    let avatarUrl: String?
}

struct AddContactRequest: Encodable {
    let contactUserUuid: String
    let contactName: String?
}

struct CreatePrivateChatRequest: Encodable {
    let otherUserUuid: String
}

struct SendMessageRequest: Encodable {
    let text: String
    let messageType: String
}

struct FcmTokenRequest: Encodable {
    let token: String
    let deviceId: String?
}
