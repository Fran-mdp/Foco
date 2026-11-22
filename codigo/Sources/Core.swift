import Foundation
import Darwin

struct FocusInterval: Codable, Equatable {
    var start: Double
    var end: Double
    func overlap(from lower: Double, to upper: Double) -> Double { max(0, min(end, upper) - max(start, lower)) }
}
struct FocusSession: Codable, Equatable {
    var id = UUID().uuidString
    var startedAt: Double
    var duration: Double?
    var firm: Bool
    var blockWhatsAppApp: Bool? = nil
    var blockWhatsAppWeb: Bool? = nil
    var sites: [BlockedSite]? = nil
    var applications: [BlockedApplication]? = nil
    var taskID: String? = nil
    var goalID: String? = nil
    var pausedAt: Double? = nil
    var pauses: [FocusInterval]? = nil
    var isPaused: Bool { pausedAt != nil }
    var endsAt: Double? {
        guard !isPaused else { return nil }
        return duration.map { startedAt + $0 + (pauses ?? []).reduce(0) { $0 + max(0, $1.end - $1.start) } }
    }
    func intervals(at now: Double) -> [FocusInterval] {
        let upper = max(startedAt, min(now, pausedAt ?? now))
        var cursor = startedAt
        var budget = duration ?? Double.greatestFiniteMagnitude
        var result: [FocusInterval] = []
        func append(until end: Double) {
            let count = min(budget, max(0, end - cursor))
            if count > 0 { result.append(FocusInterval(start: cursor, end: cursor + count)); budget -= count }
        }
        for pause in pauses ?? [] {
            append(until: min(upper, pause.start))
            cursor = max(cursor, min(upper, pause.end))
        }
        append(until: upper)
        return result
    }
    func elapsed(at now: Double) -> Double { intervals(at: now).reduce(0) { $0 + $1.end - $1.start } }
    func remaining(at now: Double) -> Double? { duration.map { max(0, $0 - elapsed(at: now)) } }
    func expired(at now: Double) -> Bool { !isPaused && (endsAt.map { now >= $0 } ?? false) }

}
enum FocusDifficulty: String, Codable, CaseIterable {
    case low, medium, high

    var label: String {
        switch self {
        case .low: return "Baja"
        case .medium: return "Media"
        case .high: return "Alta"
        }
    }
}

struct FocusRecord: Codable, Identifiable {
    var id: String
    var startedAt: Double
    var seconds: Double
    var completed: Bool
    var targetSeconds: Double? = nil
    var intervals: [FocusInterval]? = nil
    var taskID: String? = nil
    var goalID: String? = nil
    var qualityRating: Int? = nil
    var difficulty: FocusDifficulty? = nil
    var activeIntervals: [FocusInterval] { intervals ?? [FocusInterval(start: startedAt, end: startedAt + seconds)] }
}
struct FocusTaskProgress: Codable, Equatable {
    var day: Double
    var percent: Int
    var recordedAt: Double
}
struct FocusTask: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var title: String
    var plannedFor: Double
    var createdAt: Double
    var completedAt: Double? = nil
    var archivedAt: Double? = nil
    var progress: [FocusTaskProgress]? = nil
    var achievementPlannedFor: Double? = nil
    var goalID: String? = nil
    func percent(before timestamp: Double) -> Int {
        if let entry = (progress ?? []).filter({ $0.day < timestamp }).max(by: { $0.day < $1.day }) { return entry.percent }
        return completedAt.map { $0 < timestamp ? 100 : 0 } ?? 0
    }
    func appears(on day: Date, now: Date) -> Bool {
        let interval = Calendar.current.dateInterval(of: .day, for: day)!
        let start = interval.start.timeIntervalSince1970, end = interval.end.timeIntervalSince1970
        let planned = plannedFor >= start && plannedFor < end
        let finished = completedAt.map { $0 >= start && $0 < end } ?? false
        let overdue = Calendar.current.isDate(day, inSameDayAs: now) && plannedFor < start && completedAt == nil
        return planned || finished || entry(on: day) != nil || overdue
    }
    func entry(on day: Date) -> FocusTaskProgress? {
        let start = Calendar.current.startOfDay(for: day).timeIntervalSince1970
        return (progress ?? []).first { $0.day == start }
    }
}

struct DeletedFocusTask {
    var task: FocusTask
    var linkedRecordIDs: Set<String>
}
enum FocusTaskError: LocalizedError {
    case invalidTitle, missing, active, limit, progressDate
    var errorDescription: String? {
        switch self {
        case .invalidTitle: return "Escribí un nombre de entre 1 y 160 caracteres, en una sola línea."
        case .missing: return "Elegí una tarea pendiente. Puede que se haya completado o archivado."
        case .active: return "Primero terminá la sesión de esta tarea. Su tiempo sigue en curso."
        case .limit: return "Se alcanzó el límite de 5000 tareas guardadas."
        case .progressDate: return "El avance debe estar entre 0 y 100%, para hoy o un día anterior."
        }
    }
}
struct FocusState: Codable {
    var session: FocusSession?
    var records: [FocusRecord] = []
    var tasks: [FocusTask]? = nil
    var goals: [FocusGoal]? = nil
    var pendingQualityRecordID: String? = nil
    var bridgeSeen: Double = 0
    var appliedID: String = ""
    var browserError: String?
    var appBlockStatus: String?
    var ownerProfile: String? // Native-port profile token; other profiles cannot acknowledge this session.
    var revision: Int = 0
    var configuration: BlockConfiguration? = nil
    var grantedHosts: [String]? = nil
    var deletedAchievementObligations: [FocusAchievementObligation]? = nil
    mutating func finish(at now: Double, completed: Bool) {
        guard let s = session else { return }
        records.insert(FocusRecord(id: s.id, startedAt: s.startedAt, seconds: s.elapsed(at: now), completed: completed, targetSeconds: s.duration, intervals: s.intervals(at: now), taskID: s.taskID, goalID: s.goalID), at: 0)
        pendingQualityRecordID = s.id
        session = nil; revision += 1
    }
    mutating func expire(at now: Double) { if session?.expired(at: now) == true { finish(at: now, completed: true) } }
}
enum FocusQualityError: LocalizedError {
    case invalidRating, missingRecord

    var errorDescription: String? {
        switch self {
        case .invalidRating: return "Elegí una valoración del 1 al 10."
        case .missingRecord: return "Esa sesión ya no está disponible."
        }
    }
}
enum FocusError: LocalizedError {
    case unavailable, busy, firm, invalidDuration, corrupt, profile
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Conectá el complemento de Chrome antes de iniciar. El bloqueo todavía no está listo."
        case .busy: return "Ya hay una sesión en curso."
        case .firm: return "Esta sesión firme termina cuando se cumple el tiempo elegido."
        case .invalidDuration: return "Elegí entre 1 y 180 minutos. El modo firme necesita una duración."
        case .corrupt: return "No se pudo leer la sesión guardada. No iniciamos un bloqueo nuevo."
        case .profile: return "Este perfil de Chrome no es el vinculado a Foco."
        }
    }
}
final class FocusStore {
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Foco", isDirectory: true)
    }
    func transaction<T>(_ body: (inout FocusState) throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let lockURL = directory.appendingPathComponent("state.lock")
        let fd = open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw FocusError.corrupt }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw FocusError.corrupt }
        defer { flock(fd, LOCK_UN) }
        let url = directory.appendingPathComponent("state.json")
        var state: FocusState
        if FileManager.default.fileExists(atPath: url.path) {
            guard let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(FocusState.self, from: data) else { throw FocusError.corrupt }
            state = decoded
        } else { state = FocusState() }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(state)
        let result = try body(&state)
        let data = try encoder.encode(state)
        if data != before || !FileManager.default.fileExists(atPath: url.path) {
            try data.write(to: url, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        return result
    }
    func read(now: Double = Date().timeIntervalSince1970) throws -> FocusState {
        try transaction { state in
            state.expire(at: now)
            if state.configuration == nil { state.configuration = BlockConfiguration.initial() }
            return state
        }
    }
    func start(duration: Double?, firm: Bool, blockWhatsAppApp: Bool = false, blockWhatsAppWeb: Bool = false, useConfiguration: Bool = false, taskID: String? = nil, goalID: String? = nil, now: Double = Date().timeIntervalSince1970) throws {
        try transaction { state in
            state.expire(at: now)
            guard state.session == nil else { throw FocusError.busy }
            guard now - state.bridgeSeen < 8, state.ownerProfile != nil, state.browserError == nil else { throw FocusError.unavailable }
            guard (!firm || duration != nil), duration.map({ $0 >= 60 && $0 <= 10_800 && $0.isFinite }) ?? true else { throw FocusError.invalidDuration }
            var session = FocusSession(startedAt: now, duration: duration, firm: firm, blockWhatsAppApp: blockWhatsAppApp, blockWhatsAppWeb: blockWhatsAppWeb)
            if let taskID {
                guard let task = (state.tasks ?? []).first(where: { $0.id == taskID && $0.completedAt == nil && $0.archivedAt == nil }) else { throw FocusTaskError.missing }
                if let assigned = task.goalID, let goalID, assigned != goalID { throw FocusGoalError.conflict }
                session.taskID = taskID
                session.goalID = task.goalID ?? goalID
            } else {
                session.goalID = goalID
            }
            try state.requireOpenGoal(session.goalID)
            if useConfiguration {
                let config = state.configuration ?? BlockConfiguration.initial()
                session.sites = try config.sites.filter(\.enabled).map { try $0.validated() }
                session.applications = try config.applications.filter(\.enabled).map { try $0.validated() }
                guard !(session.sites!.isEmpty && session.applications!.isEmpty) else { throw RuleError.empty }
                let granted = Set(state.grantedHosts ?? [])
                guard session.sites!.allSatisfy({ granted.contains($0.host) }) else { throw RuleError.missingPermission }
            }
            state.session = session
            state.revision += 1
        }
    }
    func stop(now: Double = Date().timeIntervalSince1970) throws {
        try transaction { state in
            state.expire(at: now)
            guard state.session?.firm != true else { throw FocusError.firm }
            state.finish(at: now, completed: false)
        }
    }
    func setPaused(_ paused: Bool, now: Double = Date().timeIntervalSince1970) throws {
        try transaction { state in
            state.expire(at: now)
            guard var session = state.session, session.isPaused != paused else { return }
            if paused { session.pausedAt = max(session.startedAt, now) }
            else if let began = session.pausedAt {
                session.pauses = (session.pauses ?? []) + [FocusInterval(start: began, end: max(began, now))]
                session.pausedAt = nil
            }
            state.session = session
            state.revision += 1
        }
    }
    func setRecordReview(id: String, rating: Int?, difficulty: FocusDifficulty?) throws {
        if let rating, !(1...10).contains(rating) { throw FocusQualityError.invalidRating }
        try transaction { state in
            guard let index = state.records.firstIndex(where: { $0.id == id }) else { throw FocusQualityError.missingRecord }
            state.records[index].qualityRating = rating
            state.records[index].difficulty = difficulty
            if state.pendingQualityRecordID == id { state.pendingQualityRecordID = nil }
            state.revision += 1
        }
    }
    func deleteRecord(id: String) throws -> FocusRecord? {
        try transaction { state in
            guard let index = state.records.firstIndex(where: { $0.id == id }) else { return nil }
            let record = state.records.remove(at: index)
            if state.pendingQualityRecordID == id { state.pendingQualityRecordID = nil }
            state.revision += 1
            return record
        }
    }
    func restoreRecord(_ record: FocusRecord) throws {
        try transaction { state in
            guard !state.records.contains(where: { $0.id == record.id }) else { return }
            var restored = record
            if let taskID = restored.taskID, !(state.tasks ?? []).contains(where: { $0.id == taskID }) { restored.taskID = nil }
            if let goalID = restored.goalID, !(state.goals ?? []).contains(where: { $0.id == goalID }) { restored.goalID = nil }
            state.records.append(restored)
            state.records.sort { $0.startedAt > $1.startedAt }
            state.revision += 1
        }
    }
    private func taskTitle(_ title: String) throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 160,
              trimmed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { throw FocusTaskError.invalidTitle }
        return trimmed
    }
    @discardableResult
    func addTask(title: String, day: Date, goalID: String? = nil, now: Double = Date().timeIntervalSince1970) throws -> FocusTask {
        let name = try taskTitle(title)
        guard day.timeIntervalSince1970.isFinite else { throw FocusTaskError.missing }
        return try transaction { state in
            guard (state.tasks ?? []).count < 5000 else { throw FocusTaskError.limit }
            try state.requireOpenGoal(goalID)
            let plannedDay = Calendar.current.startOfDay(for: day).timeIntervalSince1970
            let task = FocusTask(title: name, plannedFor: plannedDay, createdAt: now, achievementPlannedFor: plannedDay, goalID: goalID)
            state.tasks = (state.tasks ?? []) + [task]
            state.revision += 1
            return task
        }
    }
    func editTask(id: String, title: String, day: Date, goal: TaskGoalAssignment = .unchanged) throws {
        let name = try taskTitle(title)
        guard day.timeIntervalSince1970.isFinite else { throw FocusTaskError.missing }
        try transaction { state in
            guard let index = state.tasks?.firstIndex(where: { $0.id == id }) else { throw FocusTaskError.missing }
            if case let .set(goalID, includePrevious) = goal {
                if state.tasks![index].goalID != goalID || includePrevious {
                    guard state.session?.taskID != id else { throw FocusTaskError.active }
                    try state.requireOpenGoal(goalID)
                    state.tasks![index].goalID = goalID
                    if let goalID, includePrevious {
                        for recordIndex in state.records.indices where state.records[recordIndex].taskID == id && state.records[recordIndex].goalID == nil {
                            state.records[recordIndex].goalID = goalID
                        }
                    }
                }
            }
            if state.tasks![index].achievementPlannedFor == nil {
                state.tasks![index].achievementPlannedFor = state.tasks![index].plannedFor
            }
            state.tasks![index].title = name
            state.tasks![index].plannedFor = Calendar.current.startOfDay(for: day).timeIntervalSince1970
            state.revision += 1
        }
    }
    func setTaskCompleted(id: String, completed: Bool, now: Double = Date().timeIntervalSince1970) throws {
        try setTaskProgress(id: id, percent: completed ? 100 : 0, day: Date(timeIntervalSince1970: now), now: now)
    }
    func setTaskProgress(id: String, percent: Int, day: Date, now: Double = Date().timeIntervalSince1970) throws {
        let date = Calendar.current.startOfDay(for: day)
        let today = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: now))
        guard (0...100).contains(percent), date.timeIntervalSince1970.isFinite, date <= today else { throw FocusTaskError.progressDate }
        try transaction { state in
            state.expire(at: now)
            if percent == 100 && state.session?.taskID == id { throw FocusTaskError.active }
            guard let index = state.tasks?.firstIndex(where: { $0.id == id }), state.tasks![index].archivedAt == nil else { throw FocusTaskError.missing }
            var task = state.tasks![index]
            var entries = task.progress ?? []
            entries.removeAll { $0.day == date.timeIntervalSince1970 }
            entries.append(FocusTaskProgress(day: date.timeIntervalSince1970, percent: percent, recordedAt: now))
            entries.sort { $0.day < $1.day }
            task.progress = entries
            // Editing a past entry must not overwrite a more recent status.
            if let latest = entries.last {
                if latest.percent == 100 {
                    task.completedAt = latest.day == today.timeIntervalSince1970 ? latest.recordedAt : latest.day
                } else { task.completedAt = nil }
            }
            state.tasks![index] = task
            state.revision += 1
        }
    }
    func deleteTask(id: String, now: Double = Date().timeIntervalSince1970) throws -> DeletedFocusTask? {
        try transaction { state in
            state.expire(at: now)
            guard state.session?.taskID != id else { throw FocusTaskError.active }
            guard let index = state.tasks?.firstIndex(where: { $0.id == id }) else { return nil }
            let tombstones = state.deletedAchievementObligations ?? []
            guard tombstones.count < 5000 else { throw FocusTaskError.limit }
            let task = state.tasks![index]
            let obligation = FocusAchievementObligation.from(task: task, now: Date(timeIntervalSince1970: now))
            var updatedTombstones = tombstones.filter { $0.id != id }
            updatedTombstones.append(obligation)
            state.deletedAchievementObligations = updatedTombstones
            state.tasks!.remove(at: index)
            let links = Set(state.records.filter { $0.taskID == id }.map(\.id))
            for index in state.records.indices where state.records[index].taskID == id { state.records[index].taskID = nil }
            state.revision += 1
            return DeletedFocusTask(task: task, linkedRecordIDs: links)
        }
    }
    func restoreTask(_ deleted: DeletedFocusTask) throws {
        try transaction { state in
            if var tombstones = state.deletedAchievementObligations {
                tombstones.removeAll { $0.id == deleted.task.id }
                state.deletedAchievementObligations = tombstones
            }
            guard !(state.tasks ?? []).contains(where: { $0.id == deleted.task.id }) else { return }
            guard (state.tasks ?? []).count < 5000 else { throw FocusTaskError.limit }
            var restored = deleted.task
            if let goalID = restored.goalID, !(state.goals ?? []).contains(where: { $0.id == goalID }) { restored.goalID = nil }
            state.tasks = (state.tasks ?? []) + [restored]
            for index in state.records.indices where deleted.linkedRecordIDs.contains(state.records[index].id) && state.records[index].taskID == nil {
                state.records[index].taskID = deleted.task.id
            }
            state.revision += 1
        }
    }
    func setTaskArchived(id: String, archived: Bool, now: Double = Date().timeIntervalSince1970) throws {
        try transaction { state in
            state.expire(at: now)
            guard state.session?.taskID != id else { throw FocusTaskError.active }
            guard let index = state.tasks?.firstIndex(where: { $0.id == id }) else { throw FocusTaskError.missing }
            state.tasks![index].archivedAt = archived ? now : nil
            state.revision += 1
        }
    }
    func acknowledge(profile: String, appliedID: String, error: String?, grantedHosts: [String]? = nil, now: Double = Date().timeIntervalSince1970) throws {
        try transaction { state in
            if let owner = state.ownerProfile, owner != profile { throw FocusError.profile }
            state.ownerProfile = profile
            if let grantedHosts { state.grantedHosts = Array(Set(grantedHosts.filter(BlockedSite.validHost))).sorted() }
            state.bridgeSeen = now; state.appliedID = appliedID; state.browserError = error
        }
    }
    func updateConfiguration(_ config: BlockConfiguration) throws {
        guard config.sites.count <= 100, config.applications.count <= 50 else { throw RuleError.limit }
        let sites = try config.sites.map { try $0.validated() }
        let apps = try config.applications.map { try $0.validated() }
        try transaction { state in
            state.expire(at: Date().timeIntervalSince1970)
            guard state.session == nil else { throw FocusError.busy }
            state.configuration = BlockConfiguration(sites: sites, applications: apps)
            state.revision += 1
        }
    }
    func todaySeconds(now: Date = Date(), state: FocusState) -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now).timeIntervalSince1970
        let end = calendar.date(byAdding: .day, value: 1, to: Date(timeIntervalSince1970: start))!.timeIntervalSince1970
        var total = state.records.flatMap(\.activeIntervals).reduce(0.0) { $0 + $1.overlap(from: start, to: end) }
        if let session = state.session { total += session.intervals(at: now.timeIntervalSince1970).reduce(0) { $0 + $1.overlap(from: start, to: end) } }
        return total
    }
}
func clockString(_ seconds: Double) -> String {
    let n = max(0, Int(seconds))
    if n >= 3600 { return String(format: "%d:%02d:%02d", n/3600, (n/60)%60, n%60) }
    return String(format: "%02d:%02d", n/60, n%60)
}
