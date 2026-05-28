import EventModels
import XCTest

@testable import EventSync

final class CloudflareConfigTests: XCTestCase {
  // MARK: - Environment Variable Loading

  func testLoadFromEnvironmentBothVarsPresent() throws {
    let config = try CloudflareConfig.loadFromEnvironment([
      "EVENT_SYNC_API_URL": "https://example.workers.dev",
      "EVENT_SYNC_API_TOKEN": "test-token",
      "EVENT_SYNC_DEVICE_ID": "test-device",
    ])

    XCTAssertNotNil(config)
    XCTAssertEqual(config?.apiURL, "https://example.workers.dev")
    XCTAssertEqual(config?.apiToken, "test-token")
    XCTAssertEqual(config?.deviceId, "test-device")
  }

  func testLoadFromEnvironmentDefaultsDeviceIdToHostname() throws {
    let config = try CloudflareConfig.loadFromEnvironment([
      "EVENT_SYNC_API_URL": "https://example.workers.dev",
      "EVENT_SYNC_API_TOKEN": "test-token",
    ])

    XCTAssertNotNil(config)
    XCTAssertEqual(config?.deviceId, ProcessInfo.processInfo.hostName)
  }

  func testLoadFromEnvironmentReturnsNilWhenUnset() throws {
    let config = try CloudflareConfig.loadFromEnvironment([:])
    XCTAssertNil(config)
  }

  func testLoadFromEnvironmentTreatsEmptyStringAsAbsent() throws {
    let config = try CloudflareConfig.loadFromEnvironment([
      "EVENT_SYNC_API_URL": "",
      "EVENT_SYNC_API_TOKEN": "",
    ])
    XCTAssertNil(config)
  }

  // MARK: - Partial Environment Variables Error

  func testPartialEnvironmentOnlyURLThrows() {
    XCTAssertThrowsError(
      try CloudflareConfig.loadFromEnvironment([
        "EVENT_SYNC_API_URL": "https://example.workers.dev"
      ])
    ) { error in
      guard let cliError = error as? EventCLIError else {
        XCTFail("Expected EventCLIError")
        return
      }
      if case .invalidInput = cliError {
      } else {
        XCTFail("Expected invalidInput error, got \(cliError)")
      }
    }
  }

  func testPartialEnvironmentOnlyTokenThrows() {
    XCTAssertThrowsError(
      try CloudflareConfig.loadFromEnvironment([
        "EVENT_SYNC_API_TOKEN": "test-token"
      ])
    ) { error in
      guard let cliError = error as? EventCLIError else {
        XCTFail("Expected EventCLIError")
        return
      }
      if case .invalidInput = cliError {
      } else {
        XCTFail("Expected invalidInput error, got \(cliError)")
      }
    }
  }

  func testLoadFromEnvironmentRejectsNonHTTPS() {
    XCTAssertThrowsError(
      try CloudflareConfig.loadFromEnvironment([
        "EVENT_SYNC_API_URL": "http://insecure.example.com",
        "EVENT_SYNC_API_TOKEN": "test-token",
      ]))
  }

  // MARK: - toSyncConfig Conversion

  func testToSyncConfig() {
    let config = CloudflareConfig(
      apiURL: "https://example.workers.dev",
      apiToken: "my-token",
      deviceId: "my-device"
    )

    let syncConfig = config.toSyncConfig()

    XCTAssertEqual(syncConfig.apiURL, config.apiURL)
    XCTAssertEqual(syncConfig.apiToken, config.apiToken)
    XCTAssertEqual(syncConfig.deviceId, config.deviceId)
  }

  // MARK: - Codable Roundtrip

  func testCodableRoundtrip() throws {
    let config = CloudflareConfig(
      apiURL: "https://example.workers.dev",
      apiToken: "roundtrip-token",
      deviceId: "device-42"
    )

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(CloudflareConfig.self, from: data)

    XCTAssertEqual(decoded, config)
  }

  // MARK: - Save and Load via File

  func testSaveAndLoadFromSpecificPath() throws {
    let tmpDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("CloudflareConfigTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let path = tmpDir.appendingPathComponent("config.json").path
    let config = CloudflareConfig(
      apiURL: "https://example.workers.dev",
      apiToken: "saved-token",
      deviceId: "saved-device"
    )

    try SyncConfigStore.saveJSON(config, to: path)

    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let loaded = try JSONDecoder().decode(CloudflareConfig.self, from: data)

    XCTAssertEqual(loaded, config)
  }

  // MARK: - File Permissions

  func testFilePermissions() throws {
    let tmpDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("CloudflareConfigTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let path = tmpDir.appendingPathComponent("config.json").path
    let config = CloudflareConfig(
      apiURL: "https://example.workers.dev",
      apiToken: "secret-token",
      deviceId: "test-device"
    )

    try SyncConfigStore.saveJSON(config, to: path)

    let attrs = try FileManager.default.attributesOfItem(atPath: path)
    let perms = attrs[.posixPermissions] as? Int
    XCTAssertEqual(perms, 0o600, "Config file must not be readable by group or others")
  }

  // MARK: - Equatable

  func testEquatable() {
    let a = CloudflareConfig(
      apiURL: "https://a.workers.dev", apiToken: "tok", deviceId: "dev"
    )
    let b = CloudflareConfig(
      apiURL: "https://a.workers.dev", apiToken: "tok", deviceId: "dev"
    )
    let c = CloudflareConfig(
      apiURL: "https://b.workers.dev", apiToken: "tok", deviceId: "dev"
    )

    XCTAssertEqual(a, b)
    XCTAssertNotEqual(a, c)
  }

  // MARK: - load() with Environment Variables

  func testLoadUsesEnvironmentVariablesWhenSet() throws {
    setenv("EVENT_SYNC_API_URL", "https://env.workers.dev", 1)
    setenv("EVENT_SYNC_API_TOKEN", "env-token", 1)
    setenv("EVENT_SYNC_DEVICE_ID", "env-device", 1)
    defer {
      unsetenv("EVENT_SYNC_API_URL")
      unsetenv("EVENT_SYNC_API_TOKEN")
      unsetenv("EVENT_SYNC_DEVICE_ID")
    }

    let config = try CloudflareConfig.load()
    XCTAssertEqual(config.apiURL, "https://env.workers.dev")
    XCTAssertEqual(config.apiToken, "env-token")
    XCTAssertEqual(config.deviceId, "env-device")
  }

  func testLoadRejectsNonHTTPSFromFile() throws {
    let tmpDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("CloudflareConfigTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let path = tmpDir.appendingPathComponent("config.json").path
    let config = CloudflareConfig(
      apiURL: "http://insecure.example.com",
      apiToken: "tok",
      deviceId: "dev"
    )
    try SyncConfigStore.saveJSON(config, to: path)

    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let loaded = try JSONDecoder().decode(CloudflareConfig.self, from: data)
    XCTAssertThrowsError(try SyncConfigStore.validateAPIURL(loaded.apiURL))
  }
}
