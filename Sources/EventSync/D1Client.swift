import EventModels
import Foundation

// MARK: - D1 Client Protocol

/// Abstraction over `D1SyncClient` that enables mock injection in tests.
/// `D1SyncClient` conforms to this protocol via an unconditional extension.
public protocol D1Client: Sendable {
  // MARK: Reminders

  func pullAllReminders() async throws -> [Reminder]
  func pushReminders(
    _ reminders: [Reminder],
    idOverrides: [String: String],
    lastModifiedByRemoteId: [String: String]
  ) async throws -> PushResult
  func deleteReminder(id: String, lastModified: String?) async throws

  // MARK: Calendar Events

  func pullAllEvents() async throws -> [CalendarEvent]
  func pushEvents(
    _ events: [CalendarEvent],
    idOverrides: [String: String],
    lastModifiedByRemoteId: [String: String]
  ) async throws -> PushResult
  func deleteEvent(id: String, lastModified: String?) async throws

  // MARK: Reminder Lists

  func pullAllLists() async throws -> [ReminderList]
  func pushLists(
    _ lists: [ReminderList],
    idOverrides: [String: String],
    lastModifiedByRemoteId: [String: String]
  ) async throws -> PushResult
  func deleteList(id: String, lastModified: String?) async throws
}
