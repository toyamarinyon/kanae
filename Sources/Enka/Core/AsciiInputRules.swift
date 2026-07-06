import CoreGraphics
import Foundation

struct AsciiInputRule: Decodable {
    let process: String
    let key: String
}

struct AsciiInputConfig: Decodable {
    let asciiInputRules: [AsciiInputRule]
}

struct ResolvedAsciiInputRule {
    let process: String
    let keyCode: CGKeyCode
    let flags: CGEventFlags
}

// ANSI virtual keycodes are tied to physical key position, not the
// character a layout produces, so chords match regardless of the active
// input source -- the same property the hardware Eisu/Kana keys rely on.
private let keyCodesByName: [String: CGKeyCode] = [
    "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
    "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
    "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11,
    "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17,
    "9": 0x19, "7": 0x1A, "8": 0x1C, "0": 0x1D,
    "o": 0x1F, "u": 0x20, "i": 0x22, "p": 0x23,
    "l": 0x25, "j": 0x26, "k": 0x28,
    "n": 0x2D, "m": 0x2E,
    "space": 0x31,
]

private let modifierMasksByName: [String: CGEventFlags] = [
    "ctrl": .maskControl,
    "control": .maskControl,
    "cmd": .maskCommand,
    "command": .maskCommand,
    "shift": .maskShift,
    "alt": .maskAlternate,
    "option": .maskAlternate,
]

func parseKeyChord(_ chord: String) -> (keyCode: CGKeyCode, flags: CGEventFlags)? {
    let parts = chord.lowercased().split(separator: "+").map(String.init)
    guard let keyName = parts.last, let keyCode = keyCodesByName[keyName] else {
        return nil
    }

    var flags: CGEventFlags = []
    for modifierName in parts.dropLast() {
        guard let mask = modifierMasksByName[modifierName] else { return nil }
        flags.insert(mask)
    }

    return (keyCode, flags)
}

/// Reads `asciiInputRules` from a JSON config file. Each rule watches a key
/// chord and, when the frontmost app's descendant process tree contains the
/// named process (see `processTree(rootedAt:contains:)`), forces the JIS
/// 英数 key -- a one-way switch to ASCII with no restore, since staying in
/// ASCII after e.g. a terminal multiplexer prefix command is the wanted
/// state. A missing config file means no rules; malformed entries are
/// skipped individually so one typo doesn't disable the whole daemon.
func loadAsciiInputRules(fromFile path: String) -> [ResolvedAsciiInputRule] {
    let fm = FileManager.default
    guard fm.fileExists(atPath: path) else { return [] }

    guard let data = fm.contents(atPath: path) else {
        writeStderr("enka: failed to read config file: \(path)\n")
        return []
    }

    let config: AsciiInputConfig
    do {
        config = try JSONDecoder().decode(AsciiInputConfig.self, from: data)
    } catch {
        writeStderr("enka: failed to parse config file \(path): \(error.localizedDescription)\n")
        return []
    }

    return config.asciiInputRules.compactMap { rule in
        guard let parsed = parseKeyChord(rule.key) else {
            writeStderr("enka: skipping rule for process \"\(rule.process)\": unrecognized key \"\(rule.key)\"\n")
            return nil
        }
        return ResolvedAsciiInputRule(process: rule.process, keyCode: parsed.keyCode, flags: parsed.flags)
    }
}
