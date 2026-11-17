import Foundation

/// Гифка из Klipy или сохранённая сервером.
struct Gif: Codable, Hashable, Identifiable {
    var id: String { providerGifId }

    let provider: String
    let providerGifId: String
    let title: String?
    let url: String
    let previewUrl: String?
    let mp4Url: String?
    let width: Int?
    let height: Int?
    let gifKey: String?
}

protocol GifRepository {
    /// Поиск/тренды. Пустой query — тренды. Ошибки сети не всплывают наружу:
    /// лучше старый кэш, чем пустой экран.
    func search(query: String, page: Int, size: Int) async -> [Gif]
}
