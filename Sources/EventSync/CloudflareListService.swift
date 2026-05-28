import EventModels
import Foundation

// MARK: - Cloudflare List Service

public actor CloudflareListService: ListsBackend {
  private let client: D1Client

  public init(client: D1Client) {
    self.client = client
  }

  public func fetchLists() async throws -> [ReminderList] {
    try await client.pullAllLists()
  }

  public func createList(title: String, color: String?) async throws -> ReminderList {
    let list = ReminderList(
      id: UUID().uuidString,
      title: title,
      color: color,
      isImmutable: false
    )
    _ = try await client.pushLists([list], idOverrides: [:], lastModifiedByRemoteId: [:])
    return list
  }

  public func deleteList(id: String) async throws {
    try await client.deleteList(
      id: id,
      lastModified: ISO8601DateFormatter.eventISO8601.string(from: Date())
    )
  }

  public func updateList(id: String, title: String?, color: String?) async throws -> ReminderList {
    let lists = try await client.pullAllLists()
    guard let existing = lists.first(where: { $0.id == id }) else {
      throw EventCLIError.notFound("List with ID '\(id)' not found")
    }
    let updated = ReminderList(
      id: existing.id,
      title: title ?? existing.title,
      color: color ?? existing.color,
      isImmutable: existing.isImmutable
    )
    _ = try await client.pushLists([updated], idOverrides: [:], lastModifiedByRemoteId: [:])
    return updated
  }
}
