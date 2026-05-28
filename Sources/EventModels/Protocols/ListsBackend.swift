import Foundation

// MARK: - Lists Backend Protocol

public protocol ListsBackend: Sendable {
  func fetchLists() async throws -> [ReminderList]
  func createList(title: String, color: String?) async throws -> ReminderList
  func deleteList(id: String) async throws
  func updateList(id: String, title: String?, color: String?) async throws -> ReminderList
}
