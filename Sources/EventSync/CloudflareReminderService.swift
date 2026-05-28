import EventModels
import Foundation

// MARK: - Encrypted Carrier

/// JSON-serializable container that carries an encrypted payload and its IV
/// inside a single plaintext field (the Reminder `notes` or CalendarEvent `notes`).
/// The version tag prevents false positives when plain notes happen to be valid JSON.
struct EncryptedCarrier: Codable, Sendable {
  let v: Int
  let p: String
  let i: String

  static let currentVersion = 1

  init(p: String, i: String) {
    self.v = Self.currentVersion
    self.p = p
    self.i = i
  }

  func toJSONString() throws -> String {
    let data = try JSONEncoder().encode(self)
    return String(decoding: data, as: UTF8.self)
  }

  static func fromJSON(_ json: String) -> EncryptedCarrier? {
    guard let data = json.data(using: .utf8) else { return nil }
    guard let carrier = try? JSONDecoder().decode(EncryptedCarrier.self, from: data) else {
      return nil
    }
    guard carrier.v == currentVersion else { return nil }
    return carrier
  }
}

// MARK: - Cloudflare Reminder Service

public actor CloudflareReminderService: RemindersBackend {
  private let client: D1Client
  private let encryption: EncryptionService

  public init(client: D1Client, encryption: EncryptionService) {
    self.client = client
    self.encryption = encryption
  }

  // MARK: - Fetch

  public func fetchReminders(
    listName: String?,
    showCompleted: Bool
  ) async throws -> [Reminder] {
    let all = try await client.pullAllReminders()
    var filtered = all
    if let listName {
      filtered = filtered.filter { $0.list == listName }
    }
    if !showCompleted {
      filtered = filtered.filter { !$0.isCompleted }
    }
    return try await decryptReminders(filtered)
  }

  public func fetchReminder(byId id: String) async throws -> Reminder {
    let all = try await client.pullAllReminders()
    guard let reminder = all.first(where: { $0.id == id }) else {
      throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
    }
    let decrypted = try await decryptReminders([reminder])
    return decrypted[0]
  }

  // MARK: - Create

  public func createReminder(_ params: CreateReminderParams) async throws -> Reminder {
    let now = ISO8601DateFormatter.eventISO8601.string(from: Date())
    let id = UUID().uuidString

    let listName = params.listName ?? "Reminders"
    let plainReminder = Reminder(
      id: id,
      title: params.title,
      isCompleted: false,
      isFlagged: false,
      list: listName,
      notes: params.notes,
      url: params.url,
      location: nil,
      timeZone: TimeZone.current.identifier,
      dueDate: params.dueDate,
      startDate: params.startDate,
      completionDate: nil,
      creationDate: now,
      lastModifiedDate: now,
      externalId: nil,
      priority: params.priority,
      alarms: nil,
      recurrenceRules: nil,
      locationTrigger: nil
    )

    let d1Reminder = try await encryptReminder(plainReminder)
    _ = try await client.pushReminders([d1Reminder], idOverrides: [:], lastModifiedByRemoteId: [:])
    return plainReminder
  }

  // MARK: - Update

  public func updateReminder(
    id: String,
    params: UpdateReminderParams
  ) async throws -> Reminder {
    let all = try await client.pullAllReminders()
    guard let encrypted = all.first(where: { $0.id == id }) else {
      throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
    }

    let decrypted = try await decryptReminders([encrypted])
    let existing = decrypted[0]
    let now = ISO8601DateFormatter.eventISO8601.string(from: Date())

    let updatedPlain = Reminder(
      id: existing.id,
      title: params.title ?? existing.title,
      isCompleted: params.completed ?? existing.isCompleted,
      isFlagged: existing.isFlagged,
      list: existing.list,
      notes: params.notes ?? existing.notes,
      url: params.url ?? existing.url,
      location: existing.location,
      timeZone: existing.timeZone,
      dueDate: params.clearDue ? nil : (params.dueDate ?? existing.dueDate),
      startDate: params.clearStart ? nil : (params.startDate ?? existing.startDate),
      completionDate: (params.completed ?? existing.isCompleted)
        ? (existing.completionDate ?? now) : nil,
      creationDate: existing.creationDate,
      lastModifiedDate: now,
      externalId: existing.externalId,
      priority: params.priority ?? existing.priority,
      alarms: existing.alarms,
      recurrenceRules: existing.recurrenceRules,
      locationTrigger: existing.locationTrigger
    )

    let d1Reminder = try await encryptReminder(updatedPlain)
    _ = try await client.pushReminders([d1Reminder], idOverrides: [:], lastModifiedByRemoteId: [:])
    return updatedPlain
  }

  // MARK: - Delete

  public func deleteReminder(id: String) async throws {
    try await client.deleteReminder(
      id: id,
      lastModified: ISO8601DateFormatter.eventISO8601.string(from: Date())
    )
  }

  // MARK: - Encryption Helpers

  /// Encrypts the sensitive fields of a plain Reminder, returning a D1-ready
  /// Reminder whose `notes` carries the EncryptedCarrier JSON and whose other
  /// sensitive fields are nil.
  private func encryptReminder(_ reminder: Reminder) async throws -> Reminder {
    let payload = EncryptedPayload(
      notes: reminder.notes,
      url: reminder.url,
      location: reminder.location,
      alarms: reminder.alarms,
      recurrenceRules: reminder.recurrenceRules
    )

    guard !payload.isEmpty else { return reminder }

    let aadDate = Self.aadDate(for: reminder)
    let encrypted = try await encryption.encrypt(
      payload, recordId: reminder.id, modifiedDate: aadDate
    )

    let carrier = EncryptedCarrier(p: encrypted.encryptedPayload, i: encrypted.encryptedIV)
    let carrierJSON = try carrier.toJSONString()

    return Reminder(
      id: reminder.id,
      title: reminder.title,
      isCompleted: reminder.isCompleted,
      isFlagged: reminder.isFlagged,
      list: reminder.list,
      notes: carrierJSON,
      url: nil,
      location: nil,
      timeZone: reminder.timeZone,
      dueDate: reminder.dueDate,
      startDate: reminder.startDate,
      completionDate: reminder.completionDate,
      creationDate: reminder.creationDate,
      lastModifiedDate: reminder.lastModifiedDate,
      externalId: reminder.externalId,
      priority: reminder.priority,
      alarms: nil,
      recurrenceRules: nil,
      locationTrigger: reminder.locationTrigger
    )
  }

  private func decryptReminders(_ reminders: [Reminder]) async throws -> [Reminder] {
    var result: [Reminder] = []
    result.reserveCapacity(reminders.count)
    for reminder in reminders {
      result.append(try await decryptReminder(reminder))
    }
    return result
  }

  private func decryptReminder(_ reminder: Reminder) async throws -> Reminder {
    guard let notes = reminder.notes,
      let carrier = EncryptedCarrier.fromJSON(notes)
    else {
      return reminder
    }

    let aadDate = Self.aadDate(for: reminder)
    let payload = try await encryption.decrypt(
      carrier.p,
      iv: carrier.i,
      recordId: reminder.id,
      modifiedDate: aadDate
    )

    return Reminder(
      id: reminder.id,
      title: reminder.title,
      isCompleted: reminder.isCompleted,
      isFlagged: reminder.isFlagged,
      list: reminder.list,
      notes: payload.notes,
      url: payload.url ?? reminder.url,
      location: payload.location ?? reminder.location,
      timeZone: reminder.timeZone,
      dueDate: reminder.dueDate,
      startDate: reminder.startDate,
      completionDate: reminder.completionDate,
      creationDate: reminder.creationDate,
      lastModifiedDate: reminder.lastModifiedDate,
      externalId: reminder.externalId,
      priority: reminder.priority,
      alarms: payload.alarms ?? reminder.alarms,
      recurrenceRules: payload.recurrenceRules ?? reminder.recurrenceRules,
      locationTrigger: reminder.locationTrigger
    )
  }

  private static func aadDate(for reminder: Reminder) -> String {
    reminder.lastModifiedDate ?? reminder.creationDate ?? ""
  }
}
