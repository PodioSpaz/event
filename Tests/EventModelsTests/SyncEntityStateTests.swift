import EventModels
import XCTest

final class SyncEntityStateTests: XCTestCase {
  func testDeletionCandidatesOnlyIncludePreviouslyKnownRemoteIds() {
    let state = SyncEntityState(
      knownRemoteIds: ["remote-a", "remote-b", "remote-c"]
    )

    let deletions = state.deletionCandidates(
      currentRemoteIds: ["remote-a", "remote-c", "local-only"]
    )

    XCTAssertEqual(deletions, ["remote-b"])
  }

  func testListLastModifiedReusesStoredValueWhenSnapshotIsUnchanged() throws {
    let list = ReminderList(id: "local-1", title: "Work", color: "#FF0000", isImmutable: false)
    var state = SyncEntityState()
    try state.recordSyncedValue(list, remoteId: "remote-1", lastModified: "2026-03-27T12:00:00Z")

    let nextLastModified = try state.lastModified(
      for: list,
      remoteId: "remote-1",
      fallback: "2026-03-28T09:00:00Z"
    )

    XCTAssertEqual(nextLastModified, "2026-03-27T12:00:00Z")
  }

  func testWindowedDeletionCandidatesSkipWhenDateRangeMissing() {
    let state = SyncEntityState(
      knownRemoteIds: ["remote-a"],
      dateRangeByRemoteId: [:]
    )
    let window = SyncDateRange(start: "2025-01-01", end: "2028-01-01")

    let deletions = state.deletionCandidates(
      currentRemoteIds: [],
      withinRange: window
    )

    XCTAssertEqual(deletions, [])
  }

  func testWindowedDeletionCandidatesSkipWhenRangeDoesNotOverlap() {
    let state = SyncEntityState(
      knownRemoteIds: ["remote-a"],
      dateRangeByRemoteId: [
        "remote-a": SyncDateRange(start: "2030-01-01", end: "2030-01-02")
      ]
    )
    let window = SyncDateRange(start: "2025-01-01", end: "2028-01-01")

    let deletions = state.deletionCandidates(
      currentRemoteIds: [],
      withinRange: window
    )

    XCTAssertEqual(deletions, [])
  }

  func testWindowedDeletionCandidatesIncludeWhenRangeOverlapsAndAbsentLocally() {
    let state = SyncEntityState(
      knownRemoteIds: ["remote-a"],
      dateRangeByRemoteId: [
        "remote-a": SyncDateRange(start: "2026-06-01", end: "2026-06-01")
      ]
    )
    let window = SyncDateRange(start: "2025-01-01", end: "2028-01-01")

    let deletions = state.deletionCandidates(
      currentRemoteIds: [],
      withinRange: window
    )

    XCTAssertEqual(deletions, ["remote-a"])
  }

  func testListLastModifiedAdvancesWhenSnapshotChanges() throws {
    let original = ReminderList(id: "local-1", title: "Work", color: "#FF0000", isImmutable: false)
    let renamed = ReminderList(id: "local-1", title: "Work Sync", color: "#FF0000", isImmutable: false)
    var state = SyncEntityState()
    try state.recordSyncedValue(original, remoteId: "remote-1", lastModified: "2026-03-27T12:00:00Z")

    let nextLastModified = try state.lastModified(
      for: renamed,
      remoteId: "remote-1",
      fallback: "2026-03-28T09:00:00Z"
    )

    XCTAssertEqual(nextLastModified, "2026-03-28T09:00:00Z")
  }
}
