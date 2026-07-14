#if canImport(EventKit)
  import EventModels
  import XCTest

  @testable import event

  final class ReminderDateInputResolverTests: XCTestCase {
    func testResolveAcceptsBareDate() throws {
      let resolution = try ReminderDateInputResolver.resolve(dateString: "2026-07-13")

      XCTAssertTrue(resolution.isAllDay)
      XCTAssertNil(resolution.components.hour)
      XCTAssertNil(resolution.components.minute)
      XCTAssertEqual(resolution.components.year, 2026)
      XCTAssertEqual(resolution.components.month, 7)
      XCTAssertEqual(resolution.components.day, 13)
    }

    func testResolveAcceptsFullDateTime() throws {
      let resolution = try ReminderDateInputResolver.resolve(dateString: "2026-07-13 09:30:00")

      XCTAssertFalse(resolution.isAllDay)
      XCTAssertEqual(resolution.components.hour, 9)
      XCTAssertEqual(resolution.components.minute, 30)
    }

    func testResolveRejectsInvalidFormat() {
      XCTAssertThrowsError(try ReminderDateInputResolver.resolve(dateString: "not-a-date"))
    }
  }
#endif
