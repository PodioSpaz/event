import ArgumentParser
import EventModels
import Foundation

// MARK: - List Commands

struct ListCommands: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "lists",
    abstract: "Manage reminder lists",
    subcommands: [List.self, Create.self, Update.self, Delete.self]
  )

  struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "List all reminder lists"
    )

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      let backend = try await BackendFactory.makeListsBackend()
      let lists = try await backend.fetchLists()

      let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
      print(formatter.format(lists))
    }
  }

  struct Create: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Create a new reminder list"
    )

    @Option(name: .shortAndLong, help: "List name")
    var name: String

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      #if canImport(EventKit)
        let service = ListService()
        let list = try await service.createList(name: name)
      #else
        let backend = try await BackendFactory.makeListsBackend()
        let list = try await backend.createList(title: name, color: nil)
      #endif

      let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
      print(formatter.format(list))
    }
  }

  struct Update: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Update an existing reminder list"
    )

    @Option(name: .shortAndLong, help: "List ID")
    var id: String

    @Option(name: .shortAndLong, help: "New list name")
    var name: String

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      #if canImport(EventKit)
        let service = ListService()
        let list = try await service.updateList(id: id, name: name)
      #else
        let backend = try await BackendFactory.makeListsBackend()
        let list = try await backend.updateList(id: id, title: name, color: nil)
      #endif

      let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
      print(formatter.format(list))
    }
  }

  struct Delete: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Delete a reminder list"
    )

    @Option(name: .shortAndLong, help: "List ID")
    var id: String

    func run() async throws {
      let backend = try await BackendFactory.makeListsBackend()
      try await backend.deleteList(id: id)
      print("List deleted successfully")
    }
  }
}
