import EventModels
import XCTest

@testable import EventSync

// MARK: - Mock D1 Client

final class MockD1Client: @unchecked Sendable, D1Client {
  var listsToReturn: [ReminderList] = []
  var pushedLists: [ReminderList] = []
  var deletedListIds: [(id: String, lastModified: String?)] = []

  var remindersToReturn: [Reminder] = []
  var pushedReminders: [Reminder] = []
  var deletedReminderIds: [(id: String, lastModified: String?)] = []

  var eventsToReturn: [CalendarEvent] = []
  var pushedEvents: [CalendarEvent] = []
  var deletedEventIds: [(id: String, lastModified: String?)] = []

  // MARK: Lists

  func pullAllLists() async throws -> [ReminderList] {
    listsToReturn
  }

  func pushLists(
    _ lists: [ReminderList],
    idOverrides: [String: String],
    lastModifiedByRemoteId: [String: String]
  ) async throws -> PushResult {
    pushedLists.append(contentsOf: lists)
    return PushResult(synced: lists.count, skipped: 0)
  }

  func deleteList(id: String, lastModified: String?) async throws {
    deletedListIds.append((id: id, lastModified: lastModified))
  }

  // MARK: Reminders

  func pullAllReminders() async throws -> [Reminder] {
    remindersToReturn
  }

  func pushReminders(
    _ reminders: [Reminder],
    idOverrides: [String: String],
    lastModifiedByRemoteId: [String: String]
  ) async throws -> PushResult {
    pushedReminders.append(contentsOf: reminders)
    return PushResult(synced: reminders.count, skipped: 0)
  }

  func deleteReminder(id: String, lastModified: String?) async throws {
    deletedReminderIds.append((id: id, lastModified: lastModified))
  }

  // MARK: Events

  func pullAllEvents() async throws -> [CalendarEvent] {
    eventsToReturn
  }

  func pushEvents(
    _ events: [CalendarEvent],
    idOverrides: [String: String],
    lastModifiedByRemoteId: [String: String]
  ) async throws -> PushResult {
    pushedEvents.append(contentsOf: events)
    return PushResult(synced: events.count, skipped: 0)
  }

  func deleteEvent(id: String, lastModified: String?) async throws {
    deletedEventIds.append((id: id, lastModified: lastModified))
  }
}

// MARK: - Tests

final class CloudflareListServiceTests: XCTestCase {
  private var mock: MockD1Client!
  private var service: CloudflareListService!

  override func setUp() async throws {
    mock = MockD1Client()
    service = CloudflareListService(client: mock)
  }

  // MARK: - fetchLists

  func testFetchListsReturnsAllLists() async throws {
    let lists = [
      ReminderList(id: "L1", title: "Work", color: "#FF0000", isImmutable: false),
      ReminderList(id: "L2", title: "Personal", color: "#00FF00", isImmutable: false),
      ReminderList(id: "L3", title: "Shopping", color: nil, isImmutable: false),
    ]
    mock.listsToReturn = lists

    let result = try await service.fetchLists()

    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(result[0].title, "Work")
    XCTAssertEqual(result[1].title, "Personal")
    XCTAssertEqual(result[2].title, "Shopping")
  }

  func testFetchListsReturnsEmptyWhenNoLists() async throws {
    mock.listsToReturn = []

    let result = try await service.fetchLists()

    XCTAssertTrue(result.isEmpty)
  }

  // MARK: - createList

  func testCreateListPushesCorrectData() async throws {
    let result = try await service.createList(title: "Shopping", color: "#0000FF")

    XCTAssertEqual(result.title, "Shopping")
    XCTAssertEqual(result.color, "#0000FF")
    XCTAssertFalse(result.isImmutable)
    XCTAssertFalse(result.id.isEmpty, "Created list must have an ID")

    XCTAssertEqual(mock.pushedLists.count, 1)
    XCTAssertEqual(mock.pushedLists[0].title, "Shopping")
    XCTAssertEqual(mock.pushedLists[0].color, "#0000FF")
  }

  func testCreateListWithNilColor() async throws {
    let result = try await service.createList(title: "Plain List", color: nil)

    XCTAssertEqual(result.title, "Plain List")
    XCTAssertNil(result.color)
    XCTAssertEqual(mock.pushedLists.count, 1)
    XCTAssertNil(mock.pushedLists[0].color)
  }

  // MARK: - deleteList

  func testDeleteListCallsClient() async throws {
    try await service.deleteList(id: "L1")

    XCTAssertEqual(mock.deletedListIds.count, 1)
    XCTAssertEqual(mock.deletedListIds[0].id, "L1")
    XCTAssertNotNil(mock.deletedListIds[0].lastModified)
  }

  // MARK: - updateList

  func testUpdateListTitle() async throws {
    let existing = ReminderList(
      id: "L1", title: "Old Title", color: "#FF0000", isImmutable: false
    )
    mock.listsToReturn = [existing]

    let result = try await service.updateList(id: "L1", title: "New Title", color: nil)

    XCTAssertEqual(result.id, "L1")
    XCTAssertEqual(result.title, "New Title")
    XCTAssertEqual(result.color, "#FF0000", "Color should be preserved when not updated")

    XCTAssertEqual(mock.pushedLists.count, 1)
    XCTAssertEqual(mock.pushedLists[0].title, "New Title")
  }

  func testUpdateListColor() async throws {
    let existing = ReminderList(
      id: "L1", title: "My List", color: "#FF0000", isImmutable: false
    )
    mock.listsToReturn = [existing]

    let result = try await service.updateList(id: "L1", title: nil, color: "#00FF00")

    XCTAssertEqual(result.title, "My List", "Title should be preserved when not updated")
    XCTAssertEqual(result.color, "#00FF00")
  }

  func testUpdateListNotFoundThrows() async throws {
    mock.listsToReturn = []

    do {
      _ = try await service.updateList(id: "NONEXISTENT", title: "New", color: nil)
      XCTFail("Expected notFound error")
    } catch let error as EventCLIError {
      if case .notFound = error {
      } else {
        XCTFail("Expected notFound error, got \(error)")
      }
    }
  }

  func testUpdateListPreservesImmutability() async throws {
    let existing = ReminderList(
      id: "L1", title: "Immutable", color: nil, isImmutable: true
    )
    mock.listsToReturn = [existing]

    let result = try await service.updateList(id: "L1", title: "Updated", color: nil)

    XCTAssertTrue(result.isImmutable)
  }
}
