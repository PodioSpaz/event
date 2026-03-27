import XCTest
import EventModels
@testable import EventSync

private struct ReminderPayload: Codable, Equatable {
  let title: String
}

final class PullItemDecoderTests: XCTestCase {
  func testDecodeItemsThrowsWhenAnyItemIsMalformed() throws {
    let dto = PullResponseDTO(
      items: [
        PullItemDTO(
          id: "r1",
          data: .object(["title": .string("ok")]),
          deleted: false,
          updatedAt: "2026-03-27T12:00:00Z"
        ),
        PullItemDTO(
          id: "r2",
          data: .object(["wrong": .string("shape")]),
          deleted: false,
          updatedAt: "2026-03-27T12:01:00Z"
        ),
      ],
      cursor: "cursor",
      hasMore: false
    )

    XCTAssertThrowsError(
      try PullItemDecoder.decodeItems(from: dto.items, entity: "reminders")
        as [PullItem<ReminderPayload>]
    )
  }
}
