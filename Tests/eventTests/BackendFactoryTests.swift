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
    #if canImport(EventKit)
    let backend = try await BackendFactory.makeRemindersBackend()
    XCTAssertTrue(
      backend is ReminderService,
      "macOS should return ReminderService, got \(type(of: backend))"
    )
    #else
    // On Linux without config, the factory should throw
    do {
      _ = try await BackendFactory.makeRemindersBackend()
      XCTFail("Expected error when Cloudflare config is missing on Linux")
    } catch {
      // Expected: CloudflareConfig.load() throws because no config exists
    }
    #endif
  }

  // MARK: - Calendar Backend

  func testMakeCalendarBackend() async throws {
    #if canImport(EventKit)
    let backend = try await BackendFactory.makeCalendarBackend()
    XCTAssertTrue(
      backend is CalendarService,
      "macOS should return CalendarService, got \(type(of: backend))"
    )
    #else
    do {
      _ = try await BackendFactory.makeCalendarBackend()
      XCTFail("Expected error when Cloudflare config is missing on Linux")
    } catch {
      // Expected
    }
    #endif
  }

  // MARK: - Lists Backend

  func testMakeListsBackend() async throws {
    #if canImport(EventKit)
    let backend = try await BackendFactory.makeListsBackend()
    XCTAssertTrue(
      backend is ListService,
      "macOS should return ListService, got \(type(of: backend))"
    )
    #else
    do {
      _ = try await BackendFactory.makeListsBackend()
      XCTFail("Expected error when Cloudflare config is missing on Linux")
    } catch {
      // Expected
    }
    #endif
  }

  // MARK: - Linux Config Required

  func testLinuxConfigRequired() async throws {
    #if canImport(EventKit)
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
    do {
      _ = try await BackendFactory.makeRemindersBackend()
      XCTFail("Expected error when Cloudflare config is missing on Linux")
    } catch {
      // Expected
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
