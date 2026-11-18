import Foundation

enum FocusPeriod: String, CaseIterable, Identifiable {
    case day = "Día", week = "Semana", month = "Mes", year = "Año", custom = "Fechas"
    var id: Self { self }
}
struct MetricPoint: Identifiable {
    var date: Date
    var seconds: Double
    var id: Date { date }
}
struct FocusMetrics {
    let state: FocusState
    let now: Date
    var calendar: Calendar = .current
    var period: FocusPeriod
    var anchor: Date
    var customStart: Date
    var customEnd: Date
    var bounds: DateInterval {
        var cal = calendar; cal.firstWeekday = 2
        if period == .custom {
            let start = cal.startOfDay(for: min(customStart, customEnd))
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: max(customStart, customEnd)))!
            return DateInterval(start: start, end: end)
        }
        let component: Calendar.Component = period == .day ? .day : period == .week ? .weekOfYear : period == .month ? .month : .year
        return cal.dateInterval(of: component, for: anchor)!
    }
    var visibleEnd: Date { min(bounds.end, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!) }
    var dayCount: Int { max(1, calendar.dateComponents([.day], from: bounds.start, to: max(bounds.start, visibleEnd)).day ?? 1) }
    func seconds(in interval: DateInterval) -> Double {
        let upper = min(interval.end.timeIntervalSince1970, now.timeIntervalSince1970)
        let lower = interval.start.timeIntervalSince1970
        var sum = state.records.flatMap(\.activeIntervals).reduce(0.0) { $0 + $1.overlap(from: lower, to: upper) }
        if let session = state.session {
            sum += session.intervals(at: now.timeIntervalSince1970).reduce(0) { $0 + $1.overlap(from: lower, to: upper) }
        }
        return sum
    }
    var total: Double { seconds(in: bounds) }
    var dailyAverage: Double { total / Double(dayCount) }
    // Sessions are assigned by start date. The mean uses full finished-session durations.
    var sessions: [FocusRecord] {
        state.records.filter { $0.startedAt >= bounds.start.timeIntervalSince1970 && $0.startedAt < bounds.end.timeIntervalSince1970 }
    }
    var sessionAverage: Double { sessions.isEmpty ? 0 : sessions.reduce(0.0) { $0 + $1.seconds } / Double(sessions.count) }
    var daily: [MetricPoint] {
        var values: [MetricPoint] = []; var cursor = bounds.start
        while cursor < visibleEnd {
            let next = calendar.date(byAdding: .day, value: 1, to: cursor)!
            values.append(MetricPoint(date: cursor, seconds: seconds(in: DateInterval(start: cursor, end: next))))
            cursor = next
        }
        return values
    }
    var activeDays: Int { daily.filter { $0.seconds > 0 }.count }
    var chartUnit: Calendar.Component { period == .day ? .hour : period == .year || dayCount > 120 ? .month : .day }
    var chartEnd: Date {
        if period == .week { return bounds.end }
        guard let last = points.last else { return bounds.end }
        return calendar.date(byAdding: chartUnit, value: 1, to: last.date) ?? bounds.end
    }
    var points: [MetricPoint] {
        if chartUnit == .day && period != .week { return daily }
        var values: [MetricPoint] = []; var cursor = bounds.start
        // A weekly chart always shows Monday–Sunday, while averages still use elapsed days.
        let chartEnd = period == .week ? bounds.end : visibleEnd
        while cursor < chartEnd {
            let next = calendar.date(byAdding: chartUnit, value: 1, to: cursor)!
            let value = cursor > now ? 0 : seconds(in: DateInterval(start: cursor, end: min(next, bounds.end)))
            values.append(MetricPoint(date: cursor, seconds: value))
            cursor = next
        }
        return values
    }
    // Compare only completed calendar days, never a partial today with a full past day.
    var comparison: (current: Double, previous: Double, days: Int)? {
        let end = min(bounds.end, calendar.startOfDay(for: now))
        let days = calendar.dateComponents([.day], from: bounds.start, to: end).day ?? 0
        guard days > 0 else { return nil }
        let previousStart = calendar.date(byAdding: .day, value: -days, to: bounds.start)!
        return (seconds(in: DateInterval(start: bounds.start, end: end)), seconds(in: DateInterval(start: previousStart, end: bounds.start)), days)
    }
}
func durationLabel(_ seconds: Double) -> String {
    let minutes = Int(max(0, seconds) / 60)
    if seconds > 0 && minutes == 0 { return "<1 min" }
    if minutes >= 60 { return "\(minutes / 60) h \(minutes % 60) min" }
    return "\(minutes) min"
}

// All task times are derived from the same records as the main dashboard.
struct TaskMetrics {
    let state: FocusState
    let now: Date
    let interval: DateInterval
    private let totals: [String: Double]
    init(state: FocusState, now: Date, interval: DateInterval) {
        self.state = state; self.now = now; self.interval = interval
        let lower = interval.start.timeIntervalSince1970
        let upper = min(interval.end.timeIntervalSince1970, now.timeIntervalSince1970)
        var values: [String: Double] = [:]
        for record in state.records {
            values[record.taskID ?? "", default: 0] += record.activeIntervals.reduce(0) { $0 + $1.overlap(from: lower, to: upper) }
        }
        if let session = state.session {
            values[session.taskID ?? "", default: 0] += session.intervals(at: now.timeIntervalSince1970).reduce(0) { $0 + $1.overlap(from: lower, to: upper) }
        }
        totals = values
    }
    func seconds(for taskID: String?) -> Double { totals[taskID ?? "", default: 0] }
    func percent(for task: FocusTask) -> Int { task.percent(before: min(interval.end.timeIntervalSince1970, now.timeIntervalSince1970 + 1)) }
    func change(for task: FocusTask) -> Int { percent(for: task) - task.percent(before: interval.start.timeIntervalSince1970) }
    func hasEntry(for task: FocusTask) -> Bool { (task.progress ?? []).contains { contains($0.day) } }
    func activity(for task: FocusTask) -> String {
        if !hasEntry(for: task) { return seconds(for: task.id) > 0 ? "Con tiempo de foco · avance sin registrar" : "Sin actividad registrada" }
        let delta = change(for: task)
        if delta == 0 { return "Sin avance declarado" }
        return "\(delta > 0 ? "+" : "")\(delta) puntos de avance"
    }
    func contains(_ timestamp: Double) -> Bool {
        timestamp >= interval.start.timeIntervalSince1970 && timestamp < interval.end.timeIntervalSince1970
    }
    var tasks: [FocusTask] { state.tasks ?? [] }
    var completed: Int { tasks.filter { $0.completedAt.map(contains) ?? false }.count }
    var related: [FocusTask] {
        tasks.filter { task in
            let wasPending = task.plannedFor < interval.end.timeIntervalSince1970 &&
                (task.archivedAt == nil || task.archivedAt! >= interval.start.timeIntervalSince1970) &&
                (task.completedAt == nil || task.completedAt! >= interval.start.timeIntervalSince1970)
            return wasPending || (task.completedAt.map(contains) ?? false) || seconds(for: task.id) > 0 || hasEntry(for: task)
        }
            .sorted {
                let lhs = seconds(for: $0.id), rhs = seconds(for: $1.id)
                return lhs == rhs ? $0.createdAt < $1.createdAt : lhs > rhs
            }
    }
    var pending: Int { related.filter { percent(for: $0) < 100 && ($0.archivedAt == nil || $0.archivedAt! >= interval.end.timeIntervalSince1970) }.count }
    var assignedSeconds: Double {
        // Includes archived tasks; archiving never discards their recorded work.
        tasks.reduce(0) { $0 + seconds(for: $1.id) }
    }
}
