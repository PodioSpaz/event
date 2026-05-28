import EventModels
import XCTest

@testable import EventSync

#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif

// MARK: - Tests

final class CloudflareCalendarServiceTests: XCTestCase {
  private var mock: MockD1Client!
  private var encryption: EncryptionService!
  private var service: CloudflareCalendarService!
  private var key: SymmetricKey!

  override func setUp() async throws {
    key = SymmetricKey(size: .bits256)
    encryption = EncryptionService(key: key)
    mock = MockD1Client()
    service = CloudflareCalendarService(client: mock, encryption: encryption)
  }

  // MARK: - Helpers

  /// Encrypt a plain event the same way CloudflareCalendarService does, so
  /// the mock can return it as if it came from D1.
  private func encryptForMock(_ event: CalendarEvent) async throws -> CalendarEvent {
    let attendeeStrings = event.attendees?.map { $0.url }
    let payload = EncryptedPayload(
      notes: event.notes,
      url: event.url,
      location: event.location,
      alarms: event.alarms,
      recurrenceRules: event.recurrenceRules,
      attendees: attendeeStrings
    )
    guard !payload.isEmpty else { return event }

    let aadDate = event.lastModifiedDate ?? event.creationDate ?? ""
    let encrypted = try await encryption.encrypt(
      payload, recordId: event.id, modifiedDate: aadDate
    )
    let carrier = EncryptedCarrier(p: encrypted.encryptedPayload, i: encrypted.encryptedIV)
    let carrierJSON = try carrier.toJSONString()

    return CalendarEvent(
      id: event.id,
      title: event.title,
      calendar: event.calendar,
      startDate: event.startDate,
      endDate: event.endDate,
      isAllDay: event.isAllDay,
      location: nil,
      notes: carrierJSON,
      url: nil,
      timeZone: event.timeZone,
      creationDate: event.creationDate,
      lastModifiedDate: event.lastModifiedDate,
      status: event.status,
      availability: event.availability,
      alarms: nil,
      recurrenceRules: nil,
      attendees: nil
    )
  }

  // MARK: - fetchEvents

  func testFetchEventsDateRange() async throws {
    let inRange = CalendarEvent(
      id: "E1", title: "In Range", calendar: "Work",
      startDate: "2026-03-18 10:00:00", endDate: "2026-03-18 11:00:00",
      isAllDay: false, location: nil, notes: nil, url: nil, timeZone: "UTC",
      creationDate: "2026-03-17T10:00:00Z", lastModifiedDate: "2026-03-17T10:00:00Z",
      status: nil, availability: nil, alarms: nil, recurrenceRules: nil, attendees: nil
    )
    let outOfRange = CalendarEvent(
      id: "E2", title: "Out of Range", calendar: "Work",
      startDate: "2026-04-01 10:00:00", endDate: "2026-04-01 11:00:00",
      isAllDay: false, location: nil, notes: nil, url: nil, timeZone: "UTC",
      creationDate: "2026-03-17T10:00:00Z", lastModifiedDate: "2026-03-17T10:00:00Z",
      status: nil, availability: nil, alarms: nil, recurrenceRules: nil, attendees: nil
    )
    mock.eventsToReturn = [inRange, outOfRange]

    let result = try await service.fetchEvents(
      start: "2026-03-16 00:00:00",
      end: "2026-03-22 23:59:59",
      calendarName: nil
    )

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].title, "In Range")
  }

  func testFetchEventsCalendarFilter() async throws {
    let workEvent = CalendarEvent(
      id: "E1", title: "Work Meeting", calendar: "Work",
      startDate: "2026-03-18 10:00:00", endDate: "2026-03-18 11:00:00",
      isAllDay: false, location: nil, notes: nil, url: nil, timeZone: "UTC",
      creationDate: "2026-03-17T10:00:00Z", lastModifiedDate: "2026-03-17T10:00:00Z",
      status: nil, availability: nil, alarms: nil, recurrenceRules: nil, attendees: nil
    )
    let personalEvent = CalendarEvent(
      id: "E2", title: "Personal Event", calendar: "Personal",
      startDate: "2026-03-18 14:00:00", endDate: "2026-03-18 15:00:00",
      isAllDay: false, location: nil, notes: nil, url: nil, timeZone: "UTC",
      creationDate: "2026-03-17T10:00:00Z", lastModifiedDate: "2026-03-17T10:00:00Z",
      status: nil, availability: nil, alarms: nil, recurrenceRules: nil, attendees: nil
    )
    mock.eventsToReturn = [workEvent, personalEvent]

    let result = try await service.fetchEvents(
      start: "2026-03-16 00:00:00",
      end: "2026-03-22 23:59:59",
      calendarName: "Work"
    )

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].title, "Work Meeting")
    XCTAssertEqual(result[0].calendar, "Work")
  }

  func testFetchEventsDecryptsSensitiveFields() async throws {
    let plain = CalendarEvent(
      id: "E1", title: "Secret Meeting", calendar: "Work",
      startDate: "2026-03-18 10:00:00", endDate: "2026-03-18 11:00:00",
      isAllDay: false, location: "Office Room 42",
      notes: "Confidential agenda", url: "https://meet.example.com",
      timeZone: "UTC",
      creationDate: "2026-03-17T10:00:00Z", lastModifiedDate: "2026-03-17T10:00:00Z",
      status: nil, availability: nil, alarms: nil, recurrenceRules: nil, attendees: nil
    )
    let encrypted = try await encryptForMock(plain)
    mock.eventsToReturn = [encrypted]

    let result = try await service.fetchEvents(
      start: "2026-03-16 00:00:00",
      end: "2026-03-22 23:59:59",
      calendarName: nil
    )

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].title, "Secret Meeting")
    XCTAssertEqual(result[0].location, "Office Room 42")
    XCTAssertEqual(result[0].notes, "Confidential agenda")
    XCTAssertEqual(result[0].url, "https://meet.example.com")
  }

  func testFetchEventsReturnsEmptyWhenNoneExist() async throws {
    mock.eventsToReturn = []

    let result = try await service.fetchEvents(
      start: "2026-03-16 00:00:00",
      end: "2026-03-22 23:59:59",
      calendarName: nil
    )

    XCTAssertTrue(result.isEmpty)
  }

  // MARK: - createEvent

  func testCreateEventEncryptsSensitiveFields() async throws {
    let params = CreateEventParams(
      title: "Team Meeting",
      calendarName: "Work",
      startDate: "2026-03-20 14:00:00",
      endDate: "2026-03-20 15:00:00",
      isAllDay: false,
      location: "Conference Room A",
      notes: "Discuss Q2 goals",
      url: "https://zoom.example.com/123"
    )

    let result = try await service.createEvent(params)

    XCTAssertEqual(result.title, "Team Meeting")
    XCTAssertEqual(result.calendar, "Work")
    XCTAssertEqual(result.location, "Conference Room A")
    XCTAssertEqual(result.notes, "Discuss Q2 goals")
    XCTAssertEqual(result.url, "https://zoom.example.com/123")

    // Verify pushed event has encrypted fields
    XCTAssertEqual(mock.pushedEvents.count, 1)
    let pushed = mock.pushedEvents[0]
    XCTAssertNil(pushed.location, "Location should be nil in D1 record (encrypted)")
    XCTAssertNil(pushed.url, "URL should be nil in D1 record (encrypted)")
    XCTAssertNotNil(pushed.notes, "Notes should carry the encrypted carrier")
    if let notes = pushed.notes {
      let carrier = EncryptedCarrier.fromJSON(notes)
      XCTAssertNotNil(carrier, "Pushed notes should be a valid EncryptedCarrier")
    }
  }

  func testCreateEventWithoutSensitiveFields() async throws {
    let params = CreateEventParams(
      title: "Quick Sync",
      calendarName: nil,
      startDate: "2026-03-20 10:00:00",
      endDate: "2026-03-20 10:30:00",
      isAllDay: false,
      location: nil,
      notes: nil,
      url: nil
    )

    let result = try await service.createEvent(params)

    XCTAssertEqual(result.title, "Quick Sync")
    XCTAssertEqual(result.calendar, "Calendar", "Default calendar should be 'Calendar'")
    XCTAssertNil(result.location)
    XCTAssertNil(result.notes)

    // No sensitive fields, so no carrier needed
    XCTAssertEqual(mock.pushedEvents.count, 1)
    let pushed = mock.pushedEvents[0]
    XCTAssertNil(pushed.notes, "No notes means no carrier needed")
  }

  // MARK: - All-Day Events

  func testAllDayEvent() async throws {
    let params = CreateEventParams(
      title: "Company Holiday",
      calendarName: "Work",
      startDate: "2026-12-25",
      endDate: "2026-12-25",
      isAllDay: true,
      location: nil,
      notes: "Office closed",
      url: nil
    )

    let result = try await service.createEvent(params)

    XCTAssertEqual(result.title, "Company Holiday")
    XCTAssertTrue(result.isAllDay)
    XCTAssertEqual(result.startDate, "2026-12-25")
    XCTAssertEqual(result.endDate, "2026-12-25")
    XCTAssertEqual(result.notes, "Office closed")

    // Verify pushed event
    XCTAssertEqual(mock.pushedEvents.count, 1)
    let pushed = mock.pushedEvents[0]
    XCTAssertTrue(pushed.isAllDay)
  }

  func testAllDayEventFetchFiltering() async throws {
    // An all-day event on 2026-03-20 should be found when querying the range
    // that includes that date.
    let allDay = CalendarEvent(
      id: "E1", title: "Holiday", calendar: "Work",
      startDate: "2026-03-20", endDate: "2026-03-20",
      isAllDay: true, location: nil, notes: nil, url: nil, timeZone: "UTC",
      creationDate: "2026-03-17T10:00:00Z", lastModifiedDate: "2026-03-17T10:00:00Z",
      status: nil, availability: nil, alarms: nil, recurrenceRules: nil, attendees: nil
    )
    mock.eventsToReturn = [allDay]

    let result = try await service.fetchEvents(
      start: "2026-03-16",
      end: "2026-03-22",
      calendarName: nil
    )

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].title, "Holiday")
    XCTAssertTrue(result[0].isAllDay)
  }

  // MARK: - updateEvent

  func testUpdateEventMergesFieldsAndReencrypts() async throws {
    let plain = CalendarEvent(
      id: "E1", title: "Original", calendar: "Work",
      startDate: "2026-03-20 14:00:00", endDate: "2026-03-20 15:00:00",
      isAllDay: false, location: "Room A",
      notes: "Old notes", url: "https://old.example.com",
      timeZone: "UTC",
      creationDate: "2026-03-17T10:00:00Z", lastModifiedDate: "2026-03-17T10:00:00Z",
      status: nil, availability: nil, alarms: nil, recurrenceRules: nil, attendees: nil
    )
    let encrypted = try await encryptForMock(plain)
    mock.eventsToReturn = [encrypted]

    let params = UpdateEventParams(
      title: "Updated Title",
      location: "Room B"
    )

    let result = try await service.updateEvent(id: "E1", params: params)

    XCTAssertEqual(result.title, "Updated Title")
    XCTAssertEqual(result.location, "Room B")
    XCTAssertEqual(result.notes, "Old notes", "Notes should be preserved")
    XCTAssertEqual(result.url, "https://old.example.com", "URL should be preserved")
    XCTAssertEqual(
      result.startDate, "2026-03-20 14:00:00", "Start date should be preserved")

    // Verify re-encryption
    XCTAssertEqual(mock.pushedEvents.count, 1)
    let pushed = mock.pushedEvents[0]
    XCTAssertNil(pushed.location, "Location should be encrypted in D1 record")
    XCTAssertNil(pushed.url, "URL should be encrypted in D1 record")
  }

  func testUpdateEventNotFoundThrows() async throws {
    mock.eventsToReturn = []

    let params = UpdateEventParams(title: "New")

    do {
      _ = try await service.updateEvent(id: "NONEXISTENT", params: params)
      XCTFail("Expected notFound error")
    } catch let error as EventCLIError {
      if case .notFound = error {
      } else {
        XCTFail("Expected notFound error, got \(error)")
      }
    }
  }

  // MARK: - deleteEvent

  func testDeleteEventCallsClient() async throws {
    try await service.deleteEvent(id: "E1")

    XCTAssertEqual(mock.deletedEventIds.count, 1)
    XCTAssertEqual(mock.deletedEventIds[0].id, "E1")
    XCTAssertNotNil(mock.deletedEventIds[0].lastModified)
  }

  // MARK: - fetchEvent by ID

  func testFetchEventByIdDecrypts() async throws {
    let plain = CalendarEvent(
      id: "E1", title: "Target", calendar: "Work",
      startDate: "2026-03-20 10:00:00", endDate: "2026-03-20 11:00:00",
      isAllDay: false, location: "Room C",
      notes: "Secret notes", url: nil, timeZone: "UTC",
      creationDate: "2026-03-17T10:00:00Z", lastModifiedDate: "2026-03-17T10:00:00Z",
      status: nil, availability: nil, alarms: nil, recurrenceRules: nil, attendees: nil
    )
    let encrypted = try await encryptForMock(plain)
    mock.eventsToReturn = [encrypted]

    let result = try await service.fetchEvent(byId: "E1")

    XCTAssertEqual(result.title, "Target")
    XCTAssertEqual(result.location, "Room C")
    XCTAssertEqual(result.notes, "Secret notes")
  }

  func testFetchEventByIdNotFoundThrows() async throws {
    mock.eventsToReturn = []

    do {
      _ = try await service.fetchEvent(byId: "MISSING")
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
    let plain = CalendarEvent(
      id: "E1", title: "Plain", calendar: "Work",
      startDate: "2026-03-20 10:00:00", endDate: "2026-03-20 11:00:00",
      isAllDay: false, location: nil,
      notes: "Just plain text", url: nil, timeZone: "UTC",
      creationDate: "2026-03-17T10:00:00Z", lastModifiedDate: "2026-03-17T10:00:00Z",
      status: nil, availability: nil, alarms: nil, recurrenceRules: nil, attendees: nil
    )
    mock.eventsToReturn = [plain]

    let result = try await service.fetchEvents(
      start: "2026-03-16",
      end: "2026-03-22",
      calendarName: nil
    )

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].notes, "Just plain text")
  }

  // MARK: - Encryption Round Trip via Fetch

  func testEncryptionRoundTripViaCreateAndFetch() async throws {
    let params = CreateEventParams(
      title: "Round Trip",
      calendarName: "Work",
      startDate: "2026-03-20 14:00:00",
      endDate: "2026-03-20 15:00:00",
      isAllDay: false,
      location: "Room D",
      notes: "Round trip notes",
      url: "https://roundtrip.example.com"
    )

    _ = try await service.createEvent(params)

    // The pushed event should be in the mock's pushed list
    let pushedEvent = mock.pushedEvents[0]
    mock.pushedEvents = []
    mock.eventsToReturn = [pushedEvent]

    let fetched = try await service.fetchEvent(byId: pushedEvent.id)
    XCTAssertEqual(fetched.title, "Round Trip")
    XCTAssertEqual(fetched.location, "Room D")
    XCTAssertEqual(fetched.notes, "Round trip notes")
    XCTAssertEqual(fetched.url, "https://roundtrip.example.com")
  }
}
