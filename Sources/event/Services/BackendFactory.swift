import EventModels
import EventSync
import Foundation

// MARK: - Backend Factory

/// Creates the appropriate backend services for the current platform.
/// On macOS, returns EventKit-backed services for local Apple data.
/// On Linux (or when EventKit is unavailable), returns Cloudflare D1-backed services.
enum BackendFactory {
  static func makeRemindersBackend() async throws -> any RemindersBackend {
    #if canImport(EventKit)
      return ReminderService()
    #else
      let config = try CloudflareConfig.load()
      let client = D1SyncClient(config: config.toSyncConfig())
      let encryption = EncryptionService(key: try EncryptionService.keyFromEnvironment())
      return CloudflareReminderService(client: client, encryption: encryption)
    #endif
  }

  static func makeCalendarBackend() async throws -> any CalendarBackend {
    #if canImport(EventKit)
      return CalendarService()
    #else
      let config = try CloudflareConfig.load()
      let client = D1SyncClient(config: config.toSyncConfig())
      let encryption = EncryptionService(key: try EncryptionService.keyFromEnvironment())
      return CloudflareCalendarService(client: client, encryption: encryption)
    #endif
  }

  static func makeListsBackend() async throws -> any ListsBackend {
    #if canImport(EventKit)
      return ListService()
    #else
      let config = try CloudflareConfig.load()
      let client = D1SyncClient(config: config.toSyncConfig())
      return CloudflareListService(client: client)
    #endif
  }

  #if canImport(EventKit)
    /// macOS-only: creates a SyncService for bidirectional push/pull.
    static func makeSyncService() async throws -> SyncService {
      let config = try SyncConfigStore.load()
      return SyncService(config: config)
    }
  #endif
}
