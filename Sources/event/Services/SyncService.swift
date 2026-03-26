import EventCommands
import EventKit
import EventModels
import Foundation

// MARK: - Sync Service

actor SyncService {
  private let reminderService = ReminderService()
  private let calendarService = CalendarService()
  private let listService = ListService()
  private let syncClient: D1SyncClient

  init(config: SyncConfig) {
    self.syncClient = D1SyncClient(config: config)
  }

  // MARK: - Push

  func pushReminders() async throws -> PushResult {
    let reminders = try await reminderService.fetchReminders(showCompleted: true)
    let idMapping = SyncConfigStore.loadIdMapping()
    let localToRemote = Dictionary(
      idMapping.reminders.map { ($0.value, $0.key) },
      uniquingKeysWith: { first, _ in first }
    )
    return try await syncClient.pushReminders(reminders, idOverrides: localToRemote)
  }

  func pushEvents() async throws -> PushResult {
    let start = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    let end = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let events = try await calendarService.fetchEvents(
      startDate: formatter.string(from: start),
      endDate: formatter.string(from: end)
    )
    let idMapping = SyncConfigStore.loadIdMapping()
    let localToRemote = Dictionary(
      idMapping.calendarEvents.map { ($0.value, $0.key) },
      uniquingKeysWith: { first, _ in first }
    )
    return try await syncClient.pushEvents(events, idOverrides: localToRemote)
  }

  func pushLists() async throws -> PushResult {
    let lists = try await listService.fetchLists()
    let idMapping = SyncConfigStore.loadIdMapping()
    let localToRemote = Dictionary(
      idMapping.reminderLists.map { ($0.value, $0.key) },
      uniquingKeysWith: { first, _ in first }
    )
    return try await syncClient.pushLists(lists, idOverrides: localToRemote)
  }

  // MARK: - Pull

  func pullReminders() async throws -> PullSummary {
    var cursors = SyncConfigStore.loadCursors()
    var idMapping = SyncConfigStore.loadIdMapping()
    var pulled = 0
    var deleted = 0
    var hasMore = true

    while hasMore {
      let response = try await syncClient.pullReminders(cursor: cursors.reminders)
      hasMore = response.hasMore

      for item in response.items {
        let localId = idMapping.reminders[item.id] ?? item.id

        if item.deleted {
          do {
            try await reminderService.deleteReminder(id: localId)
            idMapping.reminders.removeValue(forKey: item.id)
            deleted += 1
          } catch {
            print("Warning: Could not delete reminder \(item.id): \(error)")
          }
        } else {
          do {
            _ = try await reminderService.updateReminder(
              id: localId,
              title: item.data.title,
              completed: item.data.isCompleted,
              notes: item.data.notes,
              dueDate: item.data.dueDate,
              startDate: item.data.startDate,
              priority: item.data.priority,
              useShortcuts: false
            )
            pulled += 1
          } catch {
            do {
              let created = try await reminderService.createReminder(
                title: item.data.title,
                listName: item.data.list,
                notes: item.data.notes,
                dueDate: item.data.dueDate,
                priority: item.data.priority,
                useShortcuts: false
              )
              idMapping.reminders[item.id] = created.id
              pulled += 1
            } catch {
              print("Warning: Could not sync reminder \(item.id): \(error)")
            }
          }
        }
      }

      cursors.reminders = response.cursor
    }

    try SyncConfigStore.saveCursors(cursors)
    try SyncConfigStore.saveIdMapping(idMapping)
    return PullSummary(pulled: pulled, deleted: deleted)
  }

  func pullEvents() async throws -> PullSummary {
    var cursors = SyncConfigStore.loadCursors()
    var idMapping = SyncConfigStore.loadIdMapping()
    var pulled = 0
    var deleted = 0
    var hasMore = true

    while hasMore {
      let response = try await syncClient.pullEvents(cursor: cursors.calendarEvents)
      hasMore = response.hasMore

      for item in response.items {
        let localId = idMapping.calendarEvents[item.id] ?? item.id

        if item.deleted {
          do {
            try await calendarService.deleteEvent(id: localId)
            idMapping.calendarEvents.removeValue(forKey: item.id)
            deleted += 1
          } catch {
            print("Warning: Could not delete event \(item.id): \(error)")
          }
        } else {
          do {
            _ = try await calendarService.updateEvent(
              id: localId,
              title: item.data.title,
              startDate: item.data.startDate,
              endDate: item.data.endDate,
              location: item.data.location,
              notes: item.data.notes
            )
            pulled += 1
          } catch {
            do {
              let created = try await calendarService.createEvent(
                title: item.data.title,
                startDate: item.data.startDate,
                endDate: item.data.endDate,
                location: item.data.location,
                notes: item.data.notes
              )
              idMapping.calendarEvents[item.id] = created.id
              pulled += 1
            } catch {
              print("Warning: Could not sync event \(item.id): \(error)")
            }
          }
        }
      }

      cursors.calendarEvents = response.cursor
    }

    try SyncConfigStore.saveCursors(cursors)
    try SyncConfigStore.saveIdMapping(idMapping)
    return PullSummary(pulled: pulled, deleted: deleted)
  }

  func pullLists() async throws -> PullSummary {
    var cursors = SyncConfigStore.loadCursors()
    var idMapping = SyncConfigStore.loadIdMapping()
    var pulled = 0
    var deleted = 0
    var hasMore = true

    while hasMore {
      let response = try await syncClient.pullLists(cursor: cursors.reminderLists)
      hasMore = response.hasMore

      for item in response.items {
        let localId = idMapping.reminderLists[item.id] ?? item.id

        if item.deleted {
          do {
            try await listService.deleteList(id: localId)
            idMapping.reminderLists.removeValue(forKey: item.id)
            deleted += 1
          } catch {
            print("Warning: Could not delete list \(item.id): \(error)")
          }
        } else {
          do {
            _ = try await listService.updateList(id: localId, name: item.data.title)
            pulled += 1
          } catch {
            do {
              let created = try await listService.createList(name: item.data.title)
              idMapping.reminderLists[item.id] = created.id
              pulled += 1
            } catch {
              print("Warning: Could not sync list \(item.id): \(error)")
            }
          }
        }
      }

      cursors.reminderLists = response.cursor
    }

    try SyncConfigStore.saveCursors(cursors)
    try SyncConfigStore.saveIdMapping(idMapping)
    return PullSummary(pulled: pulled, deleted: deleted)
  }
}
