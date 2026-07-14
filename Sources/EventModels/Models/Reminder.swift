import Foundation

// MARK: - Reminder Model

public struct Reminder: Codable, Sendable {
  public let id: String
  public let title: String
  public let isCompleted: Bool
  public let isFlagged: Bool  // Note: EKReminder has no isFlagged, always false
  public let list: String
  public let notes: String?
  public let url: String?
  public let location: String?
  public let timeZone: String?
  public let dueDate: String?
  public let dueDateIsAllDay: Bool?
  public let startDate: String?
  public let startDateIsAllDay: Bool?
  public let completionDate: String?
  public let creationDate: String?
  public let lastModifiedDate: String?
  public let externalId: String?
  public let priority: Int
  public let alarms: [Alarm]?
  public let recurrenceRules: [RecurrenceRule]?
  public let locationTrigger: LocationTrigger?

  public init(
    id: String,
    title: String,
    isCompleted: Bool,
    isFlagged: Bool,
    list: String,
    notes: String?,
    url: String?,
    location: String?,
    timeZone: String?,
    dueDate: String?,
    dueDateIsAllDay: Bool? = nil,
    startDate: String?,
    startDateIsAllDay: Bool? = nil,
    completionDate: String?,
    creationDate: String?,
    lastModifiedDate: String?,
    externalId: String?,
    priority: Int,
    alarms: [Alarm]?,
    recurrenceRules: [RecurrenceRule]?,
    locationTrigger: LocationTrigger?
  ) {
    self.id = id
    self.title = title
    self.isCompleted = isCompleted
    self.isFlagged = isFlagged
    self.list = list
    self.notes = notes
    self.url = url
    self.location = location
    self.timeZone = timeZone
    self.dueDate = dueDate
    self.dueDateIsAllDay = dueDateIsAllDay
    self.startDate = startDate
    self.startDateIsAllDay = startDateIsAllDay
    self.completionDate = completionDate
    self.creationDate = creationDate
    self.lastModifiedDate = lastModifiedDate
    self.externalId = externalId
    self.priority = priority
    self.alarms = alarms
    self.recurrenceRules = recurrenceRules
    self.locationTrigger = locationTrigger
  }
}
