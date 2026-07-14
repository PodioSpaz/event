#if canImport(EventKit)

  import EventKit
  import EventModels
  import Foundation

  extension Reminder {
    init(from ekReminder: EKReminder, preferredTimeZone: TimeZone = .current) {
      let dateTimeFormatter = DateFormatter()
      dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
      dateTimeFormatter.timeZone = preferredTimeZone

      let dateOnlyFormatter = DateFormatter()
      dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
      dateOnlyFormatter.timeZone = preferredTimeZone

      func isAllDay(_ components: DateComponents) -> Bool {
        components.hour == nil && components.minute == nil
      }

      func formattedString(from components: DateComponents?) -> String? {
        guard let components,
          let date = DateComponentsBuilder.toDate(from: components, timeZone: preferredTimeZone)
        else {
          return nil
        }
        return isAllDay(components)
          ? dateOnlyFormatter.string(from: date)
          : dateTimeFormatter.string(from: date)
      }

      let dueDate = formattedString(from: ekReminder.dueDateComponents)
      let dueDateIsAllDay = ekReminder.dueDateComponents.map(isAllDay)
      let startDate = formattedString(from: ekReminder.startDateComponents)
      let startDateIsAllDay = ekReminder.startDateComponents.map(isAllDay)

      let alarms = ekReminder.alarms?.map { Alarm(from: $0, preferredTimeZone: preferredTimeZone) }
      let recurrenceRules = ekReminder.recurrenceRules?.map { RecurrenceRule(from: $0) }
      let locationTrigger = ekReminder.alarms?.compactMap { LocationTrigger(from: $0) }.first

      let utcFormatter = ISO8601DateFormatter.syncISO8601

      self.init(
        id: ekReminder.calendarItemIdentifier,
        title: ekReminder.title ?? "",
        isCompleted: ekReminder.isCompleted,
        isFlagged: false,  // EKReminder has no isFlagged property
        list: ekReminder.calendar?.title ?? "Unknown",
        notes: ekReminder.notes,
        url: ekReminder.url?.absoluteString,
        location: ekReminder.location,
        timeZone: ekReminder.timeZone?.identifier,
        dueDate: dueDate,
        dueDateIsAllDay: dueDateIsAllDay,
        startDate: startDate,
        startDateIsAllDay: startDateIsAllDay,
        completionDate: ekReminder.completionDate.map { utcFormatter.string(from: $0) },
        creationDate: ekReminder.creationDate.map { utcFormatter.string(from: $0) },
        lastModifiedDate: ekReminder.lastModifiedDate.map { utcFormatter.string(from: $0) },
        externalId: ekReminder.calendarItemExternalIdentifier,
        priority: ekReminder.priority,
        alarms: alarms,
        recurrenceRules: recurrenceRules,
        locationTrigger: locationTrigger
      )
    }
  }

#endif
