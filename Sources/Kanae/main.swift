import Foundation
import Darwin

do {
    let arguments = CommandLine.arguments
    if shouldHandleDirectOpenInvocation() {
        handleDirectOpen()
        exit(0)
    }

    let command = try parseArguments(arguments)

    switch command {
    case .run:
        try runDaemon()
    case let .accessibilityStatus(resultFile):
        let isGranted = checkAccessibilityPermission()
        if let resultFile {
            do {
                try (isGranted ? "granted" : "not_granted").write(
                    toFile: resultFile,
                    atomically: true,
                    encoding: .utf8
                )
            } catch {
                writeStderr("kanae: failed to write accessibility status result to \(resultFile): \(error.localizedDescription)\n")
                exit(1)
            }
        }
        exit(isGranted ? 0 : 1)
    case let .install(noOpen, noStart, waitAccessibilitySeconds):
        runInstall(
            noOpen: noOpen,
            noStart: noStart,
            waitAccessibilitySeconds: waitAccessibilitySeconds
        )
    case .uninstall:
        runUninstall()
    case .status:
        printStatus()
    case .restart:
        let plist = launchAgentPlistPath()
        if !FileManager.default.fileExists(atPath: plist) {
            writeStderr("error: LaunchAgent plist missing: \(plist). Run the installer again.\n")
            exit(1)
        }
        runRestartCommands(plistPath: plist)
    case .stop:
        let plist = launchAgentPlistPath()
        if !FileManager.default.fileExists(atPath: plist) {
            writeStderr("error: LaunchAgent plist missing: \(plist). Run the installer again.\n")
            exit(1)
        }
        runStopCommands(plistPath: plist)
    }
} catch let error as KanaeError {
    if case .invalidArguments = error {
        let progname = URL(fileURLWithPath: CommandLine.arguments.first ?? "kanae").lastPathComponent
        writeStderr(usage(progname: progname) + "\n")
        writeStderr("kanae: \(error.description)\n")
        exit(64)
    }
    writeStderr("kanae: \(error.description)\n")
    exit(1)
} catch {
    writeStderr("kanae: \(error.localizedDescription)\n")
    exit(1)
}
