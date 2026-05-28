import EventModels
import XCTest

final class SyncIdMappingTests: XCTestCase {
  func testInvertsRemoteToLocalMapping() {
    let (inverted, collisions) = SyncIdMapping.inverted([
      "remote-1": "local-a",
      "remote-2": "local-b",
    ])

    XCTAssertEqual(inverted, ["local-a": "remote-1", "local-b": "remote-2"])
    XCTAssertTrue(collisions.isEmpty)
  }

  func testReportsCollisionAndKeepsSmallerRemoteId() {
    let (inverted, collisions) = SyncIdMapping.inverted([
      "remote-z": "local-shared",
      "remote-a": "local-shared",
    ])

    // Deterministic: the lexicographically smaller remote ID wins.
    XCTAssertEqual(inverted["local-shared"], "remote-a")
    XCTAssertEqual(collisions.count, 1)
    XCTAssertEqual(
      collisions.first,
      SyncIdMapping.InversionCollision(
        localId: "local-shared", keptRemoteId: "remote-a", droppedRemoteId: "remote-z"))
  }

  func testEmptyMappingInvertsToEmpty() {
    let (inverted, collisions) = SyncIdMapping.inverted([:])
    XCTAssertTrue(inverted.isEmpty)
    XCTAssertTrue(collisions.isEmpty)
  }
}
