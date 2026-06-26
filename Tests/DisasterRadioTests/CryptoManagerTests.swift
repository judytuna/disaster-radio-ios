import XCTest
import CryptoKit
@testable import DisasterRadio

final class CryptoManagerTests: XCTestCase {

    func test_publicKey_is32Bytes() {
        XCTAssertEqual(CryptoManager.shared.publicKeyData.count, 32)
    }

    func test_sign_producesNonEmptySignature() {
        let sig = CryptoManager.shared.sign("hello disaster.radio")
        XCTAssertNotNil(sig)
        XCTAssertFalse(sig!.isEmpty)
    }

    func test_sign_produces64ByteEd25519Signature() {
        let sig = CryptoManager.shared.sign("test message")
        // Ed25519 detached signatures are always 64 bytes
        XCTAssertEqual(sig?.count, 64)
    }

    func test_sign_isVerifiableWithPublicKey() throws {
        let message = "~ judytuna joined the channel"
        guard let sig = CryptoManager.shared.sign(message) else {
            XCTFail("sign returned nil")
            return
        }
        let pubKey = try Curve25519.Signing.PublicKey(
            rawRepresentation: CryptoManager.shared.publicKeyData
        )
        let messageData = message.data(using: .utf8)!
        XCTAssertTrue(pubKey.isValidSignature(sig, for: messageData))
    }

    func test_sign_differentMessagesProduceDifferentSignatures() {
        let sig1 = CryptoManager.shared.sign("message one")
        let sig2 = CryptoManager.shared.sign("message two")
        XCTAssertNotEqual(sig1, sig2)
    }

    func test_sign_emptyString_stillProducesSignature() {
        let sig = CryptoManager.shared.sign("")
        XCTAssertNotNil(sig)
        XCTAssertEqual(sig?.count, 64)
    }

    func test_publicKey_isStableAcrossCalls() {
        // Key should be loaded from Keychain, not regenerated each call
        let key1 = CryptoManager.shared.publicKeyData
        let key2 = CryptoManager.shared.publicKeyData
        XCTAssertEqual(key1, key2)
    }
}
