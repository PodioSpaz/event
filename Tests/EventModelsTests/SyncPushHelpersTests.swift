import EventModels
import XCTest

final class SyncPushHelpersTests: XCTestCase {
  struct Item: Sendable {
    let id: String
  }

  func testCurrentRemoteIdsUsesIdentityWhenMappingMissing() {
    let items = [Item(id: "local-a"), Item(id: "local-b")]
    let localToRemote = ["local-b": "remote-b"]

    let remoteIds = SyncPushHelpers.currentRemoteIds(
      items: items,
      getId: { $0.id },
      localToRemote: localToRemote
    )

    XCTAssertEqual(remoteIds, ["local-a", "remote-b"])
  }
}
