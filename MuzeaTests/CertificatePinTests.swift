import Security
import XCTest
@testable import Muzea

final class CertificatePinTests: XCTestCase {

    /// Промежуточный CA Let's Encrypt YE1 (публичный сертификат).
    private let intermediateBase64 = "MIICizCCAhGgAwIBAgIQXd1w3TH4AchcGGp6BLgK/jAKBggqhkjOPQQDAzAuMQswCQYDVQQGEwJVUzENMAsGA1UEChMESVNSRzEQMA4GA1UEAxMHUm9vdCBZRTAeFw0yNTA5MDMwMDAwMDBaFw0yODA5MDIyMzU5NTlaMDMxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQwwCgYDVQQDEwNZRTEwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAQHZVB1/mimla2hfSurylScjPMZaOJXLz/NnAc2sylm8WDyhU9Ccp+zASQi5vSwGGJjSGklkD9fdPR8GpyDIOIjCEfrnbt/v+ZSEPLLEGbaM6EccDbN7p9xteIm2Avf+ryjge4wgeswDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFLsgykcL/tflnPmPCSqjjDdFsbzYMB8GA1UdIwQYMBaAFKPIJlqOoUzQNWP8myPIOq5W809WMDIGCCsGAQUFBwEBBCYwJDAiBggrBgEFBQcwAoYWaHR0cDovL3llLmkubGVuY3Iub3JnLzATBgNVHSAEDDAKMAgGBmeBDAECATAnBgNVHR8EIDAeMBygGqAYhhZodHRwOi8veWUuYy5sZW5jci5vcmcvMAoGCCqGSM49BAMDA2gAMGUCMQDgjUEahFT/h3DRakqiPZpLvPgfZwkt6K2EOMmh1nvEzl83eMLYcod4GCl3b0J1Nn0CMBNYmEQJb4CEG5WoOe7aRn/LVKu6saHmHEynI7ysIPd8zQsK1HdmhlHKlw9Z5GpGvA=="

    /// Корневой CA ISRG Root YE.
    private let rootBase64 = "MIICpjCCAiugAwIBAgIRAIchZfw0tuX7qK3Vs3BftTowCgYIKoZIzj0EAwMwTzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2VhcmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDIwHhcNMjYwNTEzMDAwMDAwWhcNMzIwOTAyMjM1OTU5WjAuMQswCQYDVQQGEwJVUzENMAsGA1UEChMESVNSRzEQMA4GA1UEAxMHUm9vdCBZRTB2MBAGByqGSM49AgEGBSuBBAAiA2IABDwS/6vhrcVqcbBo+wgdI3fwn9x7DNJJOY/lTOti0vkwuRN87RhEhTH17E7XyFjWsPYhIPt/wzOqxTd2b+4ZJNy9ID04YywF9U5zasDVyGSNErVNtz8uSGh5izW87j77GaOB6zCB6DAOBgNVHQ8BAf8EBAMCAQYwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUo8gmWo6hTNA1Y/ybI8g6rlbzT1YwHwYDVR0jBBgwFoAUfEKWrt5LSDv6kviejM9ti6lyN5UwMgYIKwYBBQUHAQEEJjAkMCIGCCsGAQUFBzAChhZodHRwOi8veDIuaS5sZW5jci5vcmcvMBMGA1UdIAQMMAowCAYGZ4EMAQIBMCcGA1UdHwQgMB4wHKAaoBiGFmh0dHA6Ly94Mi5jLmxlbmNyLm9yZy8wCgYIKoZIzj0EAwMDaQAwZgIxAMU19WCtmxVND8UHBZRoma49Z7jPs64Dma0eTu1OChVbB/2J7GV3nvYKAx54uk1G9QIxAO0miLVJu8PLNiXXXkiE/gsK3CTRTF/aeo4bMX42Zw40csRU6AC26hSW1/IWaas6dg=="

    private func certificate(_ base64: String) throws -> SecCertificate {
        let data = try XCTUnwrap(Data(base64Encoded: base64))
        return try XCTUnwrap(SecCertificateCreateWithData(nil, data as CFData))
    }

    func testPinnedHosts() {
        XCTAssertTrue(CertificatePin.isPinned(host: "api-muzea.su"))
        XCTAssertTrue(CertificatePin.isPinned(host: "CHAT-MUZEA.SU"))
        XCTAssertTrue(CertificatePin.isPinned(host: "auth.muzea.su"))
        XCTAssertFalse(CertificatePin.isPinned(host: "muzea.su"))
        XCTAssertFalse(CertificatePin.isPinned(host: "evil.example"))
    }

    func testIntermediateAndRootSpkiMatchAndroidPins() throws {
        let intermediate = try certificate(intermediateBase64)
        let root = try certificate(rootBase64)

        XCTAssertEqual(
            CertificatePin.spkiHash(certificate: intermediate),
            "brzvtCELCIZUo4sD/qPX0ccRtPsd3DY6RfmxpOU9oB4="
        )
        XCTAssertEqual(
            CertificatePin.spkiHash(certificate: root),
            "sCkq5UWXjg+7mKu9lMhhYF5bGLsy7VI/UNW3tccdR7w="
        )
    }

    func testMatchesRequiresKnownPin() {
        XCTAssertTrue(CertificatePin.matches(
            host: "api-muzea.su",
            spkiHashes: ["brzvtCELCIZUo4sD/qPX0ccRtPsd3DY6RfmxpOU9oB4="]
        ))
        XCTAssertFalse(CertificatePin.matches(
            host: "api-muzea.su",
            spkiHashes: ["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="]
        ))
        XCTAssertFalse(CertificatePin.matches(
            host: "evil.example",
            spkiHashes: ["brzvtCELCIZUo4sD/qPX0ccRtPsd3DY6RfmxpOU9oB4="]
        ))
    }

    func testRSASubjectPublicKeyInfoWrapsPKCS1() {
        let pkcs1 = Data(repeating: 0xAB, count: 270)
        let spki = CertificatePin.rsaSubjectPublicKeyInfo(pkcs1)

        XCTAssertEqual(spki.first, 0x30)
        XCTAssertTrue(spki.suffix(270).elementsEqual(pkcs1))
    }

    func testECSubjectPublicKeyInfoRejectsUnknownCurve() {
        XCTAssertNil(CertificatePin.ecSubjectPublicKeyInfo(Data(repeating: 4, count: 10)))
        XCTAssertNotNil(CertificatePin.ecSubjectPublicKeyInfo(Data(repeating: 4, count: 65)))
        XCTAssertNotNil(CertificatePin.ecSubjectPublicKeyInfo(Data(repeating: 4, count: 97)))
    }
}
