import Foundation

@main
struct GoalsTests {
    static func main() throws {
        let previousZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
        defer { NSTimeZone.default = previousZone }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("FocoGoals-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FocusStore(directory: dir)
        let t = 1_800_000_000.0
        let day = Date(timeIntervalSince1970: t)
        func connect(_ now: Double) throws { try store.acknowledge(profile: "test", appliedID: "", error: nil, now: now) }
        func seconds(_ id: String, _ state: FocusState, _ now: Double = t + 10_000) -> Double {
            GoalMetrics(state: state, goalID: id, now: Date(timeIntervalSince1970: now)).seconds
        }
        let legacy = try JSONDecoder().decode(FocusState.self, from: Data("{\"records\":[],\"bridgeSeen\":0,\"appliedID\":\"\",\"revision\":0}".utf8))
        precondition(legacy.goals == nil)
        let legacyRecord = try JSONDecoder().decode(FocusRecord.self, from: Data("{\"id\":\"old\",\"startedAt\":0,\"seconds\":60,\"completed\":false}".utf8))
        precondition(legacyRecord.goalID == nil)
        let first = try store.addGoal(title: "  Aprobar IPSC  ", targetHours: 2, now: t)
        precondition(first.title == "Aprobar IPSC" && first.targetSeconds == 7200 && first.outcome == nil)
        for hours in [0.0, -1, .infinity, .nan, 100_001] {
            do { _ = try store.addGoal(title: "Invalid", targetHours: hours, now: t); fatalError("Invalid hours accepted") }
            catch FocusGoalError.hours {}
        }
        do { _ = try store.addGoal(title: "bad\nname", targetHours: nil); fatalError("Multiline title accepted") }
        catch FocusGoalError.title {}
        let second = try store.addGoal(title: "Tecnología", targetHours: nil, now: t + 1)
        let a = try store.addTask(title: "Teoría", day: day, goalID: first.id, now: t + 1)
        let b = try store.addTask(title: "Parciales", day: day, goalID: first.id, now: t + 2)
        try connect(t + 10)
        try store.start(duration: nil, firm: false, taskID: a.id, now: t + 10)
        try store.setPaused(true, now: t + 40)
        try store.setPaused(false, now: t + 100)
        try store.stop(now: t + 130)
        var state = try store.read(now: t + 130)
        precondition(state.records.first?.goalID == first.id && state.records.first?.seconds == 60)
        try connect(t + 150)
        try store.start(duration: nil, firm: false, goalID: first.id, now: t + 150)
        try store.stop(now: t + 210)
        state = try store.read(now: t + 210)
        precondition(state.records.first?.taskID == nil && seconds(first.id, state) == 120, "Direct and task blocks count once")
        try connect(t + 220)
        try store.start(duration: nil, firm: false, taskID: b.id, now: t + 220)
        try store.setPaused(true, now: t + 250)
        state = try store.read(now: t + 300)
        precondition(seconds(first.id, state, t + 300) == 150, "Running paused block excludes break")
        let clipped = GoalMetrics(state: state, goalID: first.id, now: Date(timeIntervalSince1970: t + 300), interval: DateInterval(start: Date(timeIntervalSince1970: t + 230), end: Date(timeIntervalSince1970: t + 300)))
        precondition(clipped.seconds == 20)
        do { try store.editTask(id: b.id, title: b.title, day: day, goal: .set(second.id, includePrevious: false)); fatalError("Moved running task") }
        catch FocusTaskError.active {}
        try store.setPaused(false, now: t + 310)
        try store.stop(now: t + 340)
        try store.editTask(id: a.id, title: a.title, day: day, goal: .set(second.id, includePrevious: false))
        try connect(t + 350)
        do { try store.start(duration: nil, firm: false, taskID: a.id, goalID: first.id, now: t + 350); fatalError("Conflicting goal accepted") }
        catch FocusGoalError.conflict {}
        try store.start(duration: nil, firm: false, taskID: a.id, now: t + 350)
        try store.stop(now: t + 410)
        state = try store.read(now: t + 410)
        precondition(seconds(first.id, state) == 180 && seconds(second.id, state) == 60, "Moving task keeps historical attribution")
        let c = try store.addTask(title: "Bloque previo", day: day, now: t + 420)
        try connect(t + 420)
        try store.start(duration: nil, firm: false, taskID: c.id, now: t + 420)
        try store.stop(now: t + 480)
        try store.editTask(id: c.id, title: c.title, day: day, goal: .set(first.id, includePrevious: false))
        state = try store.read(now: t + 480)
        precondition(seconds(first.id, state) == 180, "No automatic historical reassignment")
        try store.editTask(id: c.id, title: c.title, day: day, goal: .set(first.id, includePrevious: true))
        try store.editTask(id: c.id, title: c.title, day: day, goal: .set(first.id, includePrevious: true))
        state = try store.read(now: t + 480)
        precondition(seconds(first.id, state) == 240, "Explicit import is idempotent")
        try store.editTask(id: c.id, title: c.title, day: day, goal: .set(second.id, includePrevious: true))
        let deletedTask = try store.deleteTask(id: c.id, now: t + 480)!
        state = try store.read(now: t + 480)
        precondition(seconds(first.id, state) == 240, "Deleting task preserves objective time")
        try store.restoreTask(deletedTask)
        try connect(t + 500)
        try store.start(duration: nil, firm: false, goalID: first.id, now: t + 500)
        do { try store.closeGoal(id: first.id, outcome: .partial, note: "", now: t + 510); fatalError("Closed running goal") }
        catch FocusGoalError.active {}
        do { _ = try store.deleteGoal(id: first.id, now: t + 510); fatalError("Deleted running goal") }
        catch FocusGoalError.active {}
        try store.stop(now: t + 560)
        try store.closeGoal(id: first.id, outcome: .partial, note: "Me faltó práctica", now: t + 600)
        try connect(t + 610)
        do { try store.start(duration: nil, firm: false, goalID: first.id, now: t + 610); fatalError("Started closed goal") }
        catch FocusGoalError.closed {}
        do { try store.start(duration: nil, firm: false, taskID: b.id, now: t + 610); fatalError("Started task of closed goal") }
        catch FocusGoalError.closed {}
        try store.closeGoal(id: first.id, outcome: .achieved, note: "Aprobado", now: t + 620)
        state = try store.read(now: t + 620)
        let result = state.goals!.first { $0.id == first.id }!
        precondition(result.outcome == .achieved && result.closedAt == t + 600 && result.resultNote == "Aprobado", "Result editable independently of hours")
        precondition(seconds(first.id, state) == 300)
        let scoped = state.filtered(forGoal: first.id)
        precondition(scoped.records.allSatisfy { $0.goalID == first.id } && scoped.session == nil)
        precondition(scoped.tasks!.contains { $0.id == a.id }, "Historical task remains visible after reassignment")
        let metrics = FocusMetrics(state: scoped, now: Date(timeIntervalSince1970: t + 700), period: .day, anchor: day, customStart: day, customEnd: day)
        precondition(metrics.total == 300, "Dashboard matches goal totals for same interval")
        let before = state.records.reduce(0) { $0 + $1.seconds }
        let deletion = try store.deleteGoal(id: first.id, now: t + 700)!
        state = try store.read(now: t + 700)
        precondition(state.records.allSatisfy { $0.goalID != first.id } && state.tasks!.allSatisfy { $0.goalID != first.id })
        precondition(state.records.reduce(0) { $0 + $1.seconds } == before)
        try store.restoreGoal(deletion)
        try store.restoreGoal(deletion)
        state = try store.read(now: t + 700)
        precondition(state.goals!.filter { $0.id == first.id }.count == 1 && seconds(first.id, state) == 300)
        let record = try store.deleteRecord(id: state.records.first!.id)!
        _ = try store.deleteGoal(id: first.id, now: t + 710)
        try store.restoreRecord(record)
        state = try store.read(now: t + 710)
        precondition(state.records.first(where: { $0.id == record.id })?.goalID == nil, "Undo record cannot resurrect a deleted goal reference")
        let small = try store.addGoal(title: "Meta breve", targetHours: 0.01, now: t + 800)
        try connect(t + 800)
        try store.start(duration: 60, firm: true, goalID: small.id, now: t + 800)
        state = try store.read(now: t + 900)
        precondition(seconds(small.id, state) == 60 && state.goals!.first(where: { $0.id == small.id })!.outcome == nil, "Hours never determine result automatically")
        try store.closeGoal(id: small.id, outcome: .notAchieved, note: "No salió", now: t + 900)
        let data = try JSONEncoder().encode(try store.read(now: t + 900))
        let decoded = try JSONDecoder().decode(FocusState.self, from: data)
        precondition(decoded.goals!.first(where: { $0.id == small.id })?.outcome == .notAchieved)
        let oldTask = try store.deleteTask(id: a.id, now: t + 950)!
        _ = try store.deleteGoal(id: second.id, now: t + 950)
        try store.restoreTask(oldTask)
        state = try store.read(now: t + 950)
        precondition(state.tasks!.first(where: { $0.id == a.id })?.goalID == nil, "Undo task cannot resurrect a deleted goal reference")
        let source = try store.addGoal(title: "Origen", targetHours: 1, now: t + 1000)
        let destination = try store.addGoal(title: "Destino", targetHours: 2, now: t + 1000)
        let moved = try store.addTask(title: "Reasignada", day: day, goalID: source.id, now: t + 1000)
        try connect(t + 1000)
        try store.start(duration: nil, firm: false, taskID: moved.id, now: t + 1000)
        try store.stop(now: t + 1060)
        let removedGoal = try store.deleteGoal(id: source.id, now: t + 1100)!
        try store.editTask(id: moved.id, title: moved.title, day: day, goal: .set(destination.id, includePrevious: true))
        try store.restoreGoal(removedGoal)
        state = try store.read(now: t + 1100)
        precondition(state.tasks!.first(where: { $0.id == moved.id })?.goalID == destination.id && seconds(destination.id, state) == 60 && seconds(source.id, state) == 0, "Undo goal never overwrites an explicit reassignment")
        do { try store.closeGoal(id: destination.id, outcome: .achieved, note: String(repeating: "x", count: 2001), now: t + 1200); fatalError("Oversized note accepted") }
        catch FocusGoalError.note {}
        let historical = state.records.first { $0.taskID == moved.id }!
        try store.assignRecordGoal(id: historical.id, goalID: small.id)
        state = try store.read(now: t + 1200)
        precondition(seconds(destination.id, state) == 0 && seconds(small.id, state) == 120, "Explicit per-block correction works for direct or closed goals")
        precondition(state.records.first(where: { $0.id == historical.id })?.seconds == historical.seconds, "Reassignment changes only the label, never the focus time")
        try store.assignRecordGoal(id: historical.id, goalID: nil)
        state = try store.read(now: t + 1200)
        precondition(seconds(small.id, state) == 60)
        do { try store.assignRecordGoal(id: historical.id, goalID: "absent"); fatalError("Missing goal accepted") }
        catch FocusGoalError.missing {}
        print("PASS goals: migration, validation, task/direct blocks, pauses, scoped metrics, snapshots, explicit history import, deletion/undo, closure guards and independent outcomes")
    }
}
