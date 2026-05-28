import Foundation

// MARK: - Encrypted Payload

public struct EncryptedPayload: Codable, Sendable, Equatable {
  public var notes: String?
  public var url: String?
  public var location: String?
  public var alarms: [Alarm]?
  public var recurrenceRules: [RecurrenceRule]?
  public var attendees: [String]?

  public init(
    notes: String? = nil,
    url: String? = nil,
    location: String? = nil,
    alarms: [Alarm]? = nil,
    recurrenceRules: [RecurrenceRule]? = nil,
    attendees: [String]? = nil
  ) {
    self.notes = notes
    self.url = url
    self.location = location
    self.alarms = alarms
    self.recurrenceRules = recurrenceRules
    self.attendees = attendees
  }

  public var isEmpty: Bool {
    notes == nil
      && url == nil
      && location == nil
      && alarms == nil
      && recurrenceRules == nil
      && attendees == nil
  }
}
