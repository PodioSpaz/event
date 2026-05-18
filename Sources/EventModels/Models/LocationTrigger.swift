import Foundation

// MARK: - Location Trigger Model

public struct LocationTrigger: Codable, Sendable {
  public enum Proximity: String, Codable, Sendable {
    case enter, leave
  }

  public static let defaultRadius: Double = 100

  public let title: String
  public let latitude: Double
  public let longitude: Double
  public let radius: Double
  public let proximity: Proximity

  public init(
    title: String,
    latitude: Double,
    longitude: Double,
    radius: Double,
    proximity: Proximity
  ) {
    self.title = title
    self.latitude = latitude
    self.longitude = longitude
    self.radius = Self.sanitizedRadius(radius)
    self.proximity = proximity
  }

  private static func sanitizedRadius(_ r: Double) -> Double {
    r > 0 ? r : defaultRadius
  }
}
