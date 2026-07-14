#if canImport(EventKit)
  import EventKit
  import EventModels
  import XCTest

  @testable import event

  final class FormatterTests: XCTestCase {

    private let store = EKEventStore()

    func testMarkdownFormatterReminder() {
      let formatter = MarkdownFormatter()
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "Buy Milk"
      ekReminder.isCompleted = true
      ekReminder.priority = 1

      let reminder = Reminder(from: ekReminder)
      let md = formatter.format(reminder)

      XCTAssertTrue(md.contains("### Reminder: Buy Milk"))
      XCTAssertTrue(md.contains("**Status:** [x] Completed"))
      XCTAssertTrue(md.contains("**Priority:** High (!!!)"))
    }

    func testMarkdownFormatterReminderAllDayDueDate() throws {
      let formatter = MarkdownFormatter()
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "All-day task"
      let date = try Date.validated(dateString: "2026-07-13")
      ekReminder.dueDateComponents = DateComponentsBuilder.buildAllDay(from: date)

      let reminder = Reminder(from: ekReminder)
      let md = formatter.format(reminder)

      XCTAssertTrue(md.contains("**Due Date:** 2026-07-13 (All Day)"))
    }

    func testMarkdownFormatterReminderTimedDueDateHasNoAllDaySuffix() throws {
      let formatter = MarkdownFormatter()
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "Timed task"
      let date = try Date.validated(dateTimeString: "2026-07-13 09:30:00")
      ekReminder.dueDateComponents = DateComponentsBuilder.build(from: date)

      let reminder = Reminder(from: ekReminder)
      let md = formatter.format(reminder)

      XCTAssertTrue(md.contains("**Due Date:** 2026-07-13 09:30:00\n"))
      XCTAssertFalse(md.contains("(All Day)"))
    }

    func testMarkdownFormatterReminderStartDate() throws {
      let formatter = MarkdownFormatter()
      let ekReminder = EKReminder(eventStore: store)
      ekReminder.title = "Task with start"
      let date = try Date.validated(dateString: "2026-07-13")
      ekReminder.startDateComponents = DateComponentsBuilder.buildAllDay(from: date)

      let reminder = Reminder(from: ekReminder)
      let md = formatter.format(reminder)

      XCTAssertTrue(md.contains("**Start Date:** 2026-07-13 (All Day)"))
    }
  }
#endif
