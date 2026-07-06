import AppKit
import Darwin

func frontmostApplicationProcessID() -> pid_t? {
    NSWorkspace.shared.frontmostApplication?.processIdentifier
}

func processName(ofPID pid: pid_t) -> String? {
    var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    let length = proc_name(pid, &buffer, UInt32(buffer.count))
    guard length > 0 else { return nil }
    return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
}

private func childProcessIDs(ofPID pid: pid_t) -> [pid_t] {
    // A NULL buffer makes proc_listchildpids return a generous byte-size
    // hint for allocation. With a real buffer, the return value is instead
    // the number of pids written (not bytes) -- the two calls are not
    // symmetric, so only the second return value is used as a count.
    let sizeHint = proc_listchildpids(pid, nil, 0)
    guard sizeHint > 0 else { return [] }

    let capacity = Int(sizeHint) / MemoryLayout<pid_t>.size + 8
    var buffer = [pid_t](repeating: 0, count: capacity)
    let count = buffer.withUnsafeMutableBytes { rawBuffer in
        proc_listchildpids(pid, rawBuffer.baseAddress, Int32(rawBuffer.count))
    }
    guard count > 0 else { return [] }

    return Array(buffer.prefix(Int(count)))
}

/// Walks descendant processes looking for `target` by exact process name.
/// herdr runs as a child (often a few levels down, past login shells or
/// tmux) of the frontmost terminal app, not as its own frontmost app, so a
/// plain frontmost-app check can't tell whether herdr is actually running.
func processTree(rootedAt pid: pid_t, contains target: String, maxDepth: Int = 12) -> Bool {
    guard maxDepth > 0 else { return false }

    for child in childProcessIDs(ofPID: pid) {
        if processName(ofPID: child) == target {
            return true
        }
        if processTree(rootedAt: child, contains: target, maxDepth: maxDepth - 1) {
            return true
        }
    }
    return false
}
