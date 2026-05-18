import Foundation

// MARK: - Sync Configuration

public struct SyncConfig: Codable, Sendable {
  public let apiURL: String
  public let apiToken: String
  public let deviceId: String

  public init(apiURL: String, apiToken: String, deviceId: String) {
    self.apiURL = apiURL
    self.apiToken = apiToken
    self.deviceId = deviceId
  }
}

// MARK: - Sync Results

public struct PushResult: Codable, Sendable {
  public let synced: Int
  public let skipped: Int

  public init(synced: Int, skipped: Int) {
    self.synced = synced
    self.skipped = skipped
  }
}

public struct PullResponse<T: Codable & Sendable>: Sendable {
  public let items: [PullItem<T>]
  public let cursor: String
  public let hasMore: Bool

  public init(items: [PullItem<T>], cursor: String, hasMore: Bool) {
    self.items = items
    self.cursor = cursor
    self.hasMore = hasMore
  }
}

public struct PullItem<T: Codable & Sendable>: Sendable {
  public let id: String
  public let data: T
  public let deleted: Bool
  public let updatedAt: String
  public let lastModified: String

  public init(id: String, data: T, deleted: Bool, updatedAt: String, lastModified: String) {
    self.id = id
    self.data = data
    self.deleted = deleted
    self.updatedAt = updatedAt
    self.lastModified = lastModified
  }
}

// MARK: - Sync ID Mapping

public struct SyncIdMapping: Codable, Sendable {
  public var reminders: [String: String]
  public var calendarEvents: [String: String]
  public var reminderLists: [String: String]

  public init(
    reminders: [String: String] = [:],
    calendarEvents: [String: String] = [:],
    reminderLists: [String: String] = [:]
  ) {
    self.reminders = reminders
    self.calendarEvents = calendarEvents
    self.reminderLists = reminderLists
  }

  /// A local ID claimed by more than one remote ID while inverting a mapping.
  public struct InversionCollision: Sendable, Equatable {
    public let localId: String
    public let keptRemoteId: String
    public let droppedRemoteId: String

    public init(localId: String, keptRemoteId: String, droppedRemoteId: String) {
      self.localId = localId
      self.keptRemoteId = keptRemoteId
      self.droppedRemoteId = droppedRemoteId
    }
  }

  /// Inverts a remote-to-local map into local-to-remote. When two remote IDs
  /// claim the same local ID, the lexicographically smaller remote ID is kept
  /// (deterministic) and the collision is reported for the caller to surface.
  public static func inverted(
    _ mapping: [String: String]
  ) -> (mapping: [String: String], collisions: [InversionCollision]) {
    var inverted: [String: String] = [:]
    inverted.reserveCapacity(mapping.count)
    var collisions: [InversionCollision] = []
    for (remote, local) in mapping.sorted(by: { $0.key < $1.key }) {
      if let existing = inverted[local] {
        collisions.append(
          InversionCollision(localId: local, keptRemoteId: existing, droppedRemoteId: remote))
      } else {
        inverted[local] = remote
      }
    }
    return (inverted, collisions)
  }
}

// MARK: - Sync Cursors

public struct SyncCursors: Codable, Sendable {
  public var reminders: String?
  public var calendarEvents: String?
  public var reminderLists: String?

  public init(reminders: String? = nil, calendarEvents: String? = nil, reminderLists: String? = nil)
  {
    self.reminders = reminders
    self.calendarEvents = calendarEvents
    self.reminderLists = reminderLists
  }
}

// MARK: - Sync Date Range

public struct SyncDateRange: Codable, Sendable, Equatable {
  public let start: String
  public let end: String

  public init(start: String, end: String) {
    self.start = start
    self.end = end
  }

  public func overlaps(_ other: SyncDateRange) -> Bool {
    start <= other.end && end >= other.start
  }
}

// MARK: - Sync State

public struct SyncEntityState: Codable, Sendable, Equatable {
  public var knownRemoteIds: Set<String>
  public var lastModifiedByRemoteId: [String: String]
  public var snapshotsByRemoteId: [String: String]
  public var dateRangeByRemoteId: [String: SyncDateRange]

  public init(
    knownRemoteIds: Set<String> = [],
    lastModifiedByRemoteId: [String: String] = [:],
    snapshotsByRemoteId: [String: String] = [:],
    dateRangeByRemoteId: [String: SyncDateRange] = [:]
  ) {
    self.knownRemoteIds = knownRemoteIds
    self.lastModifiedByRemoteId = lastModifiedByRemoteId
    self.snapshotsByRemoteId = snapshotsByRemoteId
    self.dateRangeByRemoteId = dateRangeByRemoteId
  }

  public func deletionCandidates(currentRemoteIds: Set<String>) -> [String] {
    knownRemoteIds.subtracting(currentRemoteIds).sorted()
  }

  public func deletionCandidates(
    currentRemoteIds: Set<String>,
    withinRange range: SyncDateRange
  ) -> [String] {
    knownRemoteIds.subtracting(currentRemoteIds).filter { id in
      guard let stored = dateRangeByRemoteId[id] else { return true }
      return stored.overlaps(range)
    }.sorted()
  }

  public func lastModified<T: Encodable>(
    for value: T,
    remoteId: String,
    fallback: String
  ) throws -> String {
    let snapshot = try SyncSnapshotEncoder.encode(value)
    guard snapshotsByRemoteId[remoteId] == snapshot,
      let existingLastModified = lastModifiedByRemoteId[remoteId]
    else {
      return fallback
    }
    return existingLastModified
  }

  public mutating func recordKnownRemoteId(_ remoteId: String) {
    knownRemoteIds.insert(remoteId)
  }

  public mutating func removeRemoteId(_ remoteId: String) {
    knownRemoteIds.remove(remoteId)
    lastModifiedByRemoteId.removeValue(forKey: remoteId)
    snapshotsByRemoteId.removeValue(forKey: remoteId)
    dateRangeByRemoteId.removeValue(forKey: remoteId)
  }

  public mutating func recordDateRange(_ range: SyncDateRange, for remoteId: String) {
    dateRangeByRemoteId[remoteId] = range
  }

  public mutating func recordSyncedValue<T: Encodable>(
    _ value: T,
    remoteId: String,
    lastModified: String
  ) throws {
    recordKnownRemoteId(remoteId)
    lastModifiedByRemoteId[remoteId] = lastModified
    snapshotsByRemoteId[remoteId] = try SyncSnapshotEncoder.encode(value)
  }
}

public struct SyncState: Codable, Sendable, Equatable {
  public var reminders: SyncEntityState
  public var calendarEvents: SyncEntityState
  public var reminderLists: SyncEntityState

  public init(
    reminders: SyncEntityState = SyncEntityState(),
    calendarEvents: SyncEntityState = SyncEntityState(),
    reminderLists: SyncEntityState = SyncEntityState()
  ) {
    self.reminders = reminders
    self.calendarEvents = calendarEvents
    self.reminderLists = reminderLists
  }
}

enum SyncSnapshotEncoder {
  static func encode<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }
}
