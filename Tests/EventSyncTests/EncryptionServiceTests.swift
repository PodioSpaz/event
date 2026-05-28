import EventModels
import XCTest

@testable import EventSync

#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif

final class EncryptionServiceTests: XCTestCase {
  private var key: SymmetricKey!
  private var service: EncryptionService!

  override func setUp() async throws {
    key = SymmetricKey(size: .bits256)
    service = EncryptionService(key: key)
  }

  // MARK: - Roundtrip

  func testEncryptDecryptRoundTrip() async throws {
    let payload = EncryptedPayload(
      notes: "secret notes",
      url: "https://example.com",
      location: "Office"
    )

    let encrypted = try await service.encrypt(
      payload, recordId: "R001", modifiedDate: "2026-03-19T10:00:00Z"
    )
    let decrypted = try await service.decrypt(
      encrypted.encryptedPayload,
      iv: encrypted.encryptedIV,
      recordId: "R001",
      modifiedDate: "2026-03-19T10:00:00Z"
    )

    XCTAssertEqual(decrypted.notes, "secret notes")
    XCTAssertEqual(decrypted.url, "https://example.com")
    XCTAssertEqual(decrypted.location, "Office")
  }

  // MARK: - IV Uniqueness

  func testIVUniqueness() async throws {
    let payload = EncryptedPayload(notes: "same content")

    let first = try await service.encrypt(
      payload, recordId: "R001", modifiedDate: "2026-03-19T10:00:00Z"
    )
    let second = try await service.encrypt(
      payload, recordId: "R001", modifiedDate: "2026-03-19T10:00:00Z"
    )

    XCTAssertNotEqual(
      first.encryptedIV, second.encryptedIV,
      "Each encryption must produce a unique IV"
    )
    XCTAssertNotEqual(
      first.encryptedPayload, second.encryptedPayload,
      "Different IVs must produce different ciphertext"
    )
  }

  // MARK: - Wrong Key

  func testWrongKeyFails() async throws {
    let payload = EncryptedPayload(notes: "secret")
    let encrypted = try await service.encrypt(
      payload, recordId: "R001", modifiedDate: "2026-03-19T10:00:00Z"
    )

    let wrongKey = SymmetricKey(size: .bits256)
    let wrongService = EncryptionService(key: wrongKey)

    do {
      _ = try await wrongService.decrypt(
        encrypted.encryptedPayload,
        iv: encrypted.encryptedIV,
        recordId: "R001",
        modifiedDate: "2026-03-19T10:00:00Z"
      )
      XCTFail("Expected decryption to fail with wrong key")
    } catch let error as EncryptionError {
      XCTAssertEqual(error, .decryptionFailed)
    }
  }

  // MARK: - AAD Mismatch

  func testAADMismatchFails() async throws {
    let payload = EncryptedPayload(notes: "tamper test")
    let encrypted = try await service.encrypt(
      payload, recordId: "T005", modifiedDate: "2026-03-19T10:00:00Z"
    )

    do {
      _ = try await service.decrypt(
        encrypted.encryptedPayload,
        iv: encrypted.encryptedIV,
        recordId: "T006",
        modifiedDate: "2026-03-19T10:00:00Z"
      )
      XCTFail("Expected decryption to fail with mismatched AAD")
    } catch let error as EncryptionError {
      XCTAssertEqual(error, .decryptionFailed)
    }
  }

  func testAADModifiedDateMismatchFails() async throws {
    let payload = EncryptedPayload(notes: "date test")
    let encrypted = try await service.encrypt(
      payload, recordId: "R001", modifiedDate: "2026-03-19T10:00:00Z"
    )

    do {
      _ = try await service.decrypt(
        encrypted.encryptedPayload,
        iv: encrypted.encryptedIV,
        recordId: "R001",
        modifiedDate: "2026-03-20T10:00:00Z"
      )
      XCTFail("Expected decryption to fail with mismatched modified date")
    } catch let error as EncryptionError {
      XCTAssertEqual(error, .decryptionFailed)
    }
  }

  // MARK: - Empty Payload

  func testEmptyPayloadRoundTrip() async throws {
    let payload = EncryptedPayload()
    XCTAssertTrue(payload.isEmpty)

    let encrypted = try await service.encrypt(
      payload, recordId: "R001", modifiedDate: "2026-03-19T10:00:00Z"
    )
    let decrypted = try await service.decrypt(
      encrypted.encryptedPayload,
      iv: encrypted.encryptedIV,
      recordId: "R001",
      modifiedDate: "2026-03-19T10:00:00Z"
    )

    XCTAssertTrue(decrypted.isEmpty)
  }

  // MARK: - Base64 Encoding

  func testBase64Encoding() async throws {
    let payload = EncryptedPayload(notes: "base64 check")
    let encrypted = try await service.encrypt(
      payload, recordId: "R001", modifiedDate: "2026-03-19T10:00:00Z"
    )

    XCTAssertNotNil(
      Data(base64Encoded: encrypted.encryptedPayload),
      "Encrypted payload must be valid base64"
    )
    XCTAssertNotNil(
      Data(base64Encoded: encrypted.encryptedIV),
      "Encrypted IV must be valid base64"
    )
  }

  // MARK: - Key Helpers

  func testKeyFromBase64Valid() throws {
    let rawKey = SymmetricKey(size: .bits256)
    let base64 = rawKey.withUnsafeBytes { Data($0).base64EncodedString() }
    let restored = try EncryptionService.keyFromBase64(base64)
    XCTAssertEqual(restored, rawKey)
  }

  func testKeyFromBase64InvalidBase64() {
    XCTAssertThrowsError(try EncryptionService.keyFromBase64("not-valid-base64!!!")) {
      error in
      guard let encError = error as? EncryptionError else {
        XCTFail("Expected EncryptionError")
        return
      }
      XCTAssertEqual(encError, .invalidBase64Key)
    }
  }

  func testKeyFromBase64WrongLength() {
    let shortData = Data(repeating: 0xAA, count: 16)
    let base64 = shortData.base64EncodedString()
    XCTAssertThrowsError(try EncryptionService.keyFromBase64(base64)) { error in
      guard let encError = error as? EncryptionError else {
        XCTFail("Expected EncryptionError")
        return
      }
      XCTAssertEqual(encError, .invalidKeyLength)
    }
  }

  func testKeyFromEnvironmentMissing() {
    unsetenv("EVENT_ENCRYPTION_KEY")
    XCTAssertThrowsError(try EncryptionService.keyFromEnvironment()) { error in
      guard let encError = error as? EncryptionError else {
        XCTFail("Expected EncryptionError")
        return
      }
      XCTAssertEqual(encError, .keyNotConfigured)
    }
  }

  func testKeyFromEnvironmentValid() throws {
    let rawKey = SymmetricKey(size: .bits256)
    let base64 = rawKey.withUnsafeBytes { Data($0).base64EncodedString() }
    setenv("EVENT_ENCRYPTION_KEY", base64, 1)
    defer { unsetenv("EVENT_ENCRYPTION_KEY") }

    let restored = try EncryptionService.keyFromEnvironment()
    XCTAssertEqual(restored, rawKey)
  }

  // MARK: - Invalid Input

  func testDecryptInvalidBase64Payload() async throws {
    do {
      _ = try await service.decrypt(
        "not-valid-base64!!!",
        iv: Data(repeating: 0, count: 12).base64EncodedString(),
        recordId: "R001",
        modifiedDate: "2026-03-19T10:00:00Z"
      )
      XCTFail("Expected invalid base64 payload error")
    } catch let error as EncryptionError {
      XCTAssertEqual(error, .invalidBase64Payload)
    }
  }

  func testDecryptInvalidBase64IV() async throws {
    let validPayload = Data(repeating: 0, count: 32).base64EncodedString()
    do {
      _ = try await service.decrypt(
        validPayload,
        iv: "not-valid-base64!!!",
        recordId: "R001",
        modifiedDate: "2026-03-19T10:00:00Z"
      )
      XCTFail("Expected invalid base64 IV error")
    } catch let error as EncryptionError {
      XCTAssertEqual(error, .invalidBase64IV)
    }
  }

  // MARK: - Complex Payload

  func testComplexPayloadRoundTrip() async throws {
    let alarm = Alarm(
      relativeOffset: -900, absoluteDate: nil, locationTrigger: nil, alarmType: "display"
    )
    let rule = RecurrenceRule(
      frequency: "weekly", interval: 1, daysOfWeek: ["MO", "WE", "FR"],
      daysOfMonth: nil, monthsOfYear: nil, weeksOfYear: nil,
      daysOfYear: nil, setPositions: nil, endDate: nil
    )

    let payload = EncryptedPayload(
      notes: "complex notes with unicode",
      url: "https://example.com/path?q=1",
      location: "123 Main St",
      alarms: [alarm],
      recurrenceRules: [rule],
      attendees: ["alice@example.com", "bob@example.com"]
    )

    let encrypted = try await service.encrypt(
      payload, recordId: "R002", modifiedDate: "2026-03-19T12:00:00Z"
    )
    let decrypted = try await service.decrypt(
      encrypted.encryptedPayload,
      iv: encrypted.encryptedIV,
      recordId: "R002",
      modifiedDate: "2026-03-19T12:00:00Z"
    )

    XCTAssertEqual(decrypted, payload)
  }
}
