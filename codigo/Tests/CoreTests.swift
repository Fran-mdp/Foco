import Foundation

@main
struct CoreTests {
    static func main() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("FocoTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FocusStore(directory: dir)
        let t = 1_000_000.0
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message); checks += 1; print("PASS \(message)")
        }
        do { try store.start(duration: nil, firm: false, now: t); fatalError("Offline start allowed") }
        catch FocusError.unavailable { checks += 1; print("PASS refuses to claim blocking without Chrome") }
        try store.acknowledge(profile: "profile-A", appliedID: "", error: nil, now: t)
        do { try store.start(duration: nil, firm: true, now: t); fatalError("Firm without timer") }
        catch FocusError.invalidDuration { checks += 1; print("PASS firm requires bounded duration") }
        try store.start(duration: nil, firm: false, now: t)
        let first = try store.read(now: t + 4)
        check(first.session?.elapsed(at: t + 4) == 4, "stopwatch elapsed")
        do { try store.start(duration: 60, firm: false, now: t+1); fatalError("Overlapping sessions") }
        catch FocusError.busy { checks += 1; print("PASS overlapping start rejected") }
        try store.stop(now: t+12)
        var state = try store.read(now: t+12)
        check(state.session == nil && state.records.first?.seconds == 12, "flexible stop records actual time")
        let manualRecord = state.records.first!
        check(state.pendingQualityRecordID == manualRecord.id && manualRecord.qualityRating == nil, "manual stop queues optional rating")
        do { try store.setRecordQuality(id: manualRecord.id, rating: 11); fatalError("Invalid quality accepted") }
        catch FocusQualityError.invalidRating {}
        try store.setRecordQuality(id: manualRecord.id, rating: 8)
        state = try store.read(now: t+12)
        check(state.records.first?.qualityRating == 8 && state.pendingQualityRecordID == nil, "rating persists and resolves prompt")

        try store.acknowledge(profile: "profile-A", appliedID: "", error: nil, now: t+12)
        try store.start(duration: 60, firm: true, now: t+12)
        do { try store.stop(now: t+20); fatalError("Firm stopped early") }
        catch FocusError.firm { checks += 1; print("PASS firm rejects early stop") }
        let reloaded = FocusStore(directory: dir)
        state = try reloaded.read(now: t+30)
        check(state.session?.firm == true, "firm session survives app/host restart")
        state = try reloaded.read(now: t+100)
        check(state.session == nil && state.records.first?.seconds == 60 && state.records.first?.completed == true, "expired sessions end after sleep/restart, capped duration")
        state = try reloaded.read(now: t+101)
        check(state.records.count == 2, "expiry records session exactly once")
        let timedRecord = state.records.first!
        check(state.pendingQualityRecordID == timedRecord.id, "timed finish queues rating across store reload")
        try store.setRecordQuality(id: timedRecord.id, rating: nil)
        state = try store.read(now: t+101)
        check(state.pendingQualityRecordID == nil && state.records.first?.qualityRating == nil, "skipping leaves no score and does not reopen the prompt")

        do { try store.acknowledge(profile: "profile-B", appliedID: "", error: nil, now: t+102); fatalError("Other profile accepted") }
        catch FocusError.profile { checks += 1; print("PASS other Chrome profile rejected") }
        do { try store.start(duration: 60, firm: false, now: t+200); fatalError("Stale bridge accepted") }
        catch FocusError.unavailable { checks += 1; print("PASS stale bridge rejected") }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let ts = today.timeIntervalSince1970
        var stats = FocusState()
        stats.records = [FocusRecord(id: "crosses-midnight", startedAt: ts-100, seconds: 200, completed: true)]
        check(store.todaySeconds(now: today.addingTimeInterval(3600), state: stats) == 100, "daily total clips sessions at midnight")
        try store.acknowledge(profile: "profile-A", appliedID: "", error: nil, now: t+300)
        try store.start(duration: 60, firm: true, now: t+300)
        try store.setPaused(true, now: t+310)
        try store.setPaused(true, now: t+320)
        state = try reloaded.read(now: t+1000)
        check(state.session?.elapsed(at: t+1000) == 10 && state.session?.remaining(at: t+1000) == 50, "pause survives reload and freezes both clocks")
        do { try store.stop(now: t+1000); fatalError("Paused firm stopped") }
        catch FocusError.firm { checks += 1 }
        try store.setPaused(false, now: t+1000)
        try store.setPaused(false, now: t+1001)
        state = try store.read(now: t+1049)
        check(state.session?.elapsed(at: t+1049) == 59, "resume preserves active time without double counting")
        state = try store.read(now: t+1050)
        check(state.session == nil && state.records.first?.seconds == 60, "timed session expires after active duration only")
        let pausedRecord = state.records.first!
        check(pausedRecord.activeIntervals.count == 2, "record retains separate focus intervals")
        let removed = try store.deleteRecord(id: pausedRecord.id)!
        check((try store.read(now: t+1050)).records.count == 2, "individual delete preserves other sessions")
        try store.restoreRecord(removed)
        try store.restoreRecord(removed)
        check((try store.read(now: t+1050)).records.count == 3, "undo restores once")
        var paused = FocusState()
        paused.records = [FocusRecord(id: "pause-midnight", startedAt: ts-100, seconds: 100, completed: false, intervals: [FocusInterval(start: ts-100, end: ts-50), FocusInterval(start: ts+100, end: ts+150)])]
        check(store.todaySeconds(now: today.addingTimeInterval(3600), state: paused) == 50, "daily totals exclude pause across midnight")
        try Data("broken".utf8).write(to: dir.appendingPathComponent("state.json"))
        do { _ = try store.read(); fatalError("Corrupt state reset silently") }
        catch FocusError.corrupt { checks += 1; print("PASS corrupt state fails visibly") }
        check(clockString(3661) == "1:01:01", "long sessions display hours")
        print("\(checks) checks passed. No real browser or system blocking was enabled.")
    }
}
