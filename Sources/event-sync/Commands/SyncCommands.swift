import ArgumentParser
import EventCommands
import EventModels
import Foundation

// MARK: - Sync Commands (Linux / D1-only)

struct SyncCommands: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sync",
    abstract: "Sync configuration and status",
    subcommands: [SyncConfigCommand.self, SyncStatusCommand.self]
  )
}
