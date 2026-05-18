import XCTest

@testable import EventModels

final class SyncConfigStoreTests: XCTestCase {
  func testSyncConfigCodable() throws {
    let config = SyncConfig(
      apiURL: "https://example.workers.dev",
      apiToken: "test-token",
      deviceId: "test-device"
    )
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(SyncConfig.self, from: data)
    XCTAssertEqual(decoded.apiURL, config.apiURL)
    XCTAssertEqual(decoded.apiToken, config.apiToken)
    XCTAssertEqual(decoded.deviceId, config.deviceId)
  }

  func testSyncCursorsCodable() throws {
    let cursors = SyncCursors(
      reminders: "2026-03-25T10:00:00",
      calendarEvents: "2026-03-25T09:00:00",
      reminderLists: nil
    )
    let data = try JSONEncoder().encode(cursors)
    let decoded = try JSONDecoder().decode(SyncCursors.self, from: data)
    XCTAssertEqual(decoded.reminders, cursors.reminders)
    XCTAssertEqual(decoded.calendarEvents, cursors.calendarEvents)
    XCTAssertNil(decoded.reminderLists)
  }

  // MARK: - Environment-based config

  func testLoadFromEnvironmentBuildsConfigWhenBothVarsPresent() throws {
    let config = try SyncConfigStore.loadFromEnvironment([
      "EVENT_SYNC_API_URL": "https://example.workers.dev",
      "EVENT_SYNC_API_TOKEN": "tok",
      "EVENT_SYNC_DEVICE_ID": "dev-1",
    ])
    XCTAssertEqual(config?.apiURL, "https://example.workers.dev")
    XCTAssertEqual(config?.apiToken, "tok")
    XCTAssertEqual(config?.deviceId, "dev-1")
  }

  func testLoadFromEnvironmentDefaultsDeviceIdToHostname() throws {
    let config = try SyncConfigStore.loadFromEnvironment([
      "EVENT_SYNC_API_URL": "https://example.workers.dev",
      "EVENT_SYNC_API_TOKEN": "tok",
    ])
    XCTAssertEqual(config?.deviceId, ProcessInfo.processInfo.hostName)
  }

  func testLoadFromEnvironmentReturnsNilWhenUnset() throws {
    XCTAssertNil(try SyncConfigStore.loadFromEnvironment([:]))
  }

  func testLoadFromEnvironmentTreatsEmptyStringAsAbsent() throws {
    XCTAssertNil(
      try SyncConfigStore.loadFromEnvironment([
        "EVENT_SYNC_API_URL": "",
        "EVENT_SYNC_API_TOKEN": "",
      ]))
  }

  func testLoadFromEnvironmentThrowsWhenOnlyURLSet() {
    XCTAssertThrowsError(
      try SyncConfigStore.loadFromEnvironment([
        "EVENT_SYNC_API_URL": "https://example.workers.dev"
      ]))
  }

  func testLoadFromEnvironmentThrowsWhenOnlyTokenSet() {
    XCTAssertThrowsError(
      try SyncConfigStore.loadFromEnvironment(["EVENT_SYNC_API_TOKEN": "tok"]))
  }

  func testLoadFromEnvironmentThrowsForNonHTTPSURL() {
    XCTAssertThrowsError(
      try SyncConfigStore.loadFromEnvironment([
        "EVENT_SYNC_API_URL": "http://example.workers.dev",
        "EVENT_SYNC_API_TOKEN": "tok",
      ]))
  }

  func testHasEnvironmentConfigReflectsPresence() {
    XCTAssertTrue(
      SyncConfigStore.hasEnvironmentConfig([
        "EVENT_SYNC_API_URL": "https://example.workers.dev",
        "EVENT_SYNC_API_TOKEN": "tok",
      ]))
    XCTAssertFalse(SyncConfigStore.hasEnvironmentConfig([:]))
    XCTAssertFalse(
      SyncConfigStore.hasEnvironmentConfig([
        "EVENT_SYNC_API_URL": "https://example.workers.dev"
      ]))
  }
}
