import EventModels
import XCTest

@testable import EventSync
@testable import event

#if canImport(EventKit)
  import EventKit
#endif

// MARK: - BackendFactory Tests

final class BackendFactoryTests: XCTestCase {

  // MARK: - Reminders Backend

  func testMakeRemindersBackend() async throws {
    let backend = try await BackendFactory.makeRemindersBackend()
    #if canImport(EventKit)
      XCTAssertTrue(
        backend is ReminderService,
        "macOS should return ReminderService, got \(type(of: backend))"
      )
    #else
      XCTAssertTrue(
        backend is CloudflareReminderService,
        "Linux should return CloudflareReminderService, got \(type(of: backend))"
      )
    #endif
  }

  // MARK: - Calendar Backend

  func testMakeCalendarBackend() async throws {
    let backend = try await BackendFactory.makeCalendarBackend()
    #if canImport(EventKit)
      XCTAssertTrue(
        backend is CalendarService,
        "macOS should return CalendarService, got \(type(of: backend))"
      )
    #else
      XCTAssertTrue(
        backend is CloudflareCalendarService,
        "Linux should return CloudflareCalendarService, got \(type(of: backend))"
      )
    #endif
  }

  // MARK: - Lists Backend

  func testMakeListsBackend() async throws {
    let backend = try await BackendFactory.makeListsBackend()
    #if canImport(EventKit)
      XCTAssertTrue(
        backend is ListService,
        "macOS should return ListService, got \(type(of: backend))"
      )
    #else
      XCTAssertTrue(
        backend is CloudflareListService,
        "Linux should return CloudflareListService, got \(type(of: backend))"
      )
    #endif
  }

  // MARK: - Linux Config Required

  /// On Linux, all three factory methods call `CloudflareConfig.load()` before constructing
  /// a service. When the config file is missing and no environment variables are set, the
  /// factory must throw so the user gets a clear error message.
  ///
  /// On macOS the factory takes the EventKit path and never reads CloudflareConfig, so we
  /// verify the underlying contract that the Linux path depends on.
  func testLinuxConfigRequired() async throws {
    #if canImport(EventKit)
      // On macOS, verify the config-loading contract that the Linux factory path depends on.
      // With no env vars and no config file, CloudflareConfig.load() must throw.
      XCTAssertThrowsError(
        try CloudflareConfig.loadFromEnvironment(
          [SyncConfigStore.EnvKey.apiURL: "https://example.com"]
        )
      ) { error in
        guard let cliError = error as? EventCLIError else {
          XCTFail("Expected EventCLIError, got \(type(of: error))")
          return
        }
        if case .invalidInput(let message) = cliError {
          XCTAssertTrue(
            message.contains("Both"),
            "Error message should mention both variables are required"
          )
        } else {
          XCTFail("Expected invalidInput, got \(cliError)")
        }
      }
    #else
      // On Linux, verify that factory methods throw when config is missing.
      do {
        _ = try await BackendFactory.makeRemindersBackend()
        XCTFail("Expected error when Cloudflare config is missing on Linux")
      } catch {
        // Expected: CloudflareConfig.load() throws because no config exists
      }

      do {
        _ = try await BackendFactory.makeCalendarBackend()
        XCTFail("Expected error when Cloudflare config is missing on Linux")
      } catch {
        // Expected
      }

      do {
        _ = try await BackendFactory.makeListsBackend()
        XCTFail("Expected error when Cloudflare config is missing on Linux")
      } catch {
        // Expected
      }
    #endif
  }
}
