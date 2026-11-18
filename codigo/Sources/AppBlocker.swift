import AppKit

// Only validated app bundles selected by the user; no shell commands or force quit.
final class ApplicationGuard {
    private var firstSeen: [pid_t: Double] = [:]
    private var lastRequest: [pid_t: Double] = [:]
    func enforce(session: FocusSession?, now: Double) -> String? {
        guard let session, !session.expired(at: now) else {
            firstSeen.removeAll(); lastRequest.removeAll(); return nil
        }
        let targets = session.applications ?? (session.blockWhatsAppApp == true ? BlockConfiguration.initial().applications : [])
        let validTargets = targets.compactMap { try? $0.validated() }
        let hasInvalidTarget = validTargets.count != targets.count
        guard !validTargets.isEmpty else { return hasInvalidTarget ? "failed" : nil }
        let apps = validTargets.flatMap { target in
            NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).filter {
                !$0.isTerminated && $0.bundleURL?.standardizedFileURL.resolvingSymlinksInPath().path == target.path
            }
        }
        let pids = Set(apps.map(\.processIdentifier))
        firstSeen = firstSeen.filter { pids.contains($0.key) }
        lastRequest = lastRequest.filter { pids.contains($0.key) }
        for app in apps {
            let pid = app.processIdentifier
            if firstSeen[pid] == nil { firstSeen[pid] = now }
            if now - (lastRequest[pid] ?? 0) >= 2 {
                _ = app.terminate() // Normal quit; never force-kill or touch messages.
                lastRequest[pid] = now
            }
        }
        if hasInvalidTarget { return "failed" }
        if apps.isEmpty { return "closed" }
        if firstSeen.values.contains(where: { now - $0 > 5 }) { return "failed" }
        return "closing"
    }
}
