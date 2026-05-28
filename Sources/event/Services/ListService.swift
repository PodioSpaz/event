#if canImport(EventKit)

  import EventKit
  import EventModels
  import Foundation

  // MARK: - List Service

  actor ListService {
    private let eventStore = EKEventStore()
    private let permissionService = PermissionService()

    /// Fetch all reminder lists
    func fetchLists() async throws -> [ReminderList] {
      try await permissionService.ensureRemindersAccess()

      let calendars = eventStore.calendars(for: .reminder)
      return calendars.map { ReminderList(from: $0) }
    }

    /// Create a new reminder list
    func createList(name: String) async throws -> ReminderList {
      try await permissionService.ensureRemindersAccess()

      let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
      calendar.title = name

      // Find a source that actually supports reminders (has existing reminder calendars)
      let existingReminderCalendars = eventStore.calendars(for: .reminder)
      let validSources = Set(existingReminderCalendars.map { $0.source })

      guard let source = validSources.first else {
        throw EventCLIError.eventKitError("No suitable source found for creating reminder list")
      }
      calendar.source = source

      try eventStore.saveCalendar(calendar, commit: true)
      return ReminderList(from: calendar)
    }

    /// Update a reminder list
    func updateList(id: String, name: String) async throws -> ReminderList {
      try await permissionService.ensureRemindersAccess()

      guard let calendar = eventStore.calendar(withIdentifier: id) else {
        throw EventCLIError.notFound("List with ID '\(id)' not found")
      }

      if calendar.isImmutable {
        throw EventCLIError.invalidInput("Cannot modify system list '\(calendar.title)'")
      }

      calendar.title = name
      try eventStore.saveCalendar(calendar, commit: true)
      return ReminderList(from: calendar)
    }

    /// Delete a reminder list
    func deleteList(id: String) async throws {
      try await permissionService.ensureRemindersAccess()

      guard let calendar = eventStore.calendar(withIdentifier: id) else {
        throw EventCLIError.notFound("List with ID '\(id)' not found")
      }

      if calendar.isImmutable {
        throw EventCLIError.invalidInput("Cannot delete system list '\(calendar.title)'")
      }

      try eventStore.removeCalendar(calendar, commit: true)
    }
  }

  // MARK: - ListsBackend Conformance

  extension ListService: ListsBackend {
    func createList(title: String, color: String?) async throws -> ReminderList {
      // EventKit does not expose a color setter for reminder calendars;
      // the color parameter is accepted but ignored on macOS.
      try await createList(name: title)
    }

    func updateList(id: String, title: String?, color: String?) async throws -> ReminderList {
      guard let title else {
        throw EventCLIError.invalidInput("title is required to update a list")
      }
      return try await updateList(id: id, name: title)
    }
  }

#endif
