import Foundation

@main
struct TasksTests {
    static func main() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("FocoTasks-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FocusStore(directory: dir)
        let today = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let t = today.timeIntervalSince1970 + 3600
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let task = try store.addTask(title: "  Study scheduling  ", day: today, now: t)
        precondition(task.title == "Study scheduling")
        let idle = try store.addTask(title: "Read notes", day: today, now: t)
        do { _ = try store.addTask(title: "bad\nname", day: today); fatalError("Multiline title accepted") }
        catch FocusTaskError.invalidTitle {}
        try store.acknowledge(profile: "test", appliedID: "", error: nil, now: t)
        try store.start(duration: nil, firm: false, taskID: task.id, now: t)
        try store.setPaused(true, now: t+20)
        try store.setPaused(false, now: t+100)
        do { try store.setTaskCompleted(id: task.id, completed: true, now: t+110); fatalError("Completed running task") }
        catch FocusTaskError.active {}
        try store.stop(now: t+130)
        var state = try store.read(now: t+130)
        precondition(state.records.first?.taskID == task.id && state.records.first?.seconds == 50)
        try store.acknowledge(profile: "test", appliedID: "", error: nil, now: t+200)
        try store.start(duration: 60, firm: true, taskID: task.id, now: t+200)
        state = try store.read(now: t+300)
        var report = TaskMetrics(state: state, now: Date(timeIntervalSince1970: t+300), interval: Calendar.current.dateInterval(of: .day, for: today)!)
        precondition(report.seconds(for: task.id) == 110 && report.pending == 2 && report.completed == 0, "Multiple blocks accumulate without completing task")
        precondition(report.percent(for: task) == 0 && report.activity(for: idle) == "Sin actividad registrada")
        try store.setTaskProgress(id: task.id, percent: 25, day: yesterday, now: t+300)
        try store.setTaskProgress(id: task.id, percent: 50, day: today, now: t+300)
        state = try store.read(now: t+300)
        report = TaskMetrics(state: state, now: Date(timeIntervalSince1970: t+300), interval: Calendar.current.dateInterval(of: .day, for: today)!)
        let updated = state.tasks!.first { $0.id == task.id }!
        precondition(report.percent(for: updated) == 50 && report.change(for: updated) == 25)
        precondition(state.tasks!.first { $0.id == task.id }!.progress!.count == 2, "One cumulative percentage per day")
        try store.setTaskProgress(id: idle.id, percent: 0, day: today, now: t+300)
        state = try store.read(now: t+300)
        report = TaskMetrics(state: state, now: Date(timeIntervalSince1970: t+300), interval: Calendar.current.dateInterval(of: .day, for: today)!)
        precondition(report.activity(for: state.tasks!.first { $0.id == idle.id }!) == "Sin avance declarado")
        let removed = try store.deleteRecord(id: state.records.first!.id)!
        state = try store.read(now: t+300)
        report = TaskMetrics(state: state, now: Date(timeIntervalSince1970: t+300), interval: Calendar.current.dateInterval(of: .day, for: today)!)
        precondition(report.seconds(for: task.id) == 50, "Deleting block also removes task time")
        try store.restoreRecord(removed)
        try store.setTaskCompleted(id: task.id, completed: true, now: t+300)
        try store.setTaskProgress(id: task.id, percent: 10, day: yesterday, now: t+301)
        state = try store.read(now: t+301)
        precondition(state.tasks!.first { $0.id == task.id }!.completedAt != nil, "Editing an earlier day preserves latest completion")
        try store.acknowledge(profile: "test", appliedID: "", error: nil, now: t+301)
        do { try store.start(duration: nil, firm: false, taskID: task.id, now: t+301); fatalError("Completed task accepted") }
        catch FocusTaskError.missing {}
        try store.setTaskArchived(id: task.id, archived: true, now: t+302)
        state = try store.read(now: t+302)
        report = TaskMetrics(state: state, now: Date(timeIntervalSince1970: t+302), interval: Calendar.current.dateInterval(of: .day, for: today)!)
        precondition(report.assignedSeconds == 110 && report.completed == 1, "Archiving preserves recorded work")
        try store.setTaskArchived(id: task.id, archived: false, now: t+302)
        try store.editTask(id: task.id, title: "Study priorities", day: today)
        let legacy = try JSONDecoder().decode(FocusState.self, from: Data("{\"records\":[],\"bridgeSeen\":0,\"appliedID\":\"\",\"revision\":0}".utf8))
        precondition(legacy.tasks == nil)
        let old = try JSONDecoder().decode(FocusRecord.self, from: Data("{\"id\":\"legacy\",\"startedAt\":0,\"seconds\":30,\"completed\":true}".utf8))
        precondition(old.taskID == nil)
        var midnight = FocusState()
        let edge = today.timeIntervalSince1970
        midnight.tasks = [task, idle]
        midnight.records = [FocusRecord(id: "cross", startedAt: edge-60, seconds: 90, completed: false, intervals: [FocusInterval(start: edge-60, end: edge-30), FocusInterval(start: edge+30, end: edge+90)], taskID: task.id), old]
        let clipped = TaskMetrics(state: midnight, now: Date(timeIntervalSince1970: t), interval: Calendar.current.dateInterval(of: .day, for: today)!)
        precondition(clipped.seconds(for: task.id) == 60, "Task day totals clip active intervals at midnight")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let pendingTomorrow = TaskMetrics(state: midnight, now: tomorrow.addingTimeInterval(3600), interval: Calendar.current.dateInterval(of: .day, for: tomorrow)!)
        precondition(pendingTomorrow.related.count == 2 && pendingTomorrow.activity(for: task) == "Sin actividad registrada", "Unfinished tasks retain days without recorded activity")
        var overdueTask = task
        overdueTask.plannedFor = yesterday.timeIntervalSince1970
        precondition(overdueTask.appears(on: today, now: today), "Pending earlier task appears today")
        overdueTask.completedAt = t
        precondition(overdueTask.appears(on: today, now: today), "Completing an overdue task keeps it visible on completion day")
        let beforeDelete = try store.read(now: t+302)
        let savedTask = beforeDelete.tasks!.first { $0.id == task.id }!
        let savedSeconds = beforeDelete.records.reduce(0) { $0 + $1.seconds }
        let deletion = try store.deleteTask(id: task.id, now: t+302)!
        state = try store.read(now: t+302)
        precondition(!state.tasks!.contains { $0.id == task.id })
        precondition(state.records.allSatisfy { $0.taskID != task.id })
        precondition(state.records.reduce(0) { $0 + $1.seconds } == savedSeconds, "Task deletion keeps all focus time")
        try store.restoreTask(deletion)
        try store.restoreTask(deletion)
        state = try store.read(now: t+302)
        precondition(state.tasks!.filter { $0.id == task.id }.count == 1 && state.tasks!.first { $0.id == task.id }! == savedTask, "Undo restores title and full progress once")
        precondition(Set(state.records.filter { $0.taskID == task.id }.map(\.id)) == deletion.linkedRecordIDs, "Undo restores existing session links")
        try store.acknowledge(profile: "test", appliedID: "", error: nil, now: t+400)
        try store.start(duration: nil, firm: false, taskID: idle.id, now: t+400)
        do { _ = try store.deleteTask(id: idle.id, now: t+401); fatalError("Deleted running task") }
        catch FocusTaskError.active {}
        try store.stop(now: t+410)
        let detached = try store.deleteRecord(id: (try store.read(now: t+410)).records.first!.id)!
        _ = try store.deleteTask(id: idle.id, now: t+410)
        try store.restoreRecord(detached)
        state = try store.read(now: t+410)
        precondition(state.records.first { $0.id == detached.id }!.taskID == nil, "Restoring a block cannot revive a deleted task link")
        print("PASS task deletion: time retained, progress and links undoable, running task protected, no orphan links")
        print("PASS tasks: migration, validation, linked blocks, pauses, progress by date, zero activity, deletion/undo and archive retention")
    }
}
