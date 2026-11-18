import Foundation

@main
struct AchievementsTests {
    static func makeCalendar(timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!, firstWeekday: Int = 2) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.firstWeekday = firstWeekday
        return cal
    }

    static func main() throws {
        let previousTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
        defer { NSTimeZone.default = previousTimeZone }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("FocoAchievements-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FocusStore(directory: dir)

        let cal = makeCalendar() // UTC, Monday-first

        // Base dates in UTC:
        // Mon 2026-11-09 00:00:00 UTC
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 9
        components.hour = 0
        components.minute = 0
        components.second = 0
        guard let monday = cal.date(from: components) else { fatalError("Invalid date") }
        let mondayStart = monday.timeIntervalSince1970
        let tuesday = cal.date(byAdding: .day, value: 1, to: monday)!
        let thursday = cal.date(byAdding: .day, value: 3, to: monday)!
        let nextMonday = cal.date(byAdding: .day, value: 7, to: monday)!

        // 1. Legacy JSON test
        do {
            let json = """
            {
                "records": [],
                "tasks": [
                    {
                        "id": "legacy-task-1",
                        "title": "Legacy Completed Task",
                        "plannedFor": \(mondayStart),
                        "createdAt": \(mondayStart + 3600),
                        "completedAt": \(mondayStart + 7200)
                    }
                ],
                "bridgeSeen": 0,
                "appliedID": "",
                "revision": 1
            }
            """
            let decoded = try JSONDecoder().decode(FocusState.self, from: Data(json.utf8))
            precondition(decoded.deletedAchievementObligations == nil, "Legacy JSON has nil tombstones")
            precondition(decoded.tasks?.first?.achievementPlannedFor == nil, "Legacy JSON task has nil achievementPlannedFor")

            let legacyAchievements = FocusAchievements(state: decoded, now: nextMonday, calendar: cal)
            precondition(legacyAchievements.onTimeTasks == 1, "Legacy completedAt without progress counts as on-time")
            precondition(legacyAchievements.perfectDays == 1, "Legacy on-time task produces perfect day")
            precondition(legacyAchievements.perfectWeeks == 1, "Legacy on-time task produces perfect week")
            precondition(legacyAchievements.firstOnTimeDate == monday, "Legacy first on-time date matches")
        }

        // 2. Partial 50 then 100 over multiple blocks doesn't auto-complete
        do {
            let task = try store.addTask(title: "Multi-block Task", day: monday, now: mondayStart + 1000)
            precondition(task.achievementPlannedFor == mondayStart, "achievementPlannedFor anchored at creation")

            // Add records linked to task
            try store.transaction { state in
                state.records.append(FocusRecord(id: "rec-1", startedAt: mondayStart + 1100, seconds: 1500, completed: true, taskID: task.id))
                state.records.append(FocusRecord(id: "rec-2", startedAt: mondayStart + 3000, seconds: 1500, completed: true, taskID: task.id))
            }
            var state = try store.read(now: mondayStart + 5000)
            var currentTask = state.tasks!.first { $0.id == task.id }!
            precondition(currentTask.completedAt == nil, "Focus records do not auto-complete task")

            // Set progress to 50%
            try store.setTaskProgress(id: task.id, percent: 50, day: monday, now: mondayStart + 5100)
            state = try store.read(now: mondayStart + 5100)
            currentTask = state.tasks!.first { $0.id == task.id }!
            precondition(currentTask.completedAt == nil, "50% progress does not complete task")

            var ach = FocusAchievements(state: state, now: monday.addingTimeInterval(5200), calendar: cal)
            precondition(ach.onTimeTasks == 0, "Partial progress is not on-time completion")

            // Set progress to 100% on Monday
            try store.setTaskProgress(id: task.id, percent: 100, day: monday, now: mondayStart + 6000)
            state = try store.read(now: mondayStart + 6000)
            currentTask = state.tasks!.first { $0.id == task.id }!
            precondition(currentTask.completedAt != nil, "100% progress completes task")

            ach = FocusAchievements(state: state, now: monday.addingTimeInterval(6000), calendar: cal)
            precondition(ach.onTimeTasks == 1, "100% on planned day is on-time")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        // 3. Today provisional vs 4. Closed day perfect
        do {
            let task = try store.addTask(title: "Today Task", day: monday, now: mondayStart + 3600)
            try store.setTaskProgress(id: task.id, percent: 100, day: monday, now: mondayStart + 7200)
            let state = try store.read(now: mondayStart + 7200)

            // During Monday (today provisional)
            let todayAch = FocusAchievements(state: state, now: monday.addingTimeInterval(7200), calendar: cal)
            precondition(todayAch.todayPlanned == 1, "Today planned is 1")
            precondition(todayAch.todayCompleted == 1, "Today completed is 1")
            precondition(todayAch.onTimeTasks == 1, "Today task is on-time")
            precondition(todayAch.firstOnTimeDate == monday, "Earned on-time date matches")
            precondition(todayAch.perfectDays == 0, "Today is provisional: no star yet")
            precondition(todayAch.firstPerfectDay == nil, "No first perfect day yet")
            precondition(todayAch.perfectWeeks == 0, "Week in progress: no trophy yet")

            // Now advance now to Tuesday (Monday is now closed)
            let closedAch = FocusAchievements(state: state, now: tuesday.addingTimeInterval(3600), calendar: cal)
            precondition(closedAch.perfectDays == 1, "Closed day with all on-time is perfect")
            precondition(closedAch.firstPerfectDay == monday, "First perfect day is Monday")
            precondition(closedAch.todayPlanned == 0, "Tuesday has 0 planned tasks")
            precondition(closedAch.todayCompleted == 0, "Tuesday has 0 completed tasks")
            precondition(closedAch.perfectWeeks == 0, "Week is still in progress on Tuesday")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        // 5. Pending prevents day/week
        do {
            let task1 = try store.addTask(title: "Task 1", day: monday, now: mondayStart + 1000)
            let _ = try store.addTask(title: "Task 2", day: monday, now: mondayStart + 1000)
            try store.setTaskProgress(id: task1.id, percent: 100, day: monday, now: mondayStart + 2000)
            // Task 2 left pending (0%)

            let state = try store.read(now: nextMonday.timeIntervalSince1970)
            let ach = FocusAchievements(state: state, now: nextMonday, calendar: cal)
            precondition(ach.onTimeTasks == 1, "Only task1 is on time")
            precondition(ach.perfectDays == 0, "Pending task prevents perfect day")
            precondition(ach.perfectWeeks == 0, "Pending task prevents perfect week")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        // 6. Empty week & 7. Closed week empty days neutral
        do {
            // Empty week evaluated
            let stateEmpty = FocusState()
            let achEmpty = FocusAchievements(state: stateEmpty, now: nextMonday, calendar: cal)
            precondition(achEmpty.perfectWeeks == 0, "Empty week gives no award")

            // Closed week with tasks on Monday and Thursday, all on time; Tue, Wed, Fri, Sat, Sun empty
            let tMon = try store.addTask(title: "Mon Task", day: monday, now: mondayStart + 1000)
            let tThu = try store.addTask(title: "Thu Task", day: thursday, now: thursday.timeIntervalSince1970 + 1000)
            try store.setTaskProgress(id: tMon.id, percent: 100, day: monday, now: mondayStart + 2000)
            try store.setTaskProgress(id: tThu.id, percent: 100, day: thursday, now: thursday.timeIntervalSince1970 + 2000)

            let stateClosed = try store.read(now: nextMonday.timeIntervalSince1970)
            let achClosed = FocusAchievements(state: stateClosed, now: nextMonday, calendar: cal)
            precondition(achClosed.perfectDays == 2, "Monday and Thursday are both perfect days")
            precondition(achClosed.perfectWeeks == 1, "Closed week with empty days neutral is a perfect week")
            precondition(achClosed.firstPerfectWeek == monday, "First perfect week begins on Monday")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        // 8. Backfill late fails
        do {
            let task = try store.addTask(title: "Late Backfill", day: monday, now: mondayStart + 1000)
            // Backfilled on Tuesday (after Monday closed)
            try store.setTaskProgress(id: task.id, percent: 100, day: monday, now: tuesday.timeIntervalSince1970 + 1000)

            let state = try store.read(now: nextMonday.timeIntervalSince1970)
            let ach = FocusAchievements(state: state, now: nextMonday, calendar: cal)
            precondition(ach.onTimeTasks == 0, "Backfilled after day ended fails on-time")
            precondition(ach.perfectDays == 0, "Backfilled task does not award perfect day")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        // 9. Future completion fails
        do {
            let _ = try store.addTask(title: "Future Task", day: nextMonday, now: mondayStart + 1000)
            let state = try store.read(now: mondayStart + 2000)
            let ach = FocusAchievements(state: state, now: monday.addingTimeInterval(2000), calendar: cal)
            precondition(ach.onTimeTasks == 0, "Future task cannot be on-time")
            precondition(ach.todayPlanned == 0, "Future task not counted in today planned")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        // 10. Delete pending cannot unlock & 11. Delete completed keeps & 12. Undo idempotent removes tombstone
        do {
            let tGood = try store.addTask(title: "Completed Task", day: monday, now: mondayStart + 1000)
            let tBad = try store.addTask(title: "Incomplete Task", day: monday, now: mondayStart + 1000)
            try store.setTaskProgress(id: tGood.id, percent: 100, day: monday, now: mondayStart + 2000)

            var state = try store.read(now: tuesday.timeIntervalSince1970)
            var ach = FocusAchievements(state: state, now: tuesday, calendar: cal)
            precondition(ach.perfectDays == 0, "Initial day not perfect due to pending tBad")

            // Delete pending task -> must NOT unlock perfect day!
            let delBad = try store.deleteTask(id: tBad.id, now: tuesday.timeIntervalSince1970)!
            state = try store.read(now: tuesday.timeIntervalSince1970)
            precondition((state.deletedAchievementObligations ?? []).count == 1, "Tombstone created for deleted task")
            precondition(state.deletedAchievementObligations?.first?.completedOnTime == false, "Tombstone for incomplete task is not on time")

            ach = FocusAchievements(state: state, now: tuesday, calendar: cal)
            precondition(ach.perfectDays == 0, "Deleting pending task cannot unlock perfect day")

            // Restore tBad idempotently
            try store.restoreTask(delBad)
            try store.restoreTask(delBad) // idempotent
            state = try store.read(now: tuesday.timeIntervalSince1970)
            precondition((state.deletedAchievementObligations ?? []).isEmpty, "Undo removes tombstone")
            precondition(state.tasks?.contains { $0.id == tBad.id } == true, "Task restored")

            // Complete tBad on time on Monday
            try store.setTaskProgress(id: tBad.id, percent: 100, day: monday, now: mondayStart + 3000)
            state = try store.read(now: tuesday.timeIntervalSince1970)
            ach = FocusAchievements(state: state, now: tuesday, calendar: cal)
            precondition(ach.perfectDays == 1, "Both tasks completed on time -> perfect day")

            // Delete completed task -> day should STILL remain perfect via tombstone
            let delGood = try store.deleteTask(id: tGood.id, now: tuesday.timeIntervalSince1970)!
            state = try store.read(now: tuesday.timeIntervalSince1970)
            precondition(state.deletedAchievementObligations?.contains { $0.id == tGood.id && $0.completedOnTime == true } == true, "Tombstone preserved on-time evidence")

            ach = FocusAchievements(state: state, now: tuesday, calendar: cal)
            precondition(ach.perfectDays == 1, "Deleting completed task keeps perfect day via tombstone")

            // Restore tGood
            try store.restoreTask(delGood)
            state = try store.read(now: tuesday.timeIntervalSince1970)
            precondition(state.deletedAchievementObligations?.contains { $0.id == tGood.id } == false, "Undo removes tombstone idempotently")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        // 13. Moving date no inflate
        do {
            let task = try store.addTask(title: "Movable Task", day: monday, now: mondayStart + 1000)
            precondition(task.achievementPlannedFor == mondayStart, "Anchored to Monday")

            // User moves task to Tuesday
            try store.editTask(id: task.id, title: "Movable Task", day: tuesday)
            var state = try store.read(now: tuesday.timeIntervalSince1970)
            let movedTask = state.tasks!.first { $0.id == task.id }!
            precondition(movedTask.plannedFor == tuesday.timeIntervalSince1970, "plannedFor updated to Tuesday")
            precondition(movedTask.achievementPlannedFor == mondayStart, "achievementPlannedFor stays anchored to Monday")

            // User completes task on Tuesday
            try store.setTaskProgress(id: task.id, percent: 100, day: tuesday, now: tuesday.timeIntervalSince1970 + 1000)
            state = try store.read(now: nextMonday.timeIntervalSince1970)
            let ach = FocusAchievements(state: state, now: nextMonday, calendar: cal)
            precondition(ach.onTimeTasks == 0, "Moving date does not inflate achievements: completed late for original Monday anchor")
            precondition(ach.perfectDays == 0, "Monday is not perfect because task was not completed on Monday")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        // 14. Archived included
        do {
            let task = try store.addTask(title: "Archived Task", day: monday, now: mondayStart + 1000)
            try store.setTaskProgress(id: task.id, percent: 100, day: monday, now: mondayStart + 2000)
            try store.setTaskArchived(id: task.id, archived: true, now: tuesday.timeIntervalSince1970)

            let state = try store.read(now: nextMonday.timeIntervalSince1970)
            let ach = FocusAchievements(state: state, now: nextMonday, calendar: cal)
            precondition(ach.onTimeTasks == 1, "Archived tasks are included in on-time count")
            precondition(ach.perfectDays == 1, "Archived tasks count towards perfect day")
            precondition(ach.perfectWeeks == 1, "Archived tasks count towards perfect week")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        // 15. DST NewYork
        do {
            guard let nyTZ = TimeZone(identifier: "America/New_York") else { fatalError("Missing NY TimeZone") }
            let nyCal = makeCalendar(timeZone: nyTZ, firstWeekday: 1) // US Sunday-first

            // 2026 Spring Forward in NY: Sunday March 8, 2026 (23 hours long)
            var dstComp = DateComponents()
            dstComp.year = 2026
            dstComp.month = 3
            dstComp.day = 8
            dstComp.hour = 0
            dstComp.minute = 0
            dstComp.second = 0
            dstComp.timeZone = nyTZ
            guard let dstSun = nyCal.date(from: dstComp) else { fatalError("Invalid DST date") }
            let dstSunStart = dstSun.timeIntervalSince1970
            guard let dstSunInterval = nyCal.dateInterval(of: .day, for: dstSun) else { fatalError("Missing day interval") }
            precondition(dstSunInterval.duration == 23 * 3600, "NY spring DST day is 23 hours")

            let dstMon = nyCal.date(byAdding: .day, value: 1, to: dstSun)!
            let recordTime = dstSunStart + 5 * 3600
            let completedTask = FocusTask(id: "dst-task", title: "DST Task", plannedFor: dstSunStart, createdAt: dstSunStart + 3600, progress: [FocusTaskProgress(day: dstSunStart, percent: 100, recordedAt: recordTime)], achievementPlannedFor: dstSunStart)
            var dstState = FocusState()
            dstState.tasks = [completedTask]

            let dstAch = FocusAchievements(state: dstState, now: dstMon.addingTimeInterval(3600), calendar: nyCal)
            precondition(dstAch.perfectDays == 1, "DST 23h day successfully recognized as perfect day using Calendar boundaries")
            precondition(dstAch.firstPerfectDay == dstSun, "First perfect day date matches DST day start")
        }

        // 16. Bound tombstones 5000 overflow
        do {
            var state = FocusState()
            var tombstones: [FocusAchievementObligation] = []
            for i in 0..<5000 {
                tombstones.append(FocusAchievementObligation(id: "tomb-\(i)", plannedFor: mondayStart, createdAt: mondayStart, completedOnTime: false))
            }
            state.deletedAchievementObligations = tombstones
            let overflowTask = FocusTask(id: "overflow-task", title: "Overflow Task", plannedFor: mondayStart, createdAt: mondayStart)
            state.tasks = [overflowTask]

            try store.transaction { $0 = state }

            do {
                _ = try store.deleteTask(id: overflowTask.id, now: mondayStart + 3600)
                fatalError("Should have failed with limit error")
            } catch FocusTaskError.limit {
                // Expected limit error
            }

            let afterState = try store.read(now: mondayStart + 3600)
            precondition(afterState.tasks?.contains { $0.id == overflowTask.id } == true, "Real task is NOT deleted on overflow")
            precondition((afterState.deletedAchievementObligations ?? []).count == 5000, "Tombstone count unchanged")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        // 17. Completion evidence timestamp later than injected now must not count even when planned day today
        do {
            let task = try store.addTask(title: "Future Evidence Task", day: monday, now: mondayStart + 1000)
            try store.setTaskProgress(id: task.id, percent: 100, day: monday, now: mondayStart + 7200)
            let state = try store.read(now: mondayStart + 7200)

            // At now = mondayStart + 3600, completion evidence (7200) is in the future relative to now
            let prematureAch = FocusAchievements(state: state, now: monday.addingTimeInterval(3600), calendar: cal)
            precondition(prematureAch.todayPlanned == 1, "Task is planned for today")
            precondition(prematureAch.todayCompleted == 0, "Future completion evidence must not count as completed today")
            precondition(prematureAch.onTimeTasks == 0, "Future completion evidence must not count as on-time")

            // At now = mondayStart + 7200, completion evidence is valid
            let maturedAch = FocusAchievements(state: state, now: monday.addingTimeInterval(7200), calendar: cal)
            precondition(maturedAch.todayPlanned == 1, "Task is planned for today")
            precondition(maturedAch.todayCompleted == 1, "Completion evidence is valid at current now")
            precondition(maturedAch.onTimeTasks == 1, "Task counted as on-time once evidence time reached")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        // 18. Duplicate live+tombstone ID counted once with live preferring
        do {
            // Live completed on time, tombstone incomplete -> live preferred, counts once, perfect day awarded
            var stateLiveGood = FocusState()
            stateLiveGood.tasks = [
                FocusTask(
                    id: "dup-task-1",
                    title: "Live Complete",
                    plannedFor: mondayStart,
                    createdAt: mondayStart + 1000,
                    progress: [FocusTaskProgress(day: mondayStart, percent: 100, recordedAt: mondayStart + 2000)],
                    achievementPlannedFor: mondayStart
                )
            ]
            stateLiveGood.deletedAchievementObligations = [
                FocusAchievementObligation(
                    id: "dup-task-1",
                    plannedFor: mondayStart,
                    createdAt: mondayStart + 1000,
                    completedOnTime: false
                )
            ]
            let ach1 = FocusAchievements(state: stateLiveGood, now: tuesday.addingTimeInterval(3600), calendar: cal)
            precondition(ach1.onTimeTasks == 1, "Duplicate counted once; live completion preferred")
            precondition(ach1.perfectDays == 1, "Live completed task yields perfect day despite incomplete tombstone")

            // Live pending, tombstone complete -> live preferred, counts once, not perfect
            var stateLivePending = FocusState()
            stateLivePending.tasks = [
                FocusTask(
                    id: "dup-task-2",
                    title: "Live Pending",
                    plannedFor: mondayStart,
                    createdAt: mondayStart + 1000,
                    achievementPlannedFor: mondayStart
                )
            ]
            stateLivePending.deletedAchievementObligations = [
                FocusAchievementObligation(
                    id: "dup-task-2",
                    plannedFor: mondayStart,
                    createdAt: mondayStart + 1000,
                    completedOnTime: true
                )
            ]
            let ach2 = FocusAchievements(state: stateLivePending, now: tuesday.addingTimeInterval(3600), calendar: cal)
            precondition(ach2.onTimeTasks == 0, "Duplicate counted once; live pending preferred over complete tombstone")
            precondition(ach2.perfectDays == 0, "Pending live task prevents perfect day")
        }

        // 19. Legacy task date edit freezes original date
        do {
            var legacyTask = FocusTask(
                id: "legacy-edit-task",
                title: "Legacy Task",
                plannedFor: mondayStart,
                createdAt: mondayStart + 1000
            )
            legacyTask.achievementPlannedFor = nil
            precondition(legacyTask.achievementPlannedFor == nil, "Legacy task starts with nil achievementPlannedFor")

            try store.transaction {
                $0.tasks = [legacyTask]
                $0.records = []
                $0.deletedAchievementObligations = nil
            }

            // Move legacy task from Monday to Tuesday
            try store.editTask(id: legacyTask.id, title: "Legacy Task Moved", day: tuesday)

            let state = try store.read(now: tuesday.timeIntervalSince1970)
            let edited = state.tasks!.first { $0.id == legacyTask.id }!
            precondition(edited.plannedFor == tuesday.timeIntervalSince1970, "plannedFor updated to Tuesday")
            precondition(edited.achievementPlannedFor == mondayStart, "Editing legacy task freezes original date into achievementPlannedFor")

            // Completing on Tuesday is late for Monday anchor
            try store.setTaskProgress(id: legacyTask.id, percent: 100, day: tuesday, now: tuesday.timeIntervalSince1970 + 1000)
            let achState = try store.read(now: nextMonday.timeIntervalSince1970)
            let ach = FocusAchievements(state: achState, now: nextMonday, calendar: cal)
            precondition(ach.onTimeTasks == 0, "Frozen original anchor prevents late completion from inflating achievements")

            try store.transaction { $0.tasks = []; $0.records = []; $0.deletedAchievementObligations = nil }
        }

        print("PASS achievements: legacy JSON, multi-block progress, today provisional, closed day perfect, pending blocks award, empty week neutral, empty days neutral, backfill fails, future fails, delete pending protects, delete completed keeps, undo idempotent, move date anchored, archived included, DST NewYork safe, 5000 tombstones bound, evidence after now ignored, duplicate live tombstone deduplicated, legacy edit freezes original date")
    }
}
