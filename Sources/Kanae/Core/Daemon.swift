@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation

private struct KeyState {
    var isPressed = false
    var sawOtherKey = false
}

final class LauncherState {
    private let leftCommandKeyCode: CGKeyCode = 55
    private let rightCommandKeyCode: CGKeyCode = 54
    private let eisuKeyCode: CGKeyCode = 102
    private let kanaKeyCode: CGKeyCode = 104
    private let relevantFlags: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]

    private let bindings: [ResolvedBinding]
    private let verbose: Bool
    private var commandStates: [CGKeyCode: KeyState] = [55: KeyState(), 54: KeyState()]

    init(bindings: [ResolvedBinding], verbose: Bool) {
        self.bindings = bindings
        self.verbose = verbose
    }

    private func log(_ message: String) {
        guard verbose else { return }
        writeStderr("kanae: \(message)\n")
    }

    func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        switch type {
        case .keyDown:
            if keyCode != leftCommandKeyCode && keyCode != rightCommandKeyCode {
                markCommandTapsCancelled()
                handlePress(event: event, keyCode: keyCode)
            }
        case .flagsChanged:
            if keyCode == leftCommandKeyCode || keyCode == rightCommandKeyCode {
                if commandStates[keyCode]?.isPressed == true {
                    handleCommandRelease(keyCode)
                } else {
                    handleCommandPress(keyCode)
                }
            }
        default: break
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleCommandPress(_ keyCode: CGKeyCode) {
        let otherKeyCode = keyCode == leftCommandKeyCode ? rightCommandKeyCode : leftCommandKeyCode
        let otherWasPressed = commandStates[otherKeyCode]?.isPressed == true
        if otherWasPressed { commandStates[otherKeyCode]?.sawOtherKey = true }
        commandStates[keyCode] = KeyState(isPressed: true, sawOtherKey: otherWasPressed)
        log("received Command press keyCode=\(keyCode)")
    }

    private func markCommandTapsCancelled() {
        for keyCode in [leftCommandKeyCode, rightCommandKeyCode] where commandStates[keyCode]?.isPressed == true {
            commandStates[keyCode]?.sawOtherKey = true
        }
    }

    private func handleCommandRelease(_ keyCode: CGKeyCode) {
        let state = commandStates[keyCode] ?? KeyState()
        commandStates[keyCode] = KeyState()
        log(
            "received Command release keyCode=\(keyCode) " +
            "isPressed=\(state.isPressed) cancelled=\(state.sawOtherKey)"
        )
        guard state.isPressed, !state.sawOtherKey else { return }
        let candidates = bindings.filter {
            if case let .tap(bindingKeyCode) = $0.trigger { return bindingKeyCode == keyCode }
            return false
        }
        executeFirstApplicable(candidates)
    }

    private func handlePress(event: CGEvent, keyCode: CGKeyCode) {
        guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }
        let flags = event.flags.intersection(relevantFlags)
        let candidates = bindings.filter {
            if case let .press(bindingKeyCode, bindingFlags) = $0.trigger {
                return bindingKeyCode == keyCode && bindingFlags == flags
            }
            return false
        }
        executeFirstApplicable(candidates)
    }

    private func executeFirstApplicable(_ candidates: [ResolvedBinding]) {
        guard !candidates.isEmpty else { return }
        var frontmostPID: pid_t?
        for binding in candidates {
            if let process = binding.process {
                if frontmostPID == nil { frontmostPID = frontmostApplicationProcessID() }
                guard let pid = frontmostPID, processTree(rootedAt: pid, contains: process) else { continue }
            }
            log("executing action=\(binding.action == .ascii ? "ascii" : "kana")")
            postTapKey(binding.action == .ascii ? eisuKeyCode : kanaKeyCode)
            return
        }
        log("matching bindings were not applicable to the frontmost process")
    }

    private func postTapKey(_ keyCode: CGKeyCode) {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            log("failed to create synthetic key events keyCode=\(keyCode)")
            return
        }
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        log("posted synthetic key tap keyCode=\(keyCode)")
    }
}

func createEventTap(state: LauncherState) throws -> CFMachPort {
    let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
    let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        return Unmanaged<LauncherState>.fromOpaque(userInfo).takeUnretainedValue().handle(event: event, type: type)
    }
    guard let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
        eventsOfInterest: CGEventMask(mask), callback: callback,
        userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(state).toOpaque())
    ) else { throw KanaeError.eventTapCreationFailed }
    return eventTap
}

func runDaemon(verbose: Bool = false) throws {
    let result = loadBindings(fromFile: configFilePath())
    let state = LauncherState(bindings: result.bindings, verbose: verbose)
    guard checkAccessibilityPermission() else { throw KanaeError.accessibilityPermissionRequired }
    let eventTap = try createEventTap(state: state)
    guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
        throw KanaeError.runLoopSourceCreationFailed
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    if verbose {
        writeStderr("kanae: event tap started options=listenOnly bindings=\(result.bindings.count)\n")
    }
    CFRunLoopRun()
}
