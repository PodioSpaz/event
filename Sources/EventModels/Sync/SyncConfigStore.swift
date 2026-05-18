import Foundation

// MARK: - Sync Config Store

public enum SyncConfigStore {
  private static var baseDirectory: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config")
      .appendingPathComponent("event-sync")
  }

  /// Acquire an exclusive, non-blocking file lock to prevent concurrent sync operations.
  /// Returns the file descriptor. Call `releaseLock(_:)` when done.
  public static func acquireLock() throws -> Int32 {
    let dir = baseDirectory
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let lockPath = dir.appendingPathComponent(".lock").path
    let fd = open(lockPath, O_CREAT | O_RDWR, 0o600)
    guard fd >= 0 else {
      throw EventCLIError.unknown("Could not create sync lock file")
    }
    guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
      close(fd)
      throw EventCLIError.unknown("Another sync operation is already running")
    }
    return fd
  }

  public static func releaseLock(_ fd: Int32) {
    flock(fd, LOCK_UN)
    close(fd)
  }

  public static var configPath: String {
    baseDirectory.appendingPathComponent("config.json").path
  }

  public static var cursorsPath: String {
    baseDirectory.appendingPathComponent("cursors.json").path
  }

  public static var idMappingPath: String {
    baseDirectory.appendingPathComponent("id-mapping.json").path
  }

  public static var statePath: String {
    baseDirectory.appendingPathComponent("state.json").path
  }

  // MARK: - Config

  public static func load() throws -> SyncConfig {
    guard FileManager.default.fileExists(atPath: configPath) else {
      throw EventCLIError.notFound(
        "Sync config not found. Run 'event sync config --api-url <URL> --api-token <TOKEN> --device-id <ID>' first."
      )
    }
    let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
    return try JSONDecoder().decode(SyncConfig.self, from: data)
  }

  public static func save(_ config: SyncConfig) throws {
    guard config.apiURL.lowercased().hasPrefix("https://") else {
      throw EventCLIError.invalidInput(
        "API URL must use HTTPS. Got: \(config.apiURL)"
      )
    }
    try saveJSON(config, to: configPath)
  }

  // MARK: - Cursors

  public static func loadCursors() -> SyncCursors {
    loadJSON(from: cursorsPath, default: SyncCursors())
  }

  public static func saveCursors(_ cursors: SyncCursors) throws {
    try saveJSON(cursors, to: cursorsPath)
  }

  // MARK: - ID Mapping

  public static func loadIdMapping() -> SyncIdMapping {
    loadJSON(from: idMappingPath, default: SyncIdMapping())
  }

  public static func saveIdMapping(_ mapping: SyncIdMapping) throws {
    try saveJSON(mapping, to: idMappingPath)
  }

  // MARK: - State

  public static func loadState() -> SyncState {
    loadJSON(from: statePath, default: SyncState())
  }

  public static func saveState(_ state: SyncState) throws {
    try saveJSON(state, to: statePath)
  }

  // MARK: - Private Helpers

  private static func saveJSON<T: Encodable>(_ value: T, to path: String) throws {
    let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(value)
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
  }

  private static func loadJSON<T: Decodable>(from path: String, default defaultValue: T) -> T {
    let data: Data
    do {
      data = try Data(contentsOf: URL(fileURLWithPath: path))
    } catch {
      return defaultValue
    }
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      fputs("Warning: Could not parse \(path): \(error.localizedDescription)\n", stderr)
      return defaultValue
    }
  }
}
