import Foundation

public enum SyncCursorPolicy {
  public static func nextCursor(
    currentCursor: String?,
    responseCursor: String,
    hadFailures: Bool
  ) -> String {
    if hadFailures {
      return currentCursor ?? responseCursor
    }
    return responseCursor
  }
}
