import Foundation

/// Проверка целостности MP4/MOV до загрузки.
///
/// Облачные провайдеры (Google Фото, iCloud, кэш мессенджеров) иногда отдают
/// поток короче файла: копия «успешна», но в MinIO уезжает половина ролика.
/// Для MP4/MOV обрыв виден по атомам: размер `mdat` выходит за конец файла.
/// Для остальных контейнеров проверка не выполняется.
enum VideoFileValidator {

    /// `true` — файл заведомо обрезан и загружать его нельзя.
    static func isTruncated(_ data: Data) -> Bool {
        guard data.count >= 16 else { return true }
        return walkAtoms(data)
    }

    /// Короткая диагностика для телеметрии: `ftyp=24,moov=...,mdat=... file=...`.
    static func describe(_ data: Data) -> String {
        var offset = 0
        var parts: [String] = []
        while offset + 8 <= data.count, parts.count < 6 {
            var size = Int(readUInt32(data, at: offset))
            let type = readType(data, at: offset + 4)
            if size == 1, offset + 16 <= data.count {
                size = Int(readUInt64(data, at: offset + 8))
            }
            parts.append("\(type)=\(size)")
            if size < 8 { break }
            offset += size
        }
        return parts.joined(separator: ",") + " file=\(data.count)"
    }

    private static func walkAtoms(_ data: Data) -> Bool {
        let firstSize = readUInt32(data, at: 0)
        guard readType(data, at: 4) == "ftyp", firstSize >= 8 else {
            // Не MP4/MOV — не наш формат, проверку не применяем.
            return false
        }

        var offset = 0
        while offset + 8 <= data.count {
            var size = Int64(readUInt32(data, at: offset))
            let type = readType(data, at: offset + 4)
            guard !type.isEmpty else { return false }

            switch size {
            case 0:
                // Атом до конца файла — валидный вариант.
                return false
            case 1:
                guard offset + 16 <= data.count else { return true }
                size = Int64(bitPattern: readUInt64(data, at: offset + 8))
            case ..<8:
                return true
            default:
                break
            }

            let next = Int64(offset) + size
            if next > Int64(data.count) { return true }
            offset = Int(next)
        }
        return false
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return data[offset..<offset + 4].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private static func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
        guard offset + 8 <= data.count else { return 0 }
        return data[offset..<offset + 8].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    private static func readType(_ data: Data, at offset: Int) -> String {
        guard offset + 4 <= data.count else { return "" }
        return String(decoding: data[offset..<offset + 4], as: UTF8.self)
    }
}
