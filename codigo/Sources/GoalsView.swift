import SwiftUI

struct GoalMenu: View {
    @EnvironmentObject var model: FocoModel
    @Binding var selection: String?
    var currentGoalID: String? = nil
    var body: some View {
        Picker("Objetivo", selection: $selection) {
            Text("Sin objetivo").tag(nil as String?)
            ForEach(model.openGoals) { goal in Text(goal.title).tag(Optional(goal.id)) }
            if let current = model.goals.first(where: { $0.id == currentGoalID && $0.closedAt != nil }) {
                Text("\(current.title) · cerrado").tag(Optional(current.id))
            }
        }.pickerStyle(.menu).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GoalsView: View {
    @EnvironmentObject var model: FocoModel
    @ViewState private var showCreate = false
    @ViewState private var editing: FocusGoal?
    @ViewState private var finishing: FocusGoal?
    @ViewState private var showClosed = false
    @ViewState private var visible = 20
    var listed: [FocusGoal] { model.goals.filter { ($0.closedAt != nil) == showClosed } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Mis objetivos").font(.system(size: 26, weight: .medium, design: .rounded)).tracking(-1)
                Text("Conectá tu tiempo de foco con lo que querés conseguir.").font(.system(size: 14)).foregroundStyle(Color.focoSecondary)
            }
            HStack {
                Picker("Estado", selection: $showClosed) {
                    Text("En curso").tag(false); Text("Con resultado").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 280)
                Spacer(minLength: 8)
                Button { showCreate = true } label: { Label("Nuevo", systemImage: "plus") }
                    .buttonStyle(FocoPrimaryStyle()).accessibilityLabel("Nuevo objetivo")
            }
            if model.deletedGoal != nil {
                HStack {
                    Text("Objetivo borrado. Las tareas y el tiempo se conservan.").font(.system(size: 12))
                    Spacer()
                    Button("Deshacer") { model.undoGoalDelete() }.buttonStyle(FocoSecondaryStyle())
                    Button { model.dismissGoalUndo() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Cerrar aviso de objetivo borrado")
                }.padding(16).panel()
            }
            if listed.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label(showClosed ? "Todavía no cerraste un objetivo" : "¿Qué querés conseguir?", systemImage: "target")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                    Text(showClosed ? "Al cerrar uno, acá vas a ver sus horas y el resultado que registraste." : "Por ejemplo: Aprobar IPSC. Podés fijar una meta de horas, sumar varias tareas y registrar el resultado al terminar.")
                        .font(.system(size: 13)).foregroundStyle(Color.focoSecondary)
                    if !showClosed { Button(model.goals.isEmpty ? "Crear mi primer objetivo" : "Crear otro objetivo") { showCreate = true }.buttonStyle(FocoPrimaryStyle()) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(22).panel()
            }
            ForEach(Array(listed.prefix(visible))) { goal in
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        Text(goal.title).font(.system(size: 20, weight: .medium, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 10)
                        Menu {
                            Button("Editar objetivo") { editing = goal }
                            Button(goal.closedAt == nil ? "Registrar resultado" : "Editar resultado") { finishing = goal }
                                .disabled(model.session?.goalID == goal.id)
                            Divider()
                            Button("Borrar objetivo", role: .destructive) { model.deleteGoal(goal) }
                                .disabled(model.session?.goalID == goal.id)
                        } label: { Image(systemName: "ellipsis").frame(width: 28, height: 28) }
                            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
                            .accessibilityLabel("Opciones de \(goal.title)")
                    }
                    GoalTimeSummary(goal: goal, seconds: model.goalSeconds(goal.id))
                    let count = model.tasks.filter { $0.goalID == goal.id }.count
                    Text("\(count) \(count == 1 ? "tarea asociada" : "tareas asociadas")")
                        .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                    if let note = goal.resultNote, !note.isEmpty {
                        DisclosureGroup("Nota del resultado") { Text(note).font(.system(size: 12)).textSelection(.enabled).padding(.top, 8) }
                            .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                    }
                    if goal.closedAt == nil {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) { actions(goal) }
                            VStack(alignment: .leading, spacing: 10) { actions(goal) }
                        }
                    }
                }.padding(22).panel()
            }
            if listed.count > visible { Button("Mostrar más objetivos") { visible += 20 }.buttonStyle(FocoSecondaryStyle()) }
            Text("Las horas registran dedicación. El resultado lo evaluás vos: llegar a la meta de horas no completa el objetivo automáticamente.")
                .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
        }
        .sheet(isPresented: $showCreate) { GoalEditSheet().environmentObject(model) }
        .sheet(item: $editing) { GoalEditSheet(goal: $0).environmentObject(model) }
        .sheet(item: $finishing) { GoalResultSheet(goal: $0).environmentObject(model) }
    }
    @ViewBuilder func actions(_ goal: FocusGoal) -> some View {
        Button(model.session?.goalID == goal.id ? "En foco ahora" : "Concentrarme en esto") { model.chooseGoal(goal) }
            .buttonStyle(FocoPrimaryStyle()).disabled(model.session != nil)
        Button("Registrar resultado") { finishing = goal }.buttonStyle(FocoSecondaryStyle())
            .disabled(model.session?.goalID == goal.id)
    }
}

struct GoalTimeSummary: View {
    let goal: FocusGoal
    let seconds: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) { timeLabels }
                VStack(alignment: .leading, spacing: 5) { timeLabels }
            }
            if let target = goal.targetSeconds {
                ProgressView(value: min(1, seconds / max(1, target))).tint(Color.foco)
                    .accessibilityLabel("Tiempo dedicado frente a la meta de horas")
                Text(comparison(target))
                    .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
            }
            if let outcome = goal.outcome {
                Label("Resultado: \(outcome.title)", systemImage: outcome.symbol)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(outcome == .achieved ? Color.foco : Color.focoSecondary)
                if let closedAt = goal.closedAt { Text("Cerrado el \(Date(timeIntervalSince1970: closedAt).formatted(date: .abbreviated, time: .omitted))").font(.system(size: 11)).foregroundStyle(Color.focoSecondary) }
            } else { Text("Resultado pendiente").font(.system(size: 12)).foregroundStyle(Color.focoSecondary) }
        }
    }
    private func comparison(_ target: Double) -> String {
        if goal.closedAt != nil {
            if seconds == target { return "Tiempo planificado alcanzado" }
            return "\(durationLabel(abs(seconds - target))) \(seconds > target ? "más" : "menos") que lo planificado"
        }
        return seconds >= target ? "Meta de horas alcanzada" : "Faltan \(durationLabel(target - seconds)) para tu meta de horas"
    }
    @ViewBuilder var timeLabels: some View {
        Text(durationLabel(seconds)).font(.system(size: 28, weight: .light, design: .rounded)).monospacedDigit()
        Text(goal.targetSeconds.map { "de \(durationLabel($0)) planificados" } ?? "de foco acumulado")
            .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
    }
}

struct GoalEditSheet: View {
    @EnvironmentObject var model: FocoModel
    @Environment(\.dismiss) var dismiss
    let goal: FocusGoal?
    @ViewState private var title: String
    @ViewState private var hasTarget: Bool
    @ViewState private var hours: String
    @ViewState private var errorText: String?
    init(goal: FocusGoal? = nil) {
        self.goal = goal
        _title = ViewState(initialValue: goal?.title ?? "")
        _hasTarget = ViewState(initialValue: goal?.targetSeconds != nil || goal == nil)
        _hours = ViewState(initialValue: goal?.targetSeconds.map { String(format: "%g", $0 / 3600) } ?? "20")
    }
    var parsedHours: Double? { Double(hours.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
    var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 160 &&
        (!hasTarget || parsedHours.map { $0.isFinite && $0 > 0 && $0 <= 100_000 } == true)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(goal == nil ? "Nuevo objetivo" : "Editar objetivo").font(.system(size: 24, weight: .medium, design: .rounded))
            TextField("Por ejemplo: Aprobar IPSC", text: $title).textFieldStyle(.roundedBorder).accessibilityLabel("Nombre del objetivo")
            Toggle("Definir una meta de horas", isOn: $hasTarget)
            if hasTarget {
                HStack { TextField("Horas", text: $hours).textFieldStyle(.roundedBorder).frame(maxWidth: 100).accessibilityLabel("Meta de horas"); Text("horas de foco") }
                Text("Podés usar decimales: 1,5 equivale a una hora y media.").font(.system(size: 11)).foregroundStyle(Color.focoSecondary)
            }
            Text("Sumá bloques directamente o asociá tareas. Las pausas no cuentan.").font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
            if let errorText { Text(errorText).font(.system(size: 12)).foregroundStyle(.red) }
            HStack {
                Button("Cancelar") { dismiss() }.buttonStyle(.plain).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Guardar") {
                    if model.saveGoal(goal, title: title, hours: hasTarget ? parsedHours : nil) { dismiss() }
                    else { errorText = model.error; model.error = nil }
                }.buttonStyle(FocoPrimaryStyle()).disabled(!valid).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 360)
    }
}

struct GoalResultSheet: View {
    @EnvironmentObject var model: FocoModel
    @Environment(\.dismiss) var dismiss
    let goal: FocusGoal
    @ViewState private var outcome: GoalOutcome?
    @ViewState private var note: String
    @ViewState private var errorText: String?
    init(goal: FocusGoal) {
        self.goal = goal
        _outcome = ViewState(initialValue: goal.outcome)
        _note = ViewState(initialValue: goal.resultNote ?? "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resultado del objetivo").font(.system(size: 24, weight: .medium, design: .rounded))
            Text(goal.title).font(.system(size: 14, weight: .medium))
            Text("Dedicaste \(durationLabel(model.goalSeconds(goal.id)))\(goal.targetSeconds.map { " de \(durationLabel($0)) planificados" } ?? "").")
                .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
            Picker("Resultado", selection: $outcome) {
                Text("Elegí un resultado").tag(nil as GoalOutcome?)
                ForEach(GoalOutcome.allCases) { Text($0.title).tag(Optional($0)) }
            }.pickerStyle(.menu)
            Text("Nota opcional").font(.system(size: 12, weight: .medium))
            TextEditor(text: $note).font(.system(size: 13)).frame(height: 100).border(Color.secondary.opacity(0.25)).accessibilityLabel("Nota del resultado")
            Text("\(note.count)/2000 caracteres").font(.system(size: 11)).foregroundStyle(note.count > 2000 ? .red : Color.focoSecondary)
            Text("El resultado es tu evaluación. Al guardar, el objetivo deja de aceptar bloques nuevos.").font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
            if let errorText { Text(errorText).font(.system(size: 12)).foregroundStyle(.red) }
            HStack {
                Button("Cancelar") { dismiss() }.buttonStyle(.plain).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Guardar resultado") {
                    guard let outcome else { return }
                    if model.finishGoal(goal, outcome: outcome, note: note) { dismiss() }
                    else { errorText = model.error; model.error = nil }
                }.buttonStyle(FocoPrimaryStyle()).disabled(note.count > 2000 || outcome == nil).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 360)
    }
}
