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

  func testSnapshotIgnoresIdentityAndTimestampDifferences() throws {
    // Simulates the pull→push flow: pull stores a snapshot with remote ID and
    // server timestamps, push compares against local ID and EventKit timestamps.
    // These volatile fields should be ignored so unchanged items aren't re-pushed.
    let pulledReminder = Reminder(
      id: "remote-abc",  // server's remote ID
      title: "Buy milk",
      isCompleted: false,
      isFlagged: false,
      list: "Personal",
      notes: nil,
      url: nil,
      location: nil,
      timeZone: nil,
      dueDate: nil,
      startDate: nil,
      completionDate: "2026-05-28T10:00:00Z",  // server's value
      creationDate: "2026-05-20T08:00:00Z",  // server's value
      lastModifiedDate: "2026-05-28T10:00:00Z",  // server's value
      externalId: nil,
      priority: 0,
      alarms: nil,
      recurrenceRules: nil,
      locationTrigger: nil
    )

    let localReminder = Reminder(
      id: "local-xyz",  // different local ID
      title: "Buy milk",  // same content
      isCompleted: false,
      isFlagged: false,
      list: "Personal",
      notes: nil,
      url: nil,
      location: nil,
      timeZone: nil,
      dueDate: nil,
      startDate: nil,
      completionDate: "2026-05-28T10:05:00Z",  // different (EventKit-managed)
      creationDate: "2026-05-20T08:05:00Z",  // different (EventKit-managed)
      lastModifiedDate: "2026-05-28T10:10:00Z",  // different (EventKit-managed)
      externalId: nil,
      priority: 0,
      alarms: nil,
      recurrenceRules: nil,
      locationTrigger: nil
    )

    var state = SyncEntityState()
    try state.recordSyncedValue(
      pulledReminder, remoteId: "remote-abc", lastModified: "2026-05-28T10:00:00Z")

    let nextLastModified = try state.lastModified(
      for: localReminder,
      remoteId: "remote-abc",
      fallback: "2026-05-28T11:00:00Z"
    )

    // Should reuse stored lastModified (not fallback) because content is unchanged
    XCTAssertEqual(nextLastModified, "2026-05-28T10:00:00Z")
  }

  func testSnapshotDetectsContentChangesDespiteVolatileFields() throws {
    // Verifies that actual content changes are still detected even when
    // volatile fields differ.
    let pulledReminder = Reminder(
      id: "remote-abc",
      title: "Buy milk",
      isCompleted: false,
      isFlagged: false,
      list: "Personal",
      notes: nil,
      url: nil,
      location: nil,
      timeZone: nil,
      dueDate: nil,
      startDate: nil,
      completionDate: nil,
      creationDate: "2026-05-20T08:00:00Z",
      lastModifiedDate: "2026-05-28T10:00:00Z",
      externalId: nil,
      priority: 0,
      alarms: nil,
      recurrenceRules: nil,
      locationTrigger: nil
    )

    let modifiedLocalReminder = Reminder(
      id: "local-xyz",  // different ID
      title: "Buy almond milk",  // CONTENT changed
      isCompleted: false,
      isFlagged: false,
      list: "Personal",
      notes: nil,
      url: nil,
      location: nil,
      timeZone: nil,
      dueDate: nil,
      startDate: nil,
      completionDate: nil,
      creationDate: "2026-05-20T08:05:00Z",  // different
      lastModifiedDate: "2026-05-28T11:00:00Z",  // different
      externalId: nil,
      priority: 0,
      alarms: nil,
      recurrenceRules: nil,
      locationTrigger: nil
    )

    var state = SyncEntityState()
    try state.recordSyncedValue(
      pulledReminder, remoteId: "remote-abc", lastModified: "2026-05-28T10:00:00Z")

    let nextLastModified = try state.lastModified(
      for: modifiedLocalReminder,
      remoteId: "remote-abc",
      fallback: "2026-05-28T12:00:00Z"
    )

    // Should return fallback because content (title) changed
    XCTAssertEqual(nextLastModified, "2026-05-28T12:00:00Z")
  }
}
