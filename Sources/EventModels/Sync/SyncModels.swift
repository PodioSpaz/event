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

  public init(id: String, data: T, deleted: Bool, updatedAt: String) {
    self.id = id
    self.data = data
    self.deleted = deleted
    self.updatedAt = updatedAt
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
