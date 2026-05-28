import EventModels
import Foundation
import SQLite

// MARK: - Linux Sync Service

/// Sync service for non-EventKit platforms (Linux, etc.) that uses SQLite as the
/// local data store. Mirrors the macOS `SyncService` pattern but operates on
/// SQLite.swift records instead of EventKit entities.
public actor LinuxSyncService: SyncServiceProtocol {
  private let connection: Connection
  private let syncClient: D1SyncClient

  public init(config: SyncConfig, database: SQLiteDatabase) {
    self.connection = database.databaseConnection
    self.syncClient = D1SyncClient(config: config)
  }

  public func shutdown() async throws {
    try await syncClient.shutdown()
  }

  // MARK: - Push

  public func pushReminders() async throws -> PushResult {
    let allItems: [Reminder] = try await fetchNonDeleted(from: "reminders")
    let localOnlyItems: [Reminder] = try await fetchLocalOnly(from: "reminders")
    let deletedRecords = try await fetchDeletedRecords(from: "reminders")

    return try await pushEntities(
      allItems: allItems,
      localOnlyItems: localOnlyItems,
      deletedRecords: deletedRecords,
      getId: { $0.id },
      getMapping: { $0.reminders },
      removeMapping: { $0.reminders.removeValue(forKey: $1) },
      getEntityState: { $0.reminders },
      setEntityState: { $0.reminders = $1 },
      deletionCandidates: { $0.deletionCandidates(currentRemoteIds: $1) },
      push: {
        try await self.syncClient.pushReminders(
          $0, idOverrides: $1, lastModifiedByRemoteId: $2)
      },
      delete: { try await self.syncClient.deleteReminder(id: $0, lastModified: $1) },
      tableName: "reminders"
    )
  }

  public func pushEvents() async throws -> PushResult {
    let allItems: [CalendarEvent] = try await fetchNonDeleted(from: "calendar_events")
    let localOnlyItems: [CalendarEvent] = try await fetchLocalOnly(from: "calendar_events")
    let deletedRecords = try await fetchDeletedRecords(from: "calendar_events")

    return try await pushEntities(
      allItems: allItems,
      localOnlyItems: localOnlyItems,
      deletedRecords: deletedRecords,
      getId: { $0.id },
      getMapping: { $0.calendarEvents },
      removeMapping: { $0.calendarEvents.removeValue(forKey: $1) },
      getEntityState: { $0.calendarEvents },
      setEntityState: { $0.calendarEvents = $1 },
      deletionCandidates: { $0.deletionCandidates(currentRemoteIds: $1) },
      push: {
        try await self.syncClient.pushEvents(
          $0, idOverrides: $1, lastModifiedByRemoteId: $2)
      },
      recordExtra: { entityState, event, remoteId in
        entityState.recordDateRange(
          SyncDateRange(start: event.startDate, end: event.endDate), for: remoteId)
      },
      delete: { try await self.syncClient.deleteEvent(id: $0, lastModified: $1) },
      tableName: "calendar_events"
    )
  }

  public func pushLists() async throws -> PushResult {
    let allItems: [ReminderList] = try await fetchNonDeleted(from: "reminder_lists")
    let localOnlyItems: [ReminderList] = try await fetchLocalOnly(from: "reminder_lists")
    let deletedRecords = try await fetchDeletedRecords(from: "reminder_lists")

    return try await pushEntities(
      allItems: allItems,
      localOnlyItems: localOnlyItems,
      deletedRecords: deletedRecords,
      getId: { $0.id },
      getMapping: { $0.reminderLists },
      removeMapping: { $0.reminderLists.removeValue(forKey: $1) },
      getEntityState: { $0.reminderLists },
      setEntityState: { $0.reminderLists = $1 },
      deletionCandidates: { $0.deletionCandidates(currentRemoteIds: $1) },
      push: {
        try await self.syncClient.pushLists(
          $0, idOverrides: $1, lastModifiedByRemoteId: $2)
      },
      delete: { try await self.syncClient.deleteList(id: $0, lastModified: $1) },
      tableName: "reminder_lists"
    )
  }

  // MARK: - Generic Push

  /// Pushes locally modified items, records their synced state, then soft-deletes
  /// remote IDs no longer present locally. The `is_local_only` flag replaces the
  /// snapshot comparison used by the macOS SyncService: items flagged as local-only
  /// are always pushed. Deletions are driven by the `deleted` column plus the
  /// state-based `deletionCandidates` safety net.
  private func pushEntities<E: Encodable & Sendable>(
    allItems: [E],
    localOnlyItems: [E],
    deletedRecords: [DeletedRecord],
    getId: (E) -> String,
    getMapping: (SyncIdMapping) -> [String: String],
    removeMapping: (inout SyncIdMapping, String) -> Void,
    getEntityState: (SyncState) -> SyncEntityState,
    setEntityState: (inout SyncState, SyncEntityState) -> Void,
    deletionCandidates: (SyncEntityState, Set<String>) -> [String],
    push: ([E], [String: String], [String: String]) async throws -> PushResult,
    recordExtra: ((inout SyncEntityState, E, String) -> Void)? = nil,
    delete: (String, String?) async throws -> Void,
    tableName: String
  ) async throws -> PushResult {
    // Dedup all items
    var seenIds = Set<String>()
    var uniqueItems = [E]()
    for item in allItems {
      let id = getId(item)
      if !seenIds.contains(id) {
        seenIds.insert(id)
        uniqueItems.append(item)
      }
    }

    // Dedup local-only items
    var localOnlySeen = Set<String>()
    var uniqueLocalOnly = [E]()
    for item in localOnlyItems {
      let id = getId(item)
      if !localOnlySeen.contains(id) {
        localOnlySeen.insert(id)
        uniqueLocalOnly.append(item)
      }
    }

    var idMapping = try SyncConfigStore.loadIdMapping()
    var state = try SyncConfigStore.loadState()
    var entityState = getEntityState(state)
    let localToRemote = invertMapping(getMapping(idMapping))

    // Current remote IDs from all non-deleted items
    let currentRemoteIds = SyncPushHelpers.currentRemoteIds(
      items: uniqueItems,
      getId: getId,
      localToRemote: localToRemote
    )

    // Deletion candidates: state-based safety net plus explicit soft-deletes
    var deletedRemoteIds = deletionCandidates(entityState, currentRemoteIds)
    // Add explicitly deleted records
    for record in deletedRecords {
      let remoteId = localToRemote[record.id] ?? record.id
      if !deletedRemoteIds.contains(remoteId) {
        deletedRemoteIds.append(remoteId)
      }
    }

    // Build lastModified map for items to push
    let fallbackLastModified = ISO8601DateFormatter.eventISO8601.string(from: Date())
    var lastModifiedByRemoteId = [String: String]()
    for item in uniqueLocalOnly {
      let remoteId = localToRemote[getId(item)] ?? getId(item)
      lastModifiedByRemoteId[remoteId] = fallbackLastModified
    }

    // Push local-only items
    let result = try await push(uniqueLocalOnly, localToRemote, lastModifiedByRemoteId)

    // Record synced state and clear is_local_only flag
    for item in uniqueLocalOnly {
      let remoteId = localToRemote[getId(item)] ?? getId(item)
      if let lastModified = lastModifiedByRemoteId[remoteId] {
        try entityState.recordSyncedValue(
          item, remoteId: remoteId, lastModified: lastModified)
      }
      recordExtra?(&entityState, item, remoteId)
    }
    setEntityState(&state, entityState)
    try SyncConfigStore.saveState(state)

    // Clear is_local_only for pushed items
    let pushedLocalIds = uniqueLocalOnly.map { getId($0) }
    if !pushedLocalIds.isEmpty {
      try await clearLocalOnly(table: tableName, ids: pushedLocalIds)
    }

    guard !deletedRemoteIds.isEmpty else { return result }

    // Process deletions
    for remoteId in deletedRemoteIds {
      try await delete(remoteId, entityState.lastModifiedByRemoteId[remoteId])
      let localId = getMapping(idMapping)[remoteId] ?? remoteId
      removeMapping(&idMapping, remoteId)
      entityState.removeRemoteId(remoteId)
      setEntityState(&state, entityState)
      try SyncConfigStore.saveIdMapping(idMapping)
      try SyncConfigStore.saveState(state)
      // Hard-delete the local record if it exists
      try await removeRecord(table: tableName, id: localId)
    }

    return result
  }

  // MARK: - Pull

  public func pullReminders() async throws -> PullSummary {
    let localReminders: [Reminder] = try await fetchNonDeleted(from: "reminders")
    let localLastModified = lastModifiedIndex(
      localReminders.map {
        (id: $0.id, lastModified: $0.lastModifiedDate, creationDate: $0.creationDate)
      })
    let localIds = Set(localReminders.map(\.id))

    return try await pullEntities(
      entityName: "reminders",
      tableName: "reminders",
      localLastModifiedById: localLastModified,
      localIdsWithoutTimestamp: localIds.subtracting(Set(localLastModified.keys)),
      pull: { cursor in try await self.syncClient.pullReminders(cursor: cursor) },
      getCursor: { $0.reminders },
      setCursor: { $0.reminders = $1 },
      getMapping: { $0.reminders },
      setMapping: { mapping, key, value in
        if let value {
          mapping.reminders[key] = value
        } else {
          mapping.reminders.removeValue(forKey: key)
        }
      },
      getEntityState: { $0.reminders },
      setEntityState: { $0.reminders = $1 }
    )
  }

  public func pullEvents() async throws -> PullSummary {
    let localEvents: [CalendarEvent] = try await fetchNonDeleted(from: "calendar_events")
    let localLastModified = lastModifiedIndex(
      localEvents.map {
        (id: $0.id, lastModified: $0.lastModifiedDate, creationDate: $0.creationDate)
      })
    let localIds = Set(localEvents.map(\.id))

    return try await pullEntities(
      entityName: "calendar events",
      tableName: "calendar_events",
      localLastModifiedById: localLastModified,
      localIdsWithoutTimestamp: localIds.subtracting(Set(localLastModified.keys)),
      pull: { cursor in try await self.syncClient.pullEvents(cursor: cursor) },
      getCursor: { $0.calendarEvents },
      setCursor: { $0.calendarEvents = $1 },
      getMapping: { $0.calendarEvents },
      setMapping: { mapping, key, value in
        if let value {
          mapping.calendarEvents[key] = value
        } else {
          mapping.calendarEvents.removeValue(forKey: key)
        }
      },
      getEntityState: { $0.calendarEvents },
      setEntityState: { $0.calendarEvents = $1 },
      recordExtra: { entityState, item in
        entityState.recordDateRange(
          SyncDateRange(start: item.data.startDate, end: item.data.endDate),
          for: item.id
        )
      }
    )
  }

  public func pullLists() async throws -> PullSummary {
    // Reminder lists carry no modification timestamp, so the pull always
    // applies the server value (an empty conflict index disables the guard).
    try await pullEntities(
      entityName: "reminder lists",
      tableName: "reminder_lists",
      localLastModifiedById: [:],
      localIdsWithoutTimestamp: [],
      pull: { cursor in try await self.syncClient.pullLists(cursor: cursor) },
      getCursor: { $0.reminderLists },
      setCursor: { $0.reminderLists = $1 },
      getMapping: { $0.reminderLists },
      setMapping: { mapping, key, value in
        if let value {
          mapping.reminderLists[key] = value
        } else {
          mapping.reminderLists.removeValue(forKey: key)
        }
      },
      getEntityState: { $0.reminderLists },
      setEntityState: { $0.reminderLists = $1 }
    )
  }

  // MARK: - Generic Pull Loop

  private func pullEntities<T: Codable & Sendable>(
    entityName: String,
    tableName: String,
    localLastModifiedById: [String: String],
    localIdsWithoutTimestamp: Set<String>,
    pull: (String?) async throws -> PullResponse<T>,
    getCursor: (SyncCursors) -> String?,
    setCursor: (inout SyncCursors, String?) -> Void,
    getMapping: (SyncIdMapping) -> [String: String],
    setMapping: (inout SyncIdMapping, String, String?) -> Void,
    getEntityState: (SyncState) -> SyncEntityState,
    setEntityState: (inout SyncState, SyncEntityState) -> Void,
    recordExtra: ((inout SyncEntityState, PullItem<T>) -> Void)? = nil
  ) async throws -> PullSummary {
    var cursors = SyncConfigStore.loadCursors()
    var idMapping = try SyncConfigStore.loadIdMapping()
    var state = try SyncConfigStore.loadState()
    var entityState = getEntityState(state)
    var pulled = 0
    var deleted = 0
    var skipped = 0
    var hasMore = true

    func persist() throws {
      setEntityState(&state, entityState)
      try SyncConfigStore.saveCursors(cursors)
      try SyncConfigStore.saveIdMapping(idMapping)
      try SyncConfigStore.saveState(state)
    }

    while hasMore {
      let response: PullResponse<T>
      do {
        response = try await pull(getCursor(cursors))
      } catch {
        // Persist progress from earlier pages so created items keep their ID
        // mapping; otherwise a retry would create duplicate local entities.
        try? persist()
        throw error
      }
      hasMore = response.hasMore
      var hadFailures = false

      for item in response.items {
        let localId = getMapping(idMapping)[item.id] ?? item.id

        if item.deleted {
          do {
            try await hardDeleteRecord(table: tableName, id: localId)
          } catch let error as EventCLIError where isNotFoundError(error) {
            // Already gone locally, clean up mapping
          } catch {
            fputs(
              "Warning: Could not delete \(entityName) \(item.id): \(error)\n", stderr)
            hadFailures = true
            continue
          }
          setMapping(&idMapping, item.id, nil)
          entityState.removeRemoteId(item.id)
          deleted += 1
          continue
        }

        // Conflict guard: never overwrite a local copy that was modified more
        // recently than the server's version -- it is pushed on the next sync.
        if localIdsWithoutTimestamp.contains(localId) {
          fputs(
            "Skipped \(entityName) \(item.id): local copy has no timestamp for conflict comparison\n",
            stderr)
          skipped += 1
          continue
        }

        if let localValue = localLastModifiedById[localId],
          let localModified = SyncTimestamp.parse(localValue),
          let serverModified = SyncTimestamp.parse(item.lastModified),
          localModified > serverModified
        {
          fputs(
            "Skipped \(entityName) \(item.id): local copy is newer; it will be pushed on next sync\n",
            stderr)
          skipped += 1
          continue
        }

        do {
          try await upsertRecord(
            table: tableName,
            id: localId,
            data: item.data,
            lastModified: item.lastModified
          )
          // If this was a new record (localId was the remote ID and no mapping
          // existed), record the mapping.
          if getMapping(idMapping)[item.id] == nil {
            setMapping(&idMapping, item.id, localId)
          }
          try entityState.recordSyncedValue(
            item.data,
            remoteId: item.id,
            lastModified: item.lastModified
          )
          recordExtra?(&entityState, item)
          pulled += 1
        } catch {
          fputs(
            "Warning: Could not sync \(entityName) \(item.id): \(error)\n", stderr)
          hadFailures = true
        }
      }

      setCursor(
        &cursors,
        SyncCursorPolicy.nextCursor(
          currentCursor: getCursor(cursors),
          responseCursor: response.cursor,
          hadFailures: hadFailures
        )
      )
      // Persist after every page so a later network failure cannot strand
      // already-applied items without their ID mapping.
      try persist()

      if hadFailures {
        throw EventCLIError.unknown(
          "Pull \(entityName) failed for one or more items. Cursor was not advanced."
        )
      }
    }

    return PullSummary(pulled: pulled, deleted: deleted, skipped: skipped)
  }

  // MARK: - SQLite Fetch Helpers

  /// Fetches all non-deleted records from a table and decodes them as `T`.
  private func fetchNonDeleted<T: Codable>(from table: String) async throws -> [T] {
    let sql = "SELECT data FROM \(table) WHERE deleted = 0"
    return try connection.prepare(sql).map { row in
      try Self.decode(T.self, from: row[0], table: table)
    }
  }

  /// Fetches records with `is_local_only=1` and `deleted=0`, decoded as `T`.
  private func fetchLocalOnly<T: Codable>(from table: String) async throws -> [T] {
    let sql = "SELECT data FROM \(table) WHERE is_local_only = 1 AND deleted = 0"
    return try connection.prepare(sql).map { row in
      try Self.decode(T.self, from: row[0], table: table)
    }
  }

  /// Fetches the ID and last_modified of soft-deleted records.
  private func fetchDeletedRecords(from table: String) async throws -> [DeletedRecord] {
    let sql = "SELECT id, last_modified FROM \(table) WHERE deleted = 1"
    return try connection.prepare(sql).map { row in
      DeletedRecord(id: row[0] as! String, lastModified: row[1] as! String)
    }
  }

  /// Decodes a JSON string `Binding?` from a column into a `Codable` value.
  private static func decode<T: Codable>(
    _ type: T.Type, from value: Binding?, table: String
  ) throws -> T {
    guard let jsonString = value as? String,
      let jsonData = jsonString.data(using: .utf8)
    else {
      throw EventCLIError.unknown("Failed to decode record data from \(table)")
    }
    return try JSONDecoder().decode(T.self, from: jsonData)
  }

  // MARK: - SQLite Write Helpers

  /// Clears the `is_local_only` flag for the given local IDs.
  private func clearLocalOnly(table: String, ids: [String]) async throws {
    guard !ids.isEmpty else { return }
    let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
    let sql = "UPDATE \(table) SET is_local_only = 0 WHERE id IN (\(placeholders))"
    try connection.run(sql, ids.map { $0 as Binding? })
  }

  /// Hard-deletes a single record by ID. Throws `notFound` if no record exists.
  private func removeRecord(table: String, id: String) async throws {
    try connection.run("DELETE FROM \(table) WHERE id = ?", id)
    if connection.changes == 0 {
      throw EventCLIError.notFound("Record with ID '\(id)' not found in \(table)")
    }
  }

  /// Hard-deletes a single record by ID. Silently succeeds if no record exists.
  private func hardDeleteRecord(table: String, id: String) async throws {
    try connection.run("DELETE FROM \(table) WHERE id = ?", id)
  }

  /// Upserts a record: inserts if the ID does not exist, updates if it does.
  /// Sets `is_local_only=0` and `deleted=0` since the data came from the server.
  private func upsertRecord<T: Encodable>(
    table: String,
    id: String,
    data: T,
    lastModified: String
  ) async throws {
    let jsonData = try JSONEncoder().encode(data)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw EventCLIError.unknown("Failed to encode record data for \(table)")
    }

    let sql = """
      INSERT INTO \(table) (id, data, last_modified, deleted, is_local_only)
      VALUES (?, ?, ?, 0, 0)
      ON CONFLICT(id) DO UPDATE SET
        data = excluded.data,
        last_modified = excluded.last_modified,
        deleted = 0,
        is_local_only = 0,
        updated_at = datetime('now')
      """
    try connection.run(sql, id, jsonString, lastModified)
  }

  // MARK: - Helpers

  /// Builds a `localId -> lastModified` index, preferring modification time and
  /// falling back to creation time when the service omits last-modified metadata.
  private nonisolated func lastModifiedIndex(
    _ pairs: [(id: String, lastModified: String?, creationDate: String?)]
  ) -> [String: String] {
    var index: [String: String] = [:]
    for pair in pairs {
      if let lastModified = pair.lastModified {
        index[pair.id] = lastModified
      } else if let creationDate = pair.creationDate {
        index[pair.id] = creationDate
      }
    }
    return index
  }

  private nonisolated func isNotFoundError(_ error: EventCLIError) -> Bool {
    if case .notFound = error {
      return true
    }
    return false
  }

  private nonisolated func invertMapping(_ mapping: [String: String]) -> [String: String] {
    let result = SyncIdMapping.inverted(mapping)
    for collision in result.collisions {
      fputs(
        "Warning: duplicate ID mapping -- local '\(collision.localId)' maps to both "
          + "'\(collision.keptRemoteId)' and '\(collision.droppedRemoteId)'\n",
        stderr)
    }
    return result.mapping
  }
}

// MARK: - Deleted Record

private struct DeletedRecord: Sendable {
  let id: String
  let lastModified: String
}
