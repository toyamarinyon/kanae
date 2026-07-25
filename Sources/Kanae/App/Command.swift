import Foundation

enum KanaeError: Error, CustomStringConvertible {
    case invalidArguments
    case accessibilityPermissionRequired
    case eventTapCreationFailed
    case runLoopSourceCreationFailed

    var description: String {
        switch self {
        case .invalidArguments:
            return "invalid arguments"
        case .accessibilityPermissionRequired:
            return "Accessibility permission is required. Enable it in System Settings > Privacy & Security > Accessibility."
        case .eventTapCreationFailed:
            return "Failed to create keyboard event tap. Check Accessibility permission."
        case .runLoopSourceCreationFailed:
            return "Failed to create run loop source for keyboard event tap."
        }
    }
}

func usage(progname: String) -> String {
    """
    Usage:
      \(progname) [run [--verbose]]
      \(progname) install [--no-open] [--no-start] [--wait-accessibility <seconds>]
      \(progname) status
      \(progname) uninstall
      \(progname) restart
      \(progname) stop
    """
}

enum KanaeCommand {
    case run(verbose: Bool)
    case status
    case accessibilityStatus(resultFile: String?)
    case install(
        noOpen: Bool,
        noStart: Bool,
        waitAccessibilitySeconds: Int
    )
    case uninstall
    case restart
    case stop
}

func parseArguments(_ arguments: [String]) throws -> KanaeCommand {
    let args = Array(arguments.dropFirst())

    if args.isEmpty {
        return .run(verbose: false)
    }

    guard let command = args.first else { throw KanaeError.invalidArguments }

    if command == "run" {
        if args.count == 1 {
            return .run(verbose: false)
        }
        if args.count == 2, args[1] == "--verbose" {
            return .run(verbose: true)
        }
        throw KanaeError.invalidArguments
    }

    switch command {
    case "install":
        var noOpen = false
        var noStart = false
        var waitAccessibilitySeconds = 120
        var didSetWaitAccessibility = false

        var index = 1
        while index < args.count {
            let flag = args[index]
            switch flag {
            case "--no-open":
                if noOpen {
                    throw KanaeError.invalidArguments
                }
                noOpen = true
            case "--no-start":
                if noStart {
                    throw KanaeError.invalidArguments
                }
                noStart = true
            case "--wait-accessibility":
                if didSetWaitAccessibility {
                    throw KanaeError.invalidArguments
                }
                if index + 1 >= args.count {
                    throw KanaeError.invalidArguments
                }
                guard let value = Int(args[index + 1]), value >= 0 else {
                    throw KanaeError.invalidArguments
                }
                waitAccessibilitySeconds = value
                didSetWaitAccessibility = true
                index += 1
            default:
                throw KanaeError.invalidArguments
            }
            index += 1
        }

        return .install(
            noOpen: noOpen,
            noStart: noStart,
            waitAccessibilitySeconds: waitAccessibilitySeconds
        )
    case "__accessibility-status":
        if args.count == 1 {
            return .accessibilityStatus(resultFile: nil)
        }
        guard args.count == 3 else {
            throw KanaeError.invalidArguments
        }
        guard args[1] == "--result-file" else {
            throw KanaeError.invalidArguments
        }
        return .accessibilityStatus(resultFile: args[2])
    case "uninstall":
        guard args.count == 1 else { throw KanaeError.invalidArguments }
        return .uninstall
    case "status":
        guard args.count == 1 else { throw KanaeError.invalidArguments }
        return .status
    case "restart":
        guard args.count == 1 else { throw KanaeError.invalidArguments }
        return .restart
    case "stop":
        guard args.count == 1 else { throw KanaeError.invalidArguments }
        return .stop
    default:
        throw KanaeError.invalidArguments
    }
}
