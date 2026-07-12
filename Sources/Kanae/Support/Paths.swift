import Foundation
import Darwin

nonisolated(unsafe) private let setupDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

func envOverride(_ name: String) -> String? {
    guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
        return nil
    }
    return value
}

func userHomeDirectory() -> String {
    FileManager.default.homeDirectoryForCurrentUser.path
}

func defaultInstallRoot() -> String {
    envOverride("KANAE_INSTALL_ROOT") ?? userHomeDirectory().appending("/Applications/kanae")
}

func defaultLaunchAgentDirectory() -> String {
    envOverride("KANAE_LAUNCH_AGENT_DIR") ?? userHomeDirectory().appending("/Library/LaunchAgents")
}

func stateDirectoryPath() -> String {
    envOverride("KANAE_STATE_DIR") ?? userHomeDirectory().appending("/.local/state/kanae")
}

func configDirectoryPath() -> String {
    envOverride("KANAE_CONFIG_DIR") ?? userHomeDirectory().appending("/.config/kanae")
}

func configFilePath() -> String {
    configDirectoryPath().appending("/config.json")
}

func standardOutputLogPath() -> String {
    stateDirectoryPath().appending("/kanae.log")
}

func standardErrorLogPath() -> String {
    stateDirectoryPath().appending("/kanae.err.log")
}

func setupLogPath() -> String {
    stateDirectoryPath().appending("/setup.log")
}

func setupLogPrefix() -> String {
    setupDateFormatter.string(from: Date())
}

func writeSetupLog(_ path: String, _ message: String) {
    let data = (message + "\n").data(using: .utf8) ?? Data()
    do {
        if let handle = try? FileHandle(forUpdating: URL(fileURLWithPath: path)) {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            handle.closeFile()
            return
        }
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    } catch {
        // Best-effort setup logging.
    }
}

func installedAppPath() -> String {
    defaultInstallRoot().appending("/Kanae.app")
}

func installedAppExecutablePath() -> String {
    installedAppPath().appending("/Contents/MacOS/Kanae")
}

func installedAppInfoPlistPath() -> String {
    installedAppPath().appending("/Contents/Info.plist")
}

func installedBinaryPath() -> String {
    defaultInstallRoot().appending("/bin/kanae")
}

func launchAgentPlistPath() -> String {
    defaultLaunchAgentDirectory().appending("/dev.ultrahope.kanae.plist")
}

func launchctlLabel() -> String {
    "dev.ultrahope.kanae"
}

func launchctlDomain() -> String {
    "gui/\(getuid())"
}

func launchctlServiceTarget() -> String {
    "\(launchctlDomain())/\(launchctlLabel())"
}

func ensureDirectory(atPath path: String) throws {
    let fm = FileManager.default
    if !fm.fileExists(atPath: path) {
        try fm.createDirectory(atPath: path, withIntermediateDirectories: true)
    }
}
