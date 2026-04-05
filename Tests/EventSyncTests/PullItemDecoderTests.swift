import EventModels
import Foundation
import XCTest

@testable import EventSync

private struct ReminderPayload: Codable, Equatable {
  let title: String
}

final class PullItemDecoderTests: XCTestCase {
  private func makeDTO(id: String, json: [String: Any], deleted: Bool = false) throws -> PullItemDTO
  {
    let data = try JSONSerialization.data(withJSONObject: json)
    return PullItemDTO(
      id: id,
      data: RawJSON(bytes: data),
      deleted: deleted,
      updatedAt: "2026-03-27T12:00:00Z",
      lastModified: "2026-03-27T11:59:00Z"
    )
  }

  func testDecodeItemsSucceedsWithValidData() throws {
    let items = [
      try makeDTO(id: "r1", json: ["title": "Buy milk"]),
      try makeDTO(id: "r2", json: ["title": "Walk dog"], deleted: true),
    ]

    let decoded: [PullItem<ReminderPayload>] = try PullItemDecoder.decodeItems(
      from: items, entity: "reminders"
    )
    XCTAssertEqual(decoded.count, 2)
    XCTAssertEqual(decoded[0].data.title, "Buy milk")
    XCTAssertEqual(decoded[0].id, "r1")
    XCTAssertFalse(decoded[0].deleted)
    XCTAssertEqual(decoded[1].data.title, "Walk dog")
    XCTAssertTrue(decoded[1].deleted)
  }

  func testDecodeItemsThrowsWhenAnyItemIsMalformed() throws {
    let items = [
      try makeDTO(id: "r1", json: ["title": "ok"]),
      try makeDTO(id: "r2", json: ["wrong": "shape"]),
    ]

    XCTAssertThrowsError(
      try PullItemDecoder.decodeItems(from: items, entity: "reminders")
        as [PullItem<ReminderPayload>]
    )
  }

  func testDecodeEmptyItems() throws {
    let decoded: [PullItem<ReminderPayload>] = try PullItemDecoder.decodeItems(
      from: [], entity: "reminders"
    )
    XCTAssertTrue(decoded.isEmpty)
  }
}
