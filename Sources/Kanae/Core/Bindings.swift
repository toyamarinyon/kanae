import CoreGraphics
import Foundation

struct Binding: Decodable {
    struct Trigger: Decodable {
        let gesture: String
        let key: String
        let modifiers: [String]?
    }

    let trigger: Trigger
    let action: String
    let process: String?
}

enum BindingAction: Equatable {
    case ascii
    case kana
}

enum ResolvedTrigger {
    case tap(keyCode: CGKeyCode)
    case press(keyCode: CGKeyCode, flags: CGEventFlags)
}

struct ResolvedBinding {
    let trigger: ResolvedTrigger
    let action: BindingAction
    let process: String?
}

enum ConfigLoadStatus {
    case missing
    case loaded(valid: Int, invalid: Int)
    case failed(String)
}

struct BindingLoadResult {
    let bindings: [ResolvedBinding]
    let status: ConfigLoadStatus
}

private let tapKeyCodesByName: [String: CGKeyCode] = [
    "left_cmd": 55,
    "right_cmd": 54,
]

// ANSI virtual keycodes are physical positions, so presses match regardless
// of the input source that is active at the time.
private let pressKeyCodesByName: [String: CGKeyCode] = [
    "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
    "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
    "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11,
    "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17,
    "9": 0x19, "7": 0x1A, "8": 0x1C, "0": 0x1D,
    "o": 0x1F, "u": 0x20, "i": 0x22, "p": 0x23,
    "l": 0x25, "j": 0x26, "k": 0x28, "n": 0x2D, "m": 0x2E,
    "space": 0x31,
]

private let modifierMasksByName: [String: CGEventFlags] = [
    "ctrl": .maskControl, "control": .maskControl,
    "cmd": .maskCommand, "command": .maskCommand,
    "shift": .maskShift,
    "alt": .maskAlternate, "option": .maskAlternate,
]

private enum BindingResolution {
    case success(ResolvedBinding)
    case failure(String)
}

private func resolve(_ binding: Binding) -> BindingResolution {
    let action: BindingAction
    switch binding.action.lowercased() {
    case "ascii": action = .ascii
    case "kana": action = .kana
    default: return .failure("unrecognized action \"\(binding.action)\"")
    }

    if let process = binding.process,
       process.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .failure("process must not be empty or whitespace")
    }

    let gesture = binding.trigger.gesture.lowercased()
    let key = binding.trigger.key.lowercased()
    let trigger: ResolvedTrigger
    switch gesture {
    case "tap":
        guard let keyCode = tapKeyCodesByName[key] else {
            return .failure("key \"\(binding.trigger.key)\" is not supported for tap")
        }
        if !(binding.trigger.modifiers ?? []).isEmpty {
            return .failure("tap does not accept modifiers")
        }
        trigger = .tap(keyCode: keyCode)
    case "press":
        guard let keyCode = pressKeyCodesByName[key] else {
            return .failure("key \"\(binding.trigger.key)\" is not supported for press")
        }
        var flags: CGEventFlags = []
        var seen: Set<UInt64> = []
        for name in binding.trigger.modifiers ?? [] {
            guard let mask = modifierMasksByName[name.lowercased()] else {
                return .failure("unrecognized modifier \"\(name)\"")
            }
            guard seen.insert(mask.rawValue).inserted else {
                return .failure("duplicate modifier \"\(name)\"")
            }
            flags.insert(mask)
        }
        trigger = .press(keyCode: keyCode, flags: flags)
    default:
        return .failure("unrecognized gesture \"\(binding.trigger.gesture)\"")
    }

    return .success(ResolvedBinding(trigger: trigger, action: action, process: binding.process))
}

func loadBindings(
    fromFile path: String,
    report: (String) -> Void = { writeStderr("kanae: \($0)\n") }
) -> BindingLoadResult {
    let fm = FileManager.default
    guard fm.fileExists(atPath: path) else {
        return BindingLoadResult(bindings: [], status: .missing)
    }
    guard let data = fm.contents(atPath: path) else {
        let message = "failed to read config file: \(path)"
        report(message)
        return BindingLoadResult(bindings: [], status: .failed(message))
    }

    let entries: [Any]
    do {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bindings = root["bindings"] as? [Any] else {
            throw NSError(domain: "KanaeConfig", code: 1, userInfo: [NSLocalizedDescriptionKey: "top level must contain a bindings array"])
        }
        entries = bindings
    } catch {
        let message = "failed to parse config file \(path): \(error.localizedDescription)"
        report(message)
        return BindingLoadResult(bindings: [], status: .failed(message))
    }

    var resolved: [ResolvedBinding] = []
    var invalid = 0
    for (index, entry) in entries.enumerated() {
        do {
            let data = try JSONSerialization.data(withJSONObject: entry)
            let binding = try JSONDecoder().decode(Binding.self, from: data)
            switch resolve(binding) {
            case let .success(value): resolved.append(value)
            case let .failure(reason):
                invalid += 1
                report("skipping binding at index \(index): \(reason)")
            }
        } catch {
            invalid += 1
            report("skipping binding at index \(index): \(error.localizedDescription)")
        }
    }
    return BindingLoadResult(bindings: resolved, status: .loaded(valid: resolved.count, invalid: invalid))
}

let defaultConfigJSON = """
{
  "bindings": [
    {
      "trigger": {
        "gesture": "tap",
        "key": "left_cmd"
      },
      "action": "ascii"
    },
    {
      "trigger": {
        "gesture": "tap",
        "key": "right_cmd"
      },
      "action": "kana"
    }
  ]
}
"""
