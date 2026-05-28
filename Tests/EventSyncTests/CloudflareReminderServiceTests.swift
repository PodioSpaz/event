import EventModels
import XCTest

@testable import EventSync

#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif

// MARK: - Tests

final class CloudflareReminderServiceTests: XCTestCase {
  private var mock: MockD1Client!
  private var encryption: EncryptionService!
  private var service: CloudflareReminderService!
  private var key: SymmetricKey!

  override func setUp() async throws {
    key = SymmetricKey(size: .bits256)
    encryption = EncryptionService(key: key)
    mock = MockD1Client()
    service = CloudflareReminderService(client: mock, encryption: encryption)
  }

  // MARK: - Helpers

  /// Encrypt a plain reminder the same way CloudflareReminderService does, so
  /// the mock can return it as if it came from D1.
  private func encryptForMock(_ reminder: Reminder) async throws -> Reminder {
    let payload = EncryptedPayload(
      notes: reminder.notes,
      url: reminder.url,
      location: reminder.location,
      alarms: reminder.alarms,
      recurrenceRules: reminder.recurrenceRules
    )
    guard !payload.isEmpty else { return reminder }

    let aadDate = reminder.lastModifiedDate ?? reminder.creationDate ?? ""
    let encrypted = try await encryption.encrypt(
      payload, recordId: reminder.id, modifiedDate: aadDate
    )
    let carrier = EncryptedCarrier(p: encrypted.encryptedPayload, i: encrypted.encryptedIV)
    let carrierJSON = try carrier.toJSONString()

    return Reminder(
      id: reminder.id,
      title: reminder.title,
      isCompleted: reminder.isCompleted,
      isFlagged: reminder.isFlagged,
      list: reminder.list,
      notes: carrierJSON,
      url: nil,
      location: nil,
      timeZone: reminder.timeZone,
      dueDate: reminder.dueDate,
      startDate: reminder.startDate,
      completionDate: reminder.completionDate,
      creationDate: reminder.creationDate,
      lastModifiedDate: reminder.lastModifiedDate,
      externalId: reminder.externalId,
      priority: reminder.priority,
      alarms: nil,
      recurrenceRules: nil,
      locationTrigger: reminder.locationTrigger
    )
  }

  // MARK: - fetchReminders

  func testFetchRemindersDecryptsData() async throws {
    let plain = Reminder(
      id: "R1", title: "Buy milk", isCompleted: false, isFlagged: false,
      list: "Work", notes: "Secret notes", url: "https://example.com",
      location: "Office", timeZone: "UTC", dueDate: "2026-03-20 10:00:00",
      startDate: nil, completionDate: nil, creationDate: "2026-03-19T10:00:00Z",
      lastModifiedDate: "2026-03-19T10:00:00Z", externalId: nil, priority: 5,
      alarms: nil, recurrenceRules: nil, locationTrigger: nil
    )
    let encrypted = try await encryptForMock(plain)
    mock.remindersToReturn = [encrypted]

    let result = try await service.fetchReminders(listName: nil, showCompleted: false)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].title, "Buy milk")
    XCTAssertEqual(result[0].notes, "Secret notes")
    XCTAssertEqual(result[0].url, "https://example.com")
    XCTAssertEqual(result[0].location, "Office")
  }

  func testFetchRemindersReturnsEmptyWhenNoneExist() async throws {
    mock.remindersToReturn = []

    let result = try await service.fetchReminders(listName: nil, showCompleted: false)

    XCTAssertTrue(result.isEmpty)
  }

  // MARK: - Filtering

  func testFilterByListName() async throws {
    let work = Reminder(
      id: "R1", title: "Work task", isCompleted: false, isFlagged: false,
      list: "Work", notes: nil, url: nil, location: nil, timeZone: "UTC",
      dueDate: nil, startDate: nil, completionDate: nil,
      creationDate: "2026-03-19T10:00:00Z", lastModifiedDate: "2026-03-19T10:00:00Z",
      externalId: nil, priority: 0, alarms: nil, recurrenceRules: nil,
      locationTrigger: nil
    )
    let personal = Reminder(
      id: "R2", title: "Personal task", isCompleted: false, isFlagged: false,
      list: "Personal", notes: nil, url: nil, location: nil, timeZone: "UTC",
      dueDate: nil, startDate: nil, completionDate: nil,
      creationDate: "2026-03-19T10:00:00Z", lastModifiedDate: "2026-03-19T10:00:00Z",
      externalId: nil, priority: 0, alarms: nil, recurrenceRules: nil,
      locationTrigger: nil
    )
    mock.remindersToReturn = [work, personal]

    let result = try await service.fetchReminders(listName: "Work", showCompleted: false)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].title, "Work task")
    XCTAssertEqual(result[0].list, "Work")
  }

  func testFilterCompleted() async throws {
    let incomplete = Reminder(
      id: "R1", title: "Incomplete", isCompleted: false, isFlagged: false,
      list: "Work", notes: nil, url: nil, location: nil, timeZone: "UTC",
      dueDate: nil, startDate: nil, completionDate: nil,
      creationDate: "2026-03-19T10:00:00Z", lastModifiedDate: "2026-03-19T10:00:00Z",
      externalId: nil, priority: 0, alarms: nil, recurrenceRules: nil,
      locationTrigger: nil
    )
    let completed = Reminder(
      id: "R2", title: "Completed", isCompleted: true, isFlagged: false,
      list: "Work", notes: nil, url: nil, location: nil, timeZone: "UTC",
      dueDate: nil, startDate: nil, completionDate: "2026-03-19T12:00:00Z",
      creationDate: "2026-03-19T10:00:00Z", lastModifiedDate: "2026-03-19T12:00:00Z",
      externalId: nil, priority: 0, alarms: nil, recurrenceRules: nil,
      locationTrigger: nil
    )
    mock.remindersToReturn = [incomplete, completed]

    let withoutCompleted = try await service.fetchReminders(
      listName: nil, showCompleted: false)
    XCTAssertEqual(withoutCompleted.count, 1)
    XCTAssertEqual(withoutCompleted[0].title, "Incomplete")

    let withCompleted = try await service.fetchReminders(
      listName: nil, showCompleted: true)
    XCTAssertEqual(withCompleted.count, 2)
  }

  // MARK: - createReminder

  func testCreateReminderEncryptsSensitiveFields() async throws {
    let params = CreateReminderParams(
      title: "Test",
      listName: "Work",
      notes: "Confidential notes",
      url: "https://secret.example.com",
      dueDate: "2026-03-20 10:00:00",
      priority: 1
    )

    let result = try await service.createReminder(params)

    XCTAssertEqual(result.title, "Test")
    XCTAssertEqual(result.list, "Work")
    XCTAssertEqual(result.notes, "Confidential notes")
    XCTAssertEqual(result.url, "https://secret.example.com")
    XCTAssertEqual(result.priority, 1)

    // Verify the pushed reminder has encrypted notes (carrier JSON)
    XCTAssertEqual(mock.pushedReminders.count, 1)
    let pushed = mock.pushedReminders[0]
    XCTAssertNil(pushed.url, "URL should be nil in the D1 record (encrypted)")
    XCTAssertNotNil(pushed.notes, "Notes should carry the encrypted carrier")
    // The pushed notes should be valid JSON (EncryptedCarrier)
    if let notes = pushed.notes {
      let carrier = EncryptedCarrier.fromJSON(notes)
      XCTAssertNotNil(carrier, "Pushed notes should be a valid EncryptedCarrier")
    }
  }

  func testCreateReminderWithoutSensitiveFields() async throws {
    let params = CreateReminderParams(
      title: "Plain",
      listName: nil,
      notes: nil,
      url: nil,
      dueDate: nil,
      priority: 0
    )

    let result = try await service.createReminder(params)

    XCTAssertEqual(result.title, "Plain")
    XCTAssertEqual(result.list, "Reminders", "Default list should be 'Reminders'")
    XCTAssertNil(result.notes)

    // When no sensitive fields, the pushed reminder should have no carrier
    XCTAssertEqual(mock.pushedReminders.count, 1)
    let pushed = mock.pushedReminders[0]
    XCTAssertNil(pushed.notes, "No notes means no carrier needed")
  }

  // MARK: - updateReminder

  func testUpdateReminderMergesFieldsAndReencrypts() async throws {
    let plain = Reminder(
      id: "R1", title: "Original", isCompleted: false, isFlagged: false,
      list: "Work", notes: "Old notes", url: "https://old.example.com",
      location: nil, timeZone: "UTC", dueDate: "2026-03-20 10:00:00",
      startDate: nil, completionDate: nil, creationDate: "2026-03-19T10:00:00Z",
      lastModifiedDate: "2026-03-19T10:00:00Z", externalId: nil, priority: 5,
      alarms: nil, recurrenceRules: nil, locationTrigger: nil
    )
    let encrypted = try await encryptForMock(plain)
    mock.remindersToReturn = [encrypted]

    let params = UpdateReminderParams(
      title: "Updated",
      notes: "New notes",
      priority: 1
    )

    let result = try await service.updateReminder(id: "R1", params: params)

    XCTAssertEqual(result.title, "Updated")
    XCTAssertEqual(result.notes, "New notes")
    XCTAssertEqual(result.priority, 1)
    XCTAssertEqual(result.url, "https://old.example.com", "URL should be preserved")
    XCTAssertEqual(result.dueDate, "2026-03-20 10:00:00", "Due date should be preserved")

    // Verify re-encryption happened
    XCTAssertEqual(mock.pushedReminders.count, 1)
    let pushed = mock.pushedReminders[0]
    XCTAssertNil(pushed.url, "URL should be encrypted in D1 record")
  }

  func testUpdateReminderNotFoundThrows() async throws {
    mock.remindersToReturn = []

    let params = UpdateReminderParams(title: "New")

    do {
      _ = try await service.updateReminder(id: "NONEXISTENT", params: params)
      XCTFail("Expected notFound error")
    } catch let error as EventCLIError {
      if case .notFound = error {
      } else {
        XCTFail("Expected notFound error, got \(error)")
      }
    }
  }

  func testUpdateReminderClearDueDate() async throws {
    let plain = Reminder(
      id: "R1", title: "Task", isCompleted: false, isFlagged: false,
      list: "Work", notes: nil, url: nil, location: nil, timeZone: "UTC",
      dueDate: "2026-03-20 10:00:00", startDate: nil, completionDate: nil,
      creationDate: "2026-03-19T10:00:00Z", lastModifiedDate: "2026-03-19T10:00:00Z",
      externalId: nil, priority: 0, alarms: nil, recurrenceRules: nil,
      locationTrigger: nil
    )
    mock.remindersToReturn = [plain]

    let params = UpdateReminderParams(clearDue: true)
    let result = try await service.updateReminder(id: "R1", params: params)

    XCTAssertNil(result.dueDate, "Due date should be cleared")
  }

  // MARK: - deleteReminder

  func testDeleteReminderCallsClient() async throws {
    try await service.deleteReminder(id: "R1")

    XCTAssertEqual(mock.deletedReminderIds.count, 1)
    XCTAssertEqual(mock.deletedReminderIds[0].id, "R1")
    XCTAssertNotNil(mock.deletedReminderIds[0].lastModified)
  }

  // MARK: - fetchReminder by ID

  func testFetchReminderByIdDecrypts() async throws {
    let plain = Reminder(
      id: "R1", title: "Target", isCompleted: false, isFlagged: false,
      list: "Work", notes: "Secret", url: nil, location: nil, timeZone: "UTC",
      dueDate: nil, startDate: nil, completionDate: nil,
      creationDate: "2026-03-19T10:00:00Z", lastModifiedDate: "2026-03-19T10:00:00Z",
      externalId: nil, priority: 0, alarms: nil, recurrenceRules: nil,
      locationTrigger: nil
    )
    let encrypted = try await encryptForMock(plain)
    mock.remindersToReturn = [encrypted]

    let result = try await service.fetchReminder(byId: "R1")

    XCTAssertEqual(result.title, "Target")
    XCTAssertEqual(result.notes, "Secret")
  }

  func testFetchReminderByIdNotFoundThrows() async throws {
    mock.remindersToReturn = []

    do {
      _ = try await service.fetchReminder(byId: "MISSING")
      XCTFail("Expected notFound error")
    } catch let error as EventCLIError {
      if case .notFound = error {
      } else {
        XCTFail("Expected notFound error, got \(error)")
      }
    }
  }

  // MARK: - Plain Notes Passthrough

  func testPlainNotesPassThroughWhenNotEncrypted() async throws {
    // A reminder with plain text notes (not an EncryptedCarrier) should be
    // returned as-is without decryption errors.
    let plain = Reminder(
      id: "R1", title: "Plain", isCompleted: false, isFlagged: false,
      list: "Work", notes: "Just plain text notes", url: nil, location: nil,
      timeZone: "UTC", dueDate: nil, startDate: nil, completionDate: nil,
      creationDate: "2026-03-19T10:00:00Z", lastModifiedDate: "2026-03-19T10:00:00Z",
      externalId: nil, priority: 0, alarms: nil, recurrenceRules: nil,
      locationTrigger: nil
    )
    mock.remindersToReturn = [plain]

    let result = try await service.fetchReminders(listName: nil, showCompleted: false)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].notes, "Just plain text notes")
  }

  // MARK: - Complex Encrypted Payload

  func testComplexPayloadEncryptionRoundTrip() async throws {
    let params = CreateReminderParams(
      title: "Complex",
      listName: "Work",
      notes: "Complex notes",
      url: "https://complex.example.com",
      dueDate: "2026-03-20 10:00:00",
      priority: 9
    )

    let created = try await service.createReminder(params)
    XCTAssertEqual(created.title, "Complex")
    XCTAssertEqual(created.notes, "Complex notes")

    // Now set up the mock to return the encrypted version and fetch it back
    let pushedReminder = mock.pushedReminders[0]
    mock.pushedReminders = []
    mock.remindersToReturn = [pushedReminder]

    let fetched = try await service.fetchReminder(byId: pushedReminder.id)
    XCTAssertEqual(fetched.title, "Complex")
    XCTAssertEqual(fetched.notes, "Complex notes")
    XCTAssertEqual(fetched.url, "https://complex.example.com")
  }
}
