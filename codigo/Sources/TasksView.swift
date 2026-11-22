import SwiftUI

enum FocoSection: String, CaseIterable, Identifiable {
    case focus = "Concentrarme", tasks = "Mis tareas", goals = "Mis objetivos", progress = "Mi progreso"
    var id: Self { self }
    var navigationTitle: String {
        switch self { case .focus: return "Foco"; case .tasks: return "Tareas"; case .goals: return "Objetivos"; case .progress: return "Progreso" }
    }
}

struct TaskSessionPicker: View {
    @EnvironmentObject var model: FocoModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let session = model.session {
                Label(model.goalName(session.goalID), systemImage: "target")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.focoSecondary)
            } else {
                HStack {
                    Text("Objetivo de este bloque").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button("Mis objetivos") { model.section = .goals }.buttonStyle(.plain).foregroundStyle(Color.foco)
                        .font(.system(size: 12, weight: .medium))
                }
                GoalMenu(selection: Binding(get: { model.selectedGoalID }, set: { model.chooseGoalID($0) }))
                    .labelsHidden()
            }
            if let session = model.session {
                Label(model.taskName(session.taskID), systemImage: session.taskID == nil ? "circle.dashed" : "checklist")
                    .font(.system(size: 13, weight: .medium)).fixedSize(horizontal: false, vertical: true)
            } else {
                HStack {
                    Text("Tarea de este bloque").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button("Mis tareas") { model.section = .tasks }.buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.foco)
                }
                Picker("Tarea de este bloque", selection: $model.selectedTaskID) {
                    Text("Sin tarea · solo concentrarme").tag(nil as String?)
                    ForEach(model.availableTasks) { task in Text(task.title).tag(Optional(task.id)) }
                }.pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                    .help(model.taskName(model.selectedTaskID))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TasksView: View {
    @EnvironmentObject var model: FocoModel
    @ViewState private var day = Date()
    @ViewState private var title = ""
    @ViewState private var editing: FocusTask?
    @ViewState private var recording: FocusTask?
    @ViewState private var showArchived = false
    @ViewState private var newGoalID: String?
    var interval: DateInterval { Calendar.current.dateInterval(of: .day, for: day)! }
    var report: TaskMetrics { TaskMetrics(state: model.state, now: model.now, interval: interval) }
    var listed: [FocusTask] {
        return model.tasks.filter { task in
            guard (task.archivedAt != nil) == showArchived else { return false }
            return task.appears(on: day, now: model.now)
        }.sorted {
            if ($0.completedAt != nil) != ($1.completedAt != nil) { return $0.completedAt == nil }
            return $0.createdAt < $1.createdAt
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Mis tareas").font(.system(size: 26, weight: .medium, design: .rounded)).tracking(-1)
                Text("Un lugar para planificar, concentrarte y registrar tu avance.").font(.system(size: 14)).foregroundStyle(Color.focoSecondary)
            }
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack { dayPicker; Spacer(); todayButton }
                    VStack(alignment: .leading, spacing: 10) { dayPicker; todayButton }
                }
                HStack(alignment: .top) {
                    TextField("¿Qué querés hacer?", text: $title).textFieldStyle(.roundedBorder).onSubmit(add)
                        .accessibilityLabel("Nombre de la nueva tarea")
                    Button("Agregar", action: add).buttonStyle(FocoPrimaryStyle())
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                GoalMenu(selection: $newGoalID)
            }.padding(18).panel()
                .onChange(of: model.state.revision) { _, _ in
                    if let newGoalID, !model.openGoals.contains(where: { $0.id == newGoalID }) { self.newGoalID = nil }
                }
            HStack(spacing: 0) {
                taskStat("Completadas", value: "\(report.completed)")
                taskStat("Pendientes", value: "\(listed.filter { $0.completedAt == nil && $0.archivedAt == nil }.count)")
                taskStat("Foco en tareas", value: durationLabel(report.assignedSeconds))
            }.padding(.vertical, 4)
            if let deleted = model.deletedTask {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tarea borrada. Su tiempo de foco se conserva.")
                        .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Deshacer") { model.undoTaskDelete() }.buttonStyle(FocoSecondaryStyle())
                        Spacer()
                        Button { model.dismissTaskUndo() } label: { Image(systemName: "xmark").frame(width: 24, height: 24) }
                            .buttonStyle(.plain).accessibilityLabel("Cerrar aviso de tarea borrada")
                    }
                }.padding(16).panel().help(deleted.task.title)
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(showArchived ? "Archivadas" : "Tareas del día").font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Toggle("Archivadas", isOn: $showArchived).toggleStyle(.checkbox).font(.system(size: 12))
                }
                if listed.isEmpty {
                    VStack(spacing: 9) {
                        Image(systemName: showArchived ? "archivebox" : "checklist").font(.system(size: 25, weight: .light)).foregroundStyle(Color.foco)
                        Text(showArchived ? "No hay tareas archivadas" : "¿Qué querés hacer hoy?").font(.system(size: 15, weight: .medium))
                        Text(showArchived ? "Elegí otro día para revisar tu archivo." : "Agregá tu primera tarea en el campo de arriba.")
                            .font(.system(size: 12)).foregroundStyle(Color.focoSecondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 26)
                }
                LazyVStack(spacing: 0) {
                    ForEach(listed) { task in
                        taskRow(task)
                        Divider().opacity(0.4).padding(.vertical, 12)
                    }
                }
                DisclosureGroup("Sobre fechas y tiempos") {
                    Text("El tiempo junto a cada tarea suma todos sus bloques. Hoy también aparecen las pendientes de días anteriores. El porcentaje corresponde al día elegido.")
                        .font(.system(size: 12)).foregroundStyle(Color.focoSecondary).padding(.top, 8)
                }.font(.system(size: 12))
            }.padding(22).panel()
        }
        .sheet(item: $editing) { task in TaskEditSheet(task: task).environmentObject(model) }
        .sheet(item: $recording) { task in TaskProgressSheet(task: task, day: day).environmentObject(model) }
    }
    var dayPicker: some View { DatePicker("Día", selection: $day, displayedComponents: .date).datePickerStyle(.field) }
    var todayButton: some View { Button("Hoy") { day = model.now }.buttonStyle(FocoSecondaryStyle()) }
    func taskStat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(size: 23, weight: .medium, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    func add() {
        if model.addTask(title: title, day: day, goalID: newGoalID) { title = ""; showArchived = false }
    }
    func taskRow(_ task: FocusTask) -> some View {
        let active = model.session?.taskID == task.id
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Button { model.completeTask(task) } label: {
                    Image(systemName: task.completedAt == nil ? "circle" : "checkmark.circle.fill")
                        .font(.system(size: 21)).foregroundStyle(task.completedAt == nil ? Color.focoSecondary : Color.foco)
                        .frame(width: 28, height: 28)
                }.buttonStyle(.plain).disabled(active || task.archivedAt != nil)
                    .accessibilityLabel(task.completedAt == nil ? "Completar tarea: \(task.title)" : "Volver a pendiente: \(task.title)")
                    .help(active ? "Terminá el bloque antes de completar esta tarea" : "Cambiar estado")
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.system(size: 14, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                    Text(active ? "En foco ahora" : "\(durationLabel(model.taskSeconds(task.id))) de foco acumulado")
                        .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                    if let goalID = task.goalID { Label(model.goalName(goalID), systemImage: "target").font(.system(size: 12)).foregroundStyle(Color.focoSecondary) }
                }
                Spacer(minLength: 4)
                Menu {
                    Button("Editar tarea y objetivo") { editing = task }
                    Button(task.archivedAt == nil ? "Archivar" : "Restaurar") { model.archiveTask(task) }.disabled(active)
                    Divider()
                    Button("Borrar tarea", role: .destructive) { model.deleteTask(task) }.disabled(active)
                } label: { Image(systemName: "ellipsis").frame(width: 28, height: 28) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
                    .accessibilityLabel("Opciones de \(task.title)")
            }
            HStack(spacing: 10) {
                Text("\(report.percent(for: task))%").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.foco)
                ProgressView(value: Double(report.percent(for: task)), total: 100).progressViewStyle(.linear).tint(Color.foco)
                    .frame(maxWidth: 130).accessibilityLabel("Avance de \(task.title)")
                Text(report.activity(for: task)).font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { taskActions(task) }
                VStack(alignment: .leading, spacing: 8) { taskActions(task) }
            }
        }.padding(.vertical, 2)
    }
    @ViewBuilder func taskActions(_ task: FocusTask) -> some View {
        if task.archivedAt == nil {
            if task.completedAt == nil && model.session == nil {
                Button("Elegir para foco") { model.chooseTask(task) }.buttonStyle(FocoPrimaryStyle())
                    .disabled(!model.canFocusTask(task)).help(model.canFocusTask(task) ? "Elegir esta tarea" : "El objetivo está cerrado; reasigná la tarea para iniciar.")
            }
            Button("Registrar avance") { recording = task }.buttonStyle(FocoSecondaryStyle())
                .disabled(Calendar.current.startOfDay(for: day) > Calendar.current.startOfDay(for: model.now))
        }
    }

}

struct TaskEditSheet: View {
    @EnvironmentObject var model: FocoModel
    @Environment(\.dismiss) var dismiss
    let task: FocusTask
    @ViewState private var title: String
    @ViewState private var day: Date
    @ViewState private var goalID: String?
    @ViewState private var includePrevious = false
    init(task: FocusTask) {
        self.task = task
        _title = ViewState(initialValue: task.title)
        _day = ViewState(initialValue: Date(timeIntervalSince1970: task.plannedFor))
        _goalID = ViewState(initialValue: task.goalID)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Editar tarea").font(.system(size: 24, weight: .medium, design: .rounded))
            TextField("Nombre", text: $title).textFieldStyle(.roundedBorder)
            if title.count > 160 { Text("El nombre puede tener hasta 160 caracteres.").font(.system(size: 12)).foregroundStyle(.orange) }
            DatePicker("Día", selection: $day, displayedComponents: .date)
            GoalMenu(selection: $goalID, currentGoalID: task.goalID)
                .disabled(model.session?.taskID == task.id)
            if goalID != nil && model.state.records.contains(where: { $0.taskID == task.id && $0.goalID == nil }) {
                Toggle("Incluir bloques anteriores sin objetivo", isOn: $includePrevious).font(.system(size: 12))
                    .disabled(model.session?.taskID == task.id)
            }
            Text("Los bloques nuevos usan el objetivo elegido. El tiempo ya asociado a otro objetivo no se mueve.")
                .font(.system(size: 11)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancelar") { dismiss() }.buttonStyle(.plain)
                Spacer()
                Button("Guardar") { if model.editTask(task, title: title, day: day, goalID: goalID, includePrevious: includePrevious) { dismiss() } }
                    .buttonStyle(FocoPrimaryStyle())
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 160)
            }
        }.padding(24).frame(width: 340)
    }
}

struct TaskProgressPanel: View {
    @EnvironmentObject var model: FocoModel
    let interval: DateInterval
    var goalID: String? = nil
    @ViewState private var visible = 10
    var report: TaskMetrics { TaskMetrics(state: model.state.filtered(forGoal: goalID), now: model.now, interval: interval) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tareas y avance").font(.system(size: 18, weight: .medium, design: .rounded))
            if goalID != nil {
                Text("Incluye tareas con bloques en este objetivo. El porcentaje refleja el avance de la tarea.")
                    .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { summary }
                VStack(alignment: .leading, spacing: 8) { summary }
            }.font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
            if report.related.isEmpty {
                Text("Elegí una tarea antes de iniciar Foco para empezar a ver su tiempo acá.")
                    .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                Button("Ir a mis tareas") { model.section = .tasks }.buttonStyle(FocoSecondaryStyle())
            }
            ForEach(Array(report.related.prefix(visible))) { task in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: report.percent(for: task) < 100 ? "circle" : "checkmark.circle.fill").foregroundStyle(Color.foco)
                        Text(task.title).font(.system(size: 14, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(durationLabel(report.seconds(for: task.id))).font(.system(size: 13, weight: .medium, design: .rounded)).monospacedDigit()
                    }
                    HStack(spacing: 10) {
                        Text("\(report.percent(for: task))% total").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.foco)
                        Text(report.activity(for: task)).font(.system(size: 12)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
                    }.padding(.leading, 24)
                }
                Divider().opacity(0.4)
            }
            if report.related.count > visible { Button("Mostrar más tareas") { visible += 10 }.buttonStyle(FocoSecondaryStyle()) }
            HStack {
                Text("Sin tarea").font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                Spacer()
                Text(durationLabel(report.seconds(for: nil))).font(.system(size: 12)).monospacedDigit()
            }
            DisclosureGroup("Cómo se calcula") {
                Text("Tiempo dentro del filtro, con pausas excluidas. El porcentaje lo registrás vos. Sin actividad registrada significa que no hay bloques ni avance declarado en estas fechas. Borrar un bloque también descuenta su tiempo de la tarea.")
                    .font(.system(size: 12)).foregroundStyle(Color.focoSecondary).padding(.top, 8)
            }.font(.system(size: 12))
        }.padding(22).panel()
    }
    @ViewBuilder var summary: some View {
        Text("\(report.completed) \(report.completed == 1 ? "completada" : "completadas")")
        Text("\(report.pending) \(report.pending == 1 ? "pendiente" : "pendientes")")
        Text("\(durationLabel(report.assignedSeconds)) de foco en tareas")
    }
}

struct TaskProgressSheet: View {
    @EnvironmentObject var model: FocoModel
    @Environment(\.dismiss) var dismiss
    let task: FocusTask
    let day: Date
    @ViewState private var percent: Double
    var prior: Int { task.percent(before: Calendar.current.startOfDay(for: day).timeIntervalSince1970) }
    init(task: FocusTask, day: Date) {
        self.task = task; self.day = day
        let end = Calendar.current.dateInterval(of: .day, for: day)!.end.timeIntervalSince1970
        _percent = ViewState(initialValue: Double(task.percent(before: end)))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("¿Cómo quedó esta tarea?").font(.system(size: 24, weight: .medium, design: .rounded))
            Text(task.title).font(.system(size: 14, weight: .medium)).fixedSize(horizontal: false, vertical: true)
            Text(day.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
            HStack {
                Text("\(Int(percent))%").font(.system(size: 40, weight: .light, design: .rounded)).monospacedDigit()
                Spacer()
                Stepper("Avance total", value: $percent, in: 0...100, step: 5).labelsHidden().accessibilityLabel("Ajustar porcentaje")
            }
            Slider(value: $percent, in: 0...100, step: 5).tint(Color.foco).accessibilityLabel("Porcentaje completado")
            Text("Es el porcentaje total alcanzado al terminar este día. Venías de \(prior)%. El tiempo de foco se registra por separado.")
                .font(.system(size: 12)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
            Button("No avancé este día") { percent = Double(prior) }.buttonStyle(FocoSecondaryStyle())
            if model.session?.taskID == task.id && Int(percent) == 100 {
                Text("Terminá el bloque de esta tarea antes de marcarla al 100%.").font(.system(size: 11)).foregroundStyle(Color.focoSecondary)
            }
            HStack {
                Button("Cancelar") { dismiss() }.buttonStyle(.plain)
                Spacer()
                Button("Guardar avance") {
                    if model.recordProgress(task, percent: Int(percent), day: day) { dismiss() }
                }.buttonStyle(FocoPrimaryStyle())
                    .disabled(model.session?.taskID == task.id && Int(percent) == 100)
            }
        }.padding(24).frame(width: 345)
    }
}
