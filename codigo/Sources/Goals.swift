import Foundation

enum GoalOutcome: String, Codable, CaseIterable, Identifiable {
    case achieved, partial, notAchieved
    var id: Self { self }
    var title: String {
        switch self { case .achieved: return "Cumplido"; case .partial: return "Parcial"; case .notAchieved: return "No cumplido" }
    }
    var symbol: String {
        switch self { case .achieved: return "checkmark.seal"; case .partial: return "circle.lefthalf.filled"; case .notAchieved: return "circle.dashed" }
    }
}
struct FocusGoal: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var title: String
    var targetSeconds: Double?
    var createdAt: Double
    var closedAt: Double? = nil
    var outcome: GoalOutcome? = nil
    var resultNote: String? = nil
}
enum TaskGoalAssignment {
    case unchanged
    case set(String?, includePrevious: Bool)
}
struct DeletedFocusGoal {
    var goal: FocusGoal
    var taskIDs: Set<String>
    var recordIDs: Set<String>
}
enum FocusGoalError: LocalizedError {
    case title, hours, missing, closed, active, limit, note, conflict, recordMissing
    var errorDescription: String? {
        switch self {
        case .title: return "Escribí un objetivo de entre 1 y 160 caracteres, en una sola línea."
        case .hours: return "La meta debe ser mayor que cero y de hasta 100.000 horas."
        case .missing: return "El objetivo ya no está disponible."
        case .closed: return "Este objetivo está cerrado. Elegí otro o quitá la asociación de la tarea."
        case .active: return "Primero terminá el bloque de este objetivo. Su tiempo sigue en curso."
        case .limit: return "Se alcanzó el límite de 500 objetivos guardados."
        case .note: return "La nota puede tener hasta 2.000 caracteres de texto."
        case .conflict: return "La tarea pertenece a otro objetivo. Elegí la tarea o el objetivo correspondiente."
        case .recordMissing: return "Ese bloque ya no está disponible."
        }
    }
}
extension FocusState {
    func requireOpenGoal(_ id: String?) throws {
        guard let id else { return }
        guard let goal = (goals ?? []).first(where: { $0.id == id }) else { throw FocusGoalError.missing }
        guard goal.closedAt == nil else { throw FocusGoalError.closed }
    }
    // Records own their association: moving a task never moves its past focus time.
    func filtered(forGoal id: String?) -> FocusState {
        guard let id else { return self }
        var filtered = self
        filtered.records = records.filter { $0.goalID == id }
        if session?.goalID != id { filtered.session = nil }
        var referenced = Set(filtered.records.compactMap(\.taskID))
        if let taskID = filtered.session?.taskID { referenced.insert(taskID) }
        filtered.tasks = (tasks ?? []).filter { $0.goalID == id || referenced.contains($0.id) }
        return filtered
    }
}
struct GoalMetrics {
    let seconds: Double
    init(state: FocusState, goalID: String, now: Date, interval: DateInterval? = nil) {
        let lower = interval?.start.timeIntervalSince1970 ?? -Double.greatestFiniteMagnitude
        let upper = min(interval?.end.timeIntervalSince1970 ?? now.timeIntervalSince1970, now.timeIntervalSince1970)
        var total = state.records.filter { $0.goalID == goalID }.reduce(0.0) { sum, record in
            sum + record.activeIntervals.reduce(0) { $0 + $1.overlap(from: lower, to: upper) }
        }
        if let session = state.session, session.goalID == goalID {
            total += session.intervals(at: now.timeIntervalSince1970).reduce(0) { $0 + $1.overlap(from: lower, to: upper) }
        }
        seconds = total
    }
}
extension FocusStore {
    func assignRecordGoal(id: String, goalID: String?) throws {
        try transaction { state in
            guard let index = state.records.firstIndex(where: { $0.id == id }) else { throw FocusGoalError.recordMissing }
            if let goalID, !(state.goals ?? []).contains(where: { $0.id == goalID }) { throw FocusGoalError.missing }
            state.records[index].goalID = goalID
            state.revision += 1
        }
    }
    private func goalFields(title: String, hours: Double?) throws -> (String, Double?) {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 160, !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw FocusGoalError.title }
        if let hours { guard hours.isFinite, hours > 0, hours <= 100_000 else { throw FocusGoalError.hours } }
        return (name, hours.map { $0 * 3600 })
    }
    @discardableResult
    func addGoal(title: String, targetHours: Double?, now: Double = Date().timeIntervalSince1970) throws -> FocusGoal {
        let fields = try goalFields(title: title, hours: targetHours)
        guard now.isFinite else { throw FocusGoalError.missing }
        return try transaction { state in
            guard (state.goals ?? []).count < 500 else { throw FocusGoalError.limit }
            let goal = FocusGoal(title: fields.0, targetSeconds: fields.1, createdAt: now)
            state.goals = (state.goals ?? []) + [goal]; state.revision += 1
            return goal
        }
    }
    func editGoal(id: String, title: String, targetHours: Double?) throws {
        let fields = try goalFields(title: title, hours: targetHours)
        try transaction { state in
            guard let index = state.goals?.firstIndex(where: { $0.id == id }) else { throw FocusGoalError.missing }
            state.goals![index].title = fields.0; state.goals![index].targetSeconds = fields.1; state.revision += 1
        }
    }
    func closeGoal(id: String, outcome: GoalOutcome, note: String, now: Double = Date().timeIntervalSince1970) throws {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count <= 2000, text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\t" }) else { throw FocusGoalError.note }
        try transaction { state in
            state.expire(at: now)
            guard let index = state.goals?.firstIndex(where: { $0.id == id }), now.isFinite, now >= state.goals![index].createdAt else { throw FocusGoalError.missing }
            guard state.session?.goalID != id else { throw FocusGoalError.active }
            state.goals![index].closedAt = state.goals![index].closedAt ?? now
            state.goals![index].outcome = outcome; state.goals![index].resultNote = text.isEmpty ? nil : text
            state.revision += 1
        }
    }
    func deleteGoal(id: String, now: Double = Date().timeIntervalSince1970) throws -> DeletedFocusGoal? {
        try transaction { state in
            state.expire(at: now)
            guard state.session?.goalID != id else { throw FocusGoalError.active }
            guard let index = state.goals?.firstIndex(where: { $0.id == id }) else { return nil }
            let goal = state.goals!.remove(at: index)
            let taskIDs = Set((state.tasks ?? []).filter { $0.goalID == id }.map(\.id))
            let recordIDs = Set(state.records.filter { $0.goalID == id }.map(\.id))
            for i in (state.tasks ?? []).indices where state.tasks![i].goalID == id { state.tasks![i].goalID = nil }
            for i in state.records.indices where state.records[i].goalID == id { state.records[i].goalID = nil }
            state.revision += 1
            return DeletedFocusGoal(goal: goal, taskIDs: taskIDs, recordIDs: recordIDs)
        }
    }
    func restoreGoal(_ deleted: DeletedFocusGoal) throws {
        try transaction { state in
            guard !(state.goals ?? []).contains(where: { $0.id == deleted.goal.id }) else { return }
            guard (state.goals ?? []).count < 500 else { throw FocusGoalError.limit }
            state.goals = (state.goals ?? []) + [deleted.goal]
            for i in (state.tasks ?? []).indices where deleted.taskIDs.contains(state.tasks![i].id) && state.tasks![i].goalID == nil { state.tasks![i].goalID = deleted.goal.id }
            for i in state.records.indices where deleted.recordIDs.contains(state.records[i].id) && state.records[i].goalID == nil { state.records[i].goalID = deleted.goal.id }
            state.revision += 1
        }
    }
}
