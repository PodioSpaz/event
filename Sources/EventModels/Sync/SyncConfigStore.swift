import Foundation

// MARK: - Sync Config Store

public enum SyncConfigStore {
  public static var configPath: String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return "\(home)/.config/event-sync/config.json"
  }

  public static var cursorsPath: String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return "\(home)/.config/event-sync/cursors.json"
  }

  public static var idMappingPath: String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return "\(home)/.config/event-sync/id-mapping.json"
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
}
