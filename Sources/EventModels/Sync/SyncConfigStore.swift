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

  public static func load() throws -> SyncConfig {
    let url = URL(fileURLWithPath: configPath)
    guard FileManager.default.fileExists(atPath: configPath) else {
      throw EventCLIError.notFound(
        "Sync config not found. Run 'event sync config --api-url <URL> --api-token <TOKEN> --device-id <ID>' first."
      )
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(SyncConfig.self, from: data)
  }

  public static func save(_ config: SyncConfig) throws {
    guard config.apiURL.lowercased().hasPrefix("https://") else {
      throw EventCLIError.invalidInput(
        "API URL must use HTTPS. Got: \(config.apiURL)"
      )
    }
    let dir = URL(fileURLWithPath: configPath).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(config)
    try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configPath)
  }

  public static func loadCursors() -> SyncCursors {
    guard FileManager.default.fileExists(atPath: cursorsPath) else {
      return SyncCursors()
    }
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: cursorsPath))
      return try JSONDecoder().decode(SyncCursors.self, from: data)
    } catch {
      print(
        "Warning: Could not parse \(cursorsPath): \(error.localizedDescription). Starting sync from beginning."
      )
      return SyncCursors()
    }
  }

  public static func saveCursors(_ cursors: SyncCursors) throws {
    let dir = URL(fileURLWithPath: cursorsPath).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(cursors)
    try data.write(to: URL(fileURLWithPath: cursorsPath), options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: cursorsPath)
  }

  public static func loadIdMapping() -> SyncIdMapping {
    guard FileManager.default.fileExists(atPath: idMappingPath) else {
      return SyncIdMapping()
    }
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: idMappingPath))
      return try JSONDecoder().decode(SyncIdMapping.self, from: data)
    } catch {
      print(
        "Warning: Could not parse \(idMappingPath): \(error.localizedDescription). Starting with empty mapping."
      )
      return SyncIdMapping()
    }
  }

  public static func saveIdMapping(_ mapping: SyncIdMapping) throws {
    let dir = URL(fileURLWithPath: idMappingPath).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(mapping)
    try data.write(to: URL(fileURLWithPath: idMappingPath), options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: idMappingPath)
  }

  public static func loadState() -> SyncState {
    guard FileManager.default.fileExists(atPath: statePath) else {
      return SyncState()
    }
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: statePath))
      return try JSONDecoder().decode(SyncState.self, from: data)
    } catch {
      print(
        "Warning: Could not parse \(statePath): \(error.localizedDescription). Starting with empty sync state."
      )
      return SyncState()
    }
  }

  public static func saveState(_ state: SyncState) throws {
    let dir = URL(fileURLWithPath: statePath).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(state)
    try data.write(to: URL(fileURLWithPath: statePath), options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: statePath)
  }
}
