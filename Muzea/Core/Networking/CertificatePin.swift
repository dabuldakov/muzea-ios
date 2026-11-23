import CryptoKit
import Foundation
import Security

/// Пиннинг промежуточного и корневого CA (SPKI SHA-256), как в Android
/// `NetworkModule.certificatePinner`. Пиним CA, а не лист: листовой сертификат
/// меняется регулярно, CA — редко.
enum CertificatePin {
    static let pinsByHost: [String: Set<String>] = [
        "api-muzea.su": ["brzvtCELCIZUo4sD/qPX0ccRtPsd3DY6RfmxpOU9oB4=",
                         "sCkq5UWXjg+7mKu9lMhhYF5bGLsy7VI/UNW3tccdR7w="],
        "chat-muzea.su": ["brzvtCELCIZUo4sD/qPX0ccRtPsd3DY6RfmxpOU9oB4=",
                          "sCkq5UWXjg+7mKu9lMhhYF5bGLsy7VI/UNW3tccdR7w="],
        "auth.muzea.su": ["brzvtCELCIZUo4sD/qPX0ccRtPsd3DY6RfmxpOU9oB4=",
                          "sCkq5UWXjg+7mKu9lMhhYF5bGLsy7VI/UNW3tccdR7w="]
    ]

    static func isPinned(host: String) -> Bool {
        pinsByHost[host.lowercased()] != nil
    }

    static func matches(host: String, spkiHashes: [String]) -> Bool {
        guard let pins = pinsByHost[host.lowercased()], !pins.isEmpty else {
            return false
        }
        return spkiHashes.contains { pins.contains($0) }
    }

    /// Проверяет, что системный `SecTrust` валиден (подпись, цепочка, срок,
    /// hostname) И содержит один из наших пинов.
    ///
    /// Вызывать `SecTrustEvaluateWithError` обязательно: когда URLSession
    /// delegate возвращает `.useCredential(URLCredential(trust:))`, платформа
    /// больше не проверяет цепочку и hostname сама. Без этой проверки пиннинг
    /// принимал любой сертификат, выданный CA из списка (например, на чужой
    /// домен), и не защищал от MITM.
    static func isTrustedAndPinned(host: String, trust: SecTrust) -> Bool {
        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else {
            return false
        }
        return matches(host: host, spkiHashes: spkiHashes(trust: trust))
    }

    /// SPKI-хэши всех сертификатов цепочки, которые удалось разобрать.
    static func spkiHashes(trust: SecTrust) -> [String] {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else {
            return []
        }
        return chain.compactMap { spkiHash(certificate: $0) }
    }

    static func spkiHash(certificate: SecCertificate) -> String? {
        guard let key = SecCertificateCopyKey(certificate),
              let attributes = SecKeyCopyAttributes(key) as? [CFString: Any],
              let type = attributes[kSecAttrKeyType] as? String else {
            return nil
        }
        var error: Unmanaged<CFError>?
        guard let raw = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            return nil
        }

        let spki: Data
        if type == (kSecAttrKeyTypeRSA as String) {
            spki = rsaSubjectPublicKeyInfo(raw)
        } else if type == (kSecAttrKeyTypeECSECPrimeRandom as String) {
            guard let ec = ecSubjectPublicKeyInfo(raw) else { return nil }
            spki = ec
        } else {
            return nil
        }
        let digest = SHA256.hash(data: spki)
        return Data(digest).base64EncodedString()
    }

    /// `SecKeyCopyExternalRepresentation` для RSA отдаёт PKCS#1, а пины
    /// считаются по SubjectPublicKeyInfo. Оборачиваем в ASN.1 SEQUENCE.
    static func rsaSubjectPublicKeyInfo(_ pkcs1: Data) -> Data {
        let algorithm = Data([
            0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86,
            0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00
        ])
        var bitString = Data([0x03])
        bitString.append(derLength(pkcs1.count + 1))
        bitString.append(0x00)
        bitString.append(pkcs1)

        let content = algorithm + bitString
        var result = Data([0x30])
        result.append(derLength(content.count))
        result.append(content)
        return result
    }

    /// Точка SEC1 (`04 || X || Y`) → SubjectPublicKeyInfo для P-256/384/521.
    static func ecSubjectPublicKeyInfo(_ point: Data) -> Data? {
        let curveOID: [UInt8]
        switch point.count {
        case 65: curveOID = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07] // P-256
        case 97: curveOID = [0x2B, 0x81, 0x04, 0x00, 0x22] // P-384
        case 133: curveOID = [0x2B, 0x81, 0x04, 0x00, 0x23] // P-521
        default: return nil
        }

        var algorithmContent = Data([
            0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01
        ])
        algorithmContent.append(0x06)
        algorithmContent.append(derLength(curveOID.count))
        algorithmContent.append(contentsOf: curveOID)

        var algorithm = Data([0x30])
        algorithm.append(derLength(algorithmContent.count))
        algorithm.append(algorithmContent)

        var bitString = Data([0x03])
        bitString.append(derLength(point.count + 1))
        bitString.append(0x00)
        bitString.append(point)

        let content = algorithm + bitString
        var result = Data([0x30])
        result.append(derLength(content.count))
        result.append(content)
        return result
    }

    private static func derLength(_ length: Int) -> Data {
        if length < 0x80 {
            return Data([UInt8(length)])
        }
        var bytes: [UInt8] = []
        var value = length
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }
}

/// URLSessionDelegate с проверкой пинов для наших трёх API-хостов.
final class PinnedSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = space.serverTrust,
              CertificatePin.isPinned(host: space.host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Сначала штатная проверка доверия (включая hostname), затем пин.
        if CertificatePin.isTrustedAndPinned(host: space.host, trust: trust) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
