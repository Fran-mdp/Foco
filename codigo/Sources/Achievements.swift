import Foundation

struct FocusAchievementObligation: Codable, Equatable {
    let id: String
    let plannedFor: Double
    let createdAt: Double
    let completedOnTime: Bool

    static func from(task: FocusTask, now: Date, calendar: Calendar = .current) -> Self {
        let targetPlanned = task.achievementPlannedFor ?? task.plannedFor
        guard targetPlanned.isFinite, task.createdAt.isFinite,
              let day = calendar.dateInterval(of: .day, for: Date(timeIntervalSince1970: targetPlanned)) else {
            return FocusAchievementObligation(id: task.id, plannedFor: targetPlanned, createdAt: task.createdAt, completedOnTime: false)
        }
        let dayStart = day.start.timeIntervalSince1970
        let dayEnd = day.end.timeIntervalSince1970
        let nowLimit = now.timeIntervalSince1970
        let onTime: Bool
        if let progress = task.progress, !progress.isEmpty {
            let dayEntries = progress.filter { p in
                p.day.isFinite && p.recordedAt.isFinite &&
                (p.day == dayStart || calendar.isDate(Date(timeIntervalSince1970: p.day), inSameDayAs: day.start))
            }
            if let latest = dayEntries.max(by: { $0.recordedAt < $1.recordedAt }) {
                onTime = latest.percent == 100 &&
                         latest.recordedAt >= max(task.createdAt, dayStart) &&
                         latest.recordedAt < dayEnd &&
                         latest.recordedAt <= nowLimit
            } else {
                onTime = false
            }
        } else if let completedAt = task.completedAt, completedAt.isFinite {
            onTime = completedAt >= max(task.createdAt, dayStart) &&
                     completedAt < dayEnd &&
                     completedAt <= nowLimit
        } else {
            onTime = false
        }
        return FocusAchievementObligation(id: task.id, plannedFor: dayStart, createdAt: task.createdAt, completedOnTime: onTime)
    }
}

struct FocusAchievements: Equatable {
    let onTimeTasks: Int
    let perfectDays: Int
    let perfectWeeks: Int
    let todayCompleted: Int
    let todayPlanned: Int
    let firstOnTimeDate: Date?
    let firstPerfectDay: Date?
    let firstPerfectWeek: Date?

    init(state: FocusState, now: Date = Date(), calendar: Calendar = .current) {
        var obligationsByID: [String: FocusAchievementObligation] = [:]

        // 1. Tombstones (deleted achievement obligations)
        for tombstone in state.deletedAchievementObligations ?? [] {
            guard tombstone.plannedFor.isFinite, tombstone.createdAt.isFinite else { continue }
            obligationsByID[tombstone.id] = tombstone
        }

        // 2. Live tasks (including archived tasks), overriding tombstones
        for task in state.tasks ?? [] {
            let targetPlanned = task.achievementPlannedFor ?? task.plannedFor
            guard targetPlanned.isFinite, task.createdAt.isFinite else { continue }
            let ob = FocusAchievementObligation.from(task: task, now: now, calendar: calendar)
            guard ob.plannedFor.isFinite, ob.createdAt.isFinite else { continue }
            obligationsByID[task.id] = ob
        }

        guard let todayInterval = calendar.dateInterval(of: .day, for: now) else {
            self.onTimeTasks = 0
            self.perfectDays = 0
            self.perfectWeeks = 0
            self.todayCompleted = 0
            self.todayPlanned = 0
            self.firstOnTimeDate = nil
            self.firstPerfectDay = nil
            self.firstPerfectWeek = nil
            return
        }

        let nowLimit = now.timeIntervalSince1970
        let todayStart = todayInterval.start.timeIntervalSince1970

        var tPlanned = 0
        var tCompleted = 0
        var onTimeCount = 0
        var onTimeDates: [Date] = []

        var obligationsByEndedDay: [Date: [FocusAchievementObligation]] = [:]
        var obligationsByEndedWeek: [Date: [FocusAchievementObligation]] = [:]

        for ob in obligationsByID.values {
            guard let dayInterval = calendar.dateInterval(of: .day, for: Date(timeIntervalSince1970: ob.plannedFor)) else { continue }
            let dayStart = dayInterval.start
            let dayStartTS = dayStart.timeIntervalSince1970

            let isFuture = dayStartTS > todayStart

            // Today's counts
            if calendar.isDate(dayStart, inSameDayAs: now) {
                tPlanned += 1
                if ob.completedOnTime {
                    tCompleted += 1
                }
            }

            // On-time tasks (excluding future)
            if ob.completedOnTime && !isFuture && ob.plannedFor <= nowLimit {
                onTimeCount += 1
                onTimeDates.append(dayStart)
            }

            // Closed day obligations (day ended)
            if dayInterval.end <= now {
                obligationsByEndedDay[dayStart, default: []].append(ob)
            }

            // Closed week obligations (week ended)
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date(timeIntervalSince1970: ob.plannedFor)) {
                if weekInterval.end <= now {
                    obligationsByEndedWeek[weekInterval.start, default: []].append(ob)
                }
            }
        }

        self.todayPlanned = tPlanned
        self.todayCompleted = tCompleted
        self.onTimeTasks = onTimeCount
        self.firstOnTimeDate = onTimeDates.min()

        // Perfect days: ended days with >= 1 obligation, ALL on time
        var pDays = 0
        var pDayDates: [Date] = []
        for (dayDate, dayObs) in obligationsByEndedDay {
            if !dayObs.isEmpty && dayObs.allSatisfy(\.completedOnTime) {
                pDays += 1
                pDayDates.append(dayDate)
            }
        }
        self.perfectDays = pDays
        self.firstPerfectDay = pDayDates.min()

        // Perfect weeks: ended weeks with >= 1 obligation, ALL on time on each due day. Empty days neutral, empty week no award.
        var pWeeks = 0
        var pWeekDates: [Date] = []
        for (weekDate, weekObs) in obligationsByEndedWeek {
            if !weekObs.isEmpty && weekObs.allSatisfy(\.completedOnTime) {
                pWeeks += 1
                pWeekDates.append(weekDate)
            }
        }
        self.perfectWeeks = pWeeks
        self.firstPerfectWeek = pWeekDates.min()
    }
}
