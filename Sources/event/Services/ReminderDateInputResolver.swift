import EventModels
import Foundation

struct ReminderDateComponentsResolution {
  let date: Date
  let components: DateComponents
  let isAllDay: Bool
}

enum ReminderDateInputResolver {
  static func resolve(
    dateString: String,
    timeZone: TimeZone = .current
  ) throws -> ReminderDateComponentsResolution {
    if Date.isAllDayFormat(dateString) {
      let date = try Date.validated(dateString: dateString)
      return ReminderDateComponentsResolution(
        date: date,
        components: DateComponentsBuilder.buildAllDay(from: date, timeZone: timeZone),
        isAllDay: true
      )
    }
    let date = try Date.validated(dateTimeString: dateString)
    return ReminderDateComponentsResolution(
      date: date,
      components: DateComponentsBuilder.build(from: date, timeZone: timeZone),
      isAllDay: false
    )
  }
}
