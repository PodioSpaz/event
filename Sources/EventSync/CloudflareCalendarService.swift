import EventModels
import Foundation

// MARK: - Cloudflare Calendar Service

public actor CloudflareCalendarService: CalendarBackend {
  private let client: D1Client
  private let encryption: EncryptionService

  public init(client: D1Client, encryption: EncryptionService) {
    self.client = client
    self.encryption = encryption
  }

  // MARK: - Fetch

  public func fetchEvents(
    start: String,
    end: String,
    calendarName: String?
  ) async throws -> [CalendarEvent] {
    let all = try await client.pullAllEvents()
    var filtered = all

    if let calendarName {
      filtered = filtered.filter { $0.calendar == calendarName }
    }

    filtered = filtered.filter { event in
      eventOverlapsRange(event: event, rangeStart: start, rangeEnd: end)
    }

    return try await decryptEvents(filtered)
  }

  public func fetchEvent(byId id: String) async throws -> CalendarEvent {
    let all = try await client.pullAllEvents()
    guard let event = all.first(where: { $0.id == id }) else {
      throw EventCLIError.notFound("Calendar event with ID '\(id)' not found")
    }
    let decrypted = try await decryptEvents([event])
    return decrypted[0]
  }

  // MARK: - Create

  public func createEvent(_ params: CreateEventParams) async throws -> CalendarEvent {
    let now = ISO8601DateFormatter.eventISO8601.string(from: Date())
    let id = UUID().uuidString

    let calendarName = params.calendarName ?? "Calendar"
    let plainEvent = CalendarEvent(
      id: id,
      title: params.title,
      calendar: calendarName,
      startDate: params.startDate,
      endDate: params.endDate,
      isAllDay: params.isAllDay,
      location: params.location,
      notes: params.notes,
      url: params.url,
      timeZone: TimeZone.current.identifier,
      creationDate: now,
      lastModifiedDate: now,
      status: nil,
      availability: nil,
      alarms: nil,
      recurrenceRules: nil,
      attendees: nil
    )

    let d1Event = try await encryptEvent(plainEvent)
    _ = try await client.pushEvents([d1Event], idOverrides: [:], lastModifiedByRemoteId: [:])
    return plainEvent
  }

  // MARK: - Update

  public func updateEvent(
    id: String,
    params: UpdateEventParams
  ) async throws -> CalendarEvent {
    let all = try await client.pullAllEvents()
    guard let encrypted = all.first(where: { $0.id == id }) else {
      throw EventCLIError.notFound("Calendar event with ID '\(id)' not found")
    }

    let decrypted = try await decryptEvents([encrypted])
    let existing = decrypted[0]
    let now = ISO8601DateFormatter.eventISO8601.string(from: Date())

    let updatedPlain = CalendarEvent(
      id: existing.id,
      title: params.title ?? existing.title,
      calendar: existing.calendar,
      startDate: params.startDate ?? existing.startDate,
      endDate: params.endDate ?? existing.endDate,
      isAllDay: params.isAllDay ?? existing.isAllDay,
      location: params.location ?? existing.location,
      notes: params.notes ?? existing.notes,
      url: params.url ?? existing.url,
      timeZone: existing.timeZone,
      creationDate: existing.creationDate,
      lastModifiedDate: now,
      status: existing.status,
      availability: existing.availability,
      alarms: existing.alarms,
      recurrenceRules: existing.recurrenceRules,
      attendees: existing.attendees
    )

    let d1Event = try await encryptEvent(updatedPlain)
    _ = try await client.pushEvents([d1Event], idOverrides: [:], lastModifiedByRemoteId: [:])
    return updatedPlain
  }

  // MARK: - Delete

  public func deleteEvent(id: String) async throws {
    try await client.deleteEvent(
      id: id,
      lastModified: ISO8601DateFormatter.eventISO8601.string(from: Date())
    )
  }

  // MARK: - Date Range Filtering

  private func eventOverlapsRange(
    event: CalendarEvent,
    rangeStart: String,
    rangeEnd: String
  ) -> Bool {
    event.startDate <= rangeEnd && event.endDate >= rangeStart
  }

  // MARK: - Encryption Helpers

  private func encryptEvent(_ event: CalendarEvent) async throws -> CalendarEvent {
    let attendeeStrings = event.attendees?.map { $0.url }

    let payload = EncryptedPayload(
      notes: event.notes,
      url: event.url,
      location: event.location,
      alarms: event.alarms,
      recurrenceRules: event.recurrenceRules,
      attendees: attendeeStrings
    )

    guard !payload.isEmpty else { return event }

    let aadDate = Self.aadDate(for: event)
    let encrypted = try await encryption.encrypt(
      payload, recordId: event.id, modifiedDate: aadDate
    )

    let carrier = EncryptedCarrier(p: encrypted.encryptedPayload, i: encrypted.encryptedIV)
    let carrierJSON = try carrier.toJSONString()

    return CalendarEvent(
      id: event.id,
      title: event.title,
      calendar: event.calendar,
      startDate: event.startDate,
      endDate: event.endDate,
      isAllDay: event.isAllDay,
      location: nil,
      notes: carrierJSON,
      url: nil,
      timeZone: event.timeZone,
      creationDate: event.creationDate,
      lastModifiedDate: event.lastModifiedDate,
      status: event.status,
      availability: event.availability,
      alarms: nil,
      recurrenceRules: nil,
      attendees: nil
    )
  }

  private func decryptEvents(_ events: [CalendarEvent]) async throws -> [CalendarEvent] {
    var result: [CalendarEvent] = []
    result.reserveCapacity(events.count)
    for event in events {
      result.append(try await decryptEvent(event))
    }
    return result
  }

  private func decryptEvent(_ event: CalendarEvent) async throws -> CalendarEvent {
    guard let notes = event.notes,
      let carrier = EncryptedCarrier.fromJSON(notes)
    else {
      return event
    }

    let aadDate = Self.aadDate(for: event)
    let payload = try await encryption.decrypt(
      carrier.p,
      iv: carrier.i,
      recordId: event.id,
      modifiedDate: aadDate
    )

    let attendees: [Participant]? = payload.attendees.map { urls in
      urls.map {
        Participant(
          name: nil, url: $0, status: nil, role: nil, type: nil, isCurrentUser: nil
        )
      }
    }

    return CalendarEvent(
      id: event.id,
      title: event.title,
      calendar: event.calendar,
      startDate: event.startDate,
      endDate: event.endDate,
      isAllDay: event.isAllDay,
      location: payload.location ?? event.location,
      notes: payload.notes,
      url: payload.url ?? event.url,
      timeZone: event.timeZone,
      creationDate: event.creationDate,
      lastModifiedDate: event.lastModifiedDate,
      status: event.status,
      availability: event.availability,
      alarms: payload.alarms ?? event.alarms,
      recurrenceRules: payload.recurrenceRules ?? event.recurrenceRules,
      attendees: attendees ?? event.attendees
    )
  }

  private static func aadDate(for event: CalendarEvent) -> String {
    event.lastModifiedDate ?? event.creationDate ?? ""
  }
}
