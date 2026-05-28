import EventModels
import XCTest

final class SyncTimestampTests: XCTestCase {
  func testParsesISO8601WithFractionalSeconds() {
    XCTAssertNotNil(SyncTimestamp.parse("2026-03-10T14:00:00.123Z"))
  }

  func testParsesISO8601WithoutFractionalSeconds() {
    XCTAssertNotNil(SyncTimestamp.parse("2026-03-10T14:00:00Z"))
  }

  func testParsesBareDateTime() {
    XCTAssertNotNil(SyncTimestamp.parse("2026-03-10 14:00:00"))
  }

  func testReturnsNilForEmptyOrMissingInput() {
    XCTAssertNil(SyncTimestamp.parse(nil))
    XCTAssertNil(SyncTimestamp.parse(""))
    XCTAssertNil(SyncTimestamp.parse("not-a-date"))
  }

  func testFractionalAndNonFractionalFormsAreComparable() throws {
    // The fractional form sorts lexically after the plain form ("Z" > "."),
    // so a `Date`-based comparison is required for correctness.
    let earlier = try XCTUnwrap(SyncTimestamp.parse("2026-03-10T14:00:00Z"))
    let later = try XCTUnwrap(SyncTimestamp.parse("2026-03-10T14:00:01.500Z"))
    XCTAssertLessThan(earlier, later)
  }
}
