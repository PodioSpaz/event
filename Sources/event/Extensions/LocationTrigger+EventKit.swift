#if canImport(EventKit)

  import CoreLocation
  import EventKit
  import EventModels
  import Foundation

  extension LocationTrigger {
    init?(from ekAlarm: EKAlarm) {
      guard let structuredLocation = ekAlarm.structuredLocation,
        let geoLocation = structuredLocation.geoLocation
      else {
        return nil
      }

      let mappedProximity: Proximity
      switch ekAlarm.proximity {
      case .enter:
        mappedProximity = .enter
      case .leave:
        mappedProximity = .leave
      default:
        // `.none` means the alarm has no proximity trigger we represent.
        return nil
      }

      self.init(
        title: structuredLocation.title ?? "Location",
        latitude: geoLocation.coordinate.latitude,
        longitude: geoLocation.coordinate.longitude,
        radius: structuredLocation.radius,
        proximity: mappedProximity
      )
    }

    /// Build an `EKAlarm` carrying this trigger's structured location and proximity.
    func toEKAlarm() -> EKAlarm {
      let structuredLocation = EKStructuredLocation(title: title)
      structuredLocation.geoLocation = CLLocation(latitude: latitude, longitude: longitude)
      structuredLocation.radius = radius

      let alarm = EKAlarm()
      alarm.structuredLocation = structuredLocation
      alarm.proximity = (proximity == .leave) ? .leave : .enter
      return alarm
    }
  }

#endif
