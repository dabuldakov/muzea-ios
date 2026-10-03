import Foundation

/// Подготовленный к загрузке файл (изображение/превью) для multipart-запросов.
struct UploadFile {
    let data: Data
    let fileName: String
    let mimeType: String
}
