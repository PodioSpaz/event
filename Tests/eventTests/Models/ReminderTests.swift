#if canImport(EventKit)
  import EventKit
  import EventModels
  import XCTest

  @testable import event

  final class ReminderTests: XCTestCase {

    private let store = EKEventStore()

    func testReminderInitialization() {
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "Buy Milk"
      ekReminder.isCompleted = true
      ekReminder.notes = "2% fat"
      ekReminder.priority = 1

      let reminder = Reminder(from: ekReminder)

      XCTAssertEqual(reminder.title, "Buy Milk")
      XCTAssertEqual(reminder.isCompleted, true)
      XCTAssertEqual(reminder.notes, "2% fat")
      XCTAssertEqual(reminder.priority, 1)
    }

    func testReminderWithNoNotesAndPriority() {
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "Simple Task"
      ekReminder.priority = 0

      let reminder = Reminder(from: ekReminder)

      XCTAssertEqual(reminder.title, "Simple Task")
      XCTAssertEqual(reminder.priority, 0)
      XCTAssertNil(reminder.notes)
    }

    func testReminderWithAllDayDueDate() throws {
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "All-day due"
      let date = try Date.validated(dateString: "2026-07-13")
      ekReminder.dueDateComponents = DateComponentsBuilder.buildAllDay(from: date)

      let reminder = Reminder(from: ekReminder)

      XCTAssertEqual(reminder.dueDate, "2026-07-13")
      XCTAssertEqual(reminder.dueDateIsAllDay, true)
    }

    func testReminderWithTimedDueDate() throws {
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "Timed due"
      let date = try Date.validated(dateTimeString: "2026-07-13 09:30:00")
      ekReminder.dueDateComponents = DateComponentsBuilder.build(from: date)

      let reminder = Reminder(from: ekReminder)

      XCTAssertEqual(reminder.dueDate, "2026-07-13 09:30:00")
      XCTAssertEqual(reminder.dueDateIsAllDay, false)
    }

    func testReminderWithNoDueDate() {
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "No due date"

      let reminder = Reminder(from: ekReminder)

      XCTAssertNil(reminder.dueDate)
      XCTAssertNil(reminder.dueDateIsAllDay)
    }

    func testReminderWithAllDayStartDate() throws {
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "All-day start"
      let date = try Date.validated(dateString: "2026-07-13")
      ekReminder.startDateComponents = DateComponentsBuilder.buildAllDay(from: date)

      let reminder = Reminder(from: ekReminder)

      XCTAssertEqual(reminder.startDate, "2026-07-13")
      XCTAssertEqual(reminder.startDateIsAllDay, true)
    }

    func testReminderWithTimedStartDate() throws {
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "Timed start"
      let date = try Date.validated(dateTimeString: "2026-07-13 09:30:00")
      ekReminder.startDateComponents = DateComponentsBuilder.build(from: date)

      let reminder = Reminder(from: ekReminder)

      XCTAssertEqual(reminder.startDate, "2026-07-13 09:30:00")
      XCTAssertEqual(reminder.startDateIsAllDay, false)
    }

    func testReminderWithNoStartDate() {
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "No start date"

      let reminder = Reminder(from: ekReminder)

      XCTAssertNil(reminder.startDate)
      XCTAssertNil(reminder.startDateIsAllDay)
    }
  }
#endif
