import Foundation
import PackagePlugin

@main
struct GitVersionPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
    let outputDir = context.pluginWorkDirectoryURL
    let outputFile = outputDir.appending(path: "GeneratedVersion.swift")
    let script = context.package.directoryURL.appending(
      path: "Plugins/GitVersionPlugin/generate-version.sh")

    return [
      .prebuildCommand(
        displayName: "Generate CLI version from git",
        executable: URL(fileURLWithPath: "/bin/sh"),
        arguments: [script.path, context.package.directoryURL.path, outputFile.path],
        outputFilesDirectory: outputDir
      )
    ]
  }
}
