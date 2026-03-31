import XCTest

@testable import event

final class SyncCommandsTests: XCTestCase {
  func testFullPullOrderCreatesListsBeforeReminders() {
    XCTAssertEqual(SyncEntityType.fullPullOrder, [.lists, .reminders, .calendar])
  }
}
