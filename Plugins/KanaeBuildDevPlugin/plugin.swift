import Foundation
import PackagePlugin

@main
struct KanaeBuildDevPlugin: CommandPlugin {
    private let productName = "kanae"
    private let appName = "KanaeDev"

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        guard arguments.isEmpty else {
            throw PluginError.unexpectedArguments(arguments)
        }

        let buildResult = try packageManager.build(
            .product(productName),
            parameters: .init(configuration: .debug, logging: .concise, echoLogs: true)
        )

        guard buildResult.succeeded else {
            throw PluginError.buildFailed(buildResult.logText)
        }

        let executable = try builtExecutable(from: buildResult)
        try assembleAppBundle(packageDirectory: context.package.directoryURL, executable: executable)
    }

    private func builtExecutable(
        from result: PackageManager.BuildResult
    ) throws -> URL {
        let executables = result.builtArtifacts.filter { artifact in
            artifact.kind == .executable
        }

        if let productExecutable = executables.first(where: {
            $0.url.lastPathComponent == productName
        }) {
            return productExecutable.url
        }

        if executables.count == 1, let executable = executables.first {
            return executable.url
        }

        throw PluginError.executableNotFound(
            executables.map { $0.url.path }.joined(separator: ", ")
        )
    }

    private func assembleAppBundle(packageDirectory: URL, executable: URL) throws {
        let fileManager = FileManager.default
        let appBundle = packageDirectory
            .appending(path: ".build", directoryHint: .isDirectory)
            .appending(path: "dev", directoryHint: .isDirectory)
            .appending(path: "\(appName).app", directoryHint: .isDirectory)
        let contents = appBundle.appending(path: "Contents", directoryHint: .isDirectory)
        let macOS = contents.appending(path: "MacOS", directoryHint: .isDirectory)

        if fileManager.fileExists(atPath: appBundle.path) {
            try fileManager.removeItem(at: appBundle)
        }

        try fileManager.createDirectory(at: macOS, withIntermediateDirectories: true)
        try fileManager.copyItem(
            at: executable,
            to: macOS.appending(path: appName, directoryHint: .notDirectory)
        )

        let infoPlist = try PropertyListSerialization.data(
            fromPropertyList: [
                "CFBundleDisplayName": appName,
                "CFBundleExecutable": appName,
                "CFBundleIdentifier": "dev.ultrahope.kanae.dev",
                "CFBundleName": appName,
                "CFBundlePackageType": "APPL",
                "LSUIElement": true,
            ],
            format: .xml,
            options: 0
        )
        try infoPlist.write(to: contents.appending(path: "Info.plist", directoryHint: .notDirectory))
    }
}

private enum PluginError: LocalizedError {
    case unexpectedArguments([String])
    case buildFailed(String)
    case executableNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .unexpectedArguments(arguments):
            "kanae-build-dev does not accept arguments: \(arguments.joined(separator: " "))"
        case let .buildFailed(log):
            "SwiftPM could not build the kanae debug executable.\n\(log)"
        case let .executableNotFound(artifacts):
            "SwiftPM did not report a kanae executable. Reported executable artifacts: \(artifacts)"
        }
    }
}
