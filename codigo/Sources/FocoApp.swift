import SwiftUI
import AppKit

// Explicit property-wrapper alias avoids the SDK 27 macro overload (CLI SDK has no SwiftUIMacros plugin).
typealias ViewState<Value> = SwiftUI.State<Value>

@MainActor
final class FocoModel: ObservableObject {
    @Published var state = FocusState()
    @Published var now = Date()
    @Published var error: String?
    @Published var showSetup = false
    @Published var showTimer = false
    @Published var firm = false
    @Published var showEditor = false
    @Published var section: FocoSection = .focus
    @Published var selectedTaskID: String? {
        didSet { if let id = selectedTaskID, let task = tasks.first(where: { $0.id == id }) { selectedGoalID = task.goalID } }
    }
    @Published var selectedGoalID: String?
    @Published var goalEnabled = UserDefaults.standard.bool(forKey: "goalEnabled") { didSet { UserDefaults.standard.set(goalEnabled, forKey: "goalEnabled") } }
    @Published var goalMinutes = max(5, UserDefaults.standard.object(forKey: "goalMinutes") as? Int ?? 60) { didSet { UserDefaults.standard.set(goalMinutes, forKey: "goalMinutes") } }
    private let appGuard = ApplicationGuard()
    @Published var minutes = 25
    @Published var lastFinished: Double?
    @Published private(set) var deletedRecord: FocusRecord?
    private var undoExpiresAt: Date?
    @Published private(set) var deletedTask: DeletedFocusTask?
    private var taskUndoExpiresAt: Date?
    @Published private(set) var deletedGoal: DeletedFocusGoal?
    private var goalUndoExpiresAt: Date?
    let store: FocusStore
    private var timer: Timer?
    private var previousID: String?
    init(store: FocusStore = FocusStore()) {
        self.store = store
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    var session: FocusSession? { state.session }
    var connected: Bool { now.timeIntervalSince1970 - state.bridgeSeen < 8 && state.ownerProfile != nil && state.browserError == nil }
    var confirmed: Bool { session != nil && state.appliedID == session?.id && connected }
    var cleaning: Bool { session == nil && !state.appliedID.isEmpty }
    var elapsed: Double { session?.elapsed(at: now.timeIntervalSince1970) ?? 0 }
    var remaining: Double? { session?.remaining(at: now.timeIntervalSince1970) }
    var totalToday: Double { store.todaySeconds(now: now, state: state) }
    var todayRecords: [FocusRecord] { state.records.filter { Calendar.current.isDate(Date(timeIntervalSince1970: $0.startedAt), inSameDayAs: now) } }
    func tick() {
        now = Date()
        dismissExpiredUndo(at: now)
        dismissExpiredTaskUndo(at: now)
        dismissExpiredGoalUndo(at: now)
        do {
            let previousTaskGoal = tasks.first(where: { $0.id == selectedTaskID })?.goalID
            let next = try store.read(now: now.timeIntervalSince1970)
            if previousID != nil, next.session == nil, let record = next.records.first, record.id == previousID {
                lastFinished = record.seconds
            }
            previousID = next.session?.id
            state = next
            if let task = tasks.first(where: { $0.id == selectedTaskID }), task.goalID != previousTaskGoal {
                selectedGoalID = task.goalID
            }
            if let selectedTaskID, !availableTasks.contains(where: { $0.id == selectedTaskID }) { self.selectedTaskID = nil }
            if let selectedGoalID, !openGoals.contains(where: { $0.id == selectedGoalID }) { self.selectedGoalID = nil }
            let status = appGuard.enforce(session: next.session, now: now.timeIntervalSince1970)
            if next.appBlockStatus != status { try store.transaction { $0.appBlockStatus = status }; state.appBlockStatus = status }
        } catch { self.error = error.localizedDescription }
    }
    func start(timed: Bool) {
        guard connected else { showSetup = true; return }
        if firm && !timed { showTimer = true; return }
        do {
            try store.start(duration: timed ? Double(minutes * 60) : nil, firm: firm, useConfiguration: true, taskID: selectedTaskID, goalID: selectedGoalID)
            lastFinished = nil; tick(); showTimer = false
        } catch { self.error = error.localizedDescription }
    }
    func stop() {
        do { try store.stop(); tick() } catch { self.error = error.localizedDescription }
    }
    func togglePause() {
        do { try store.setPaused(session?.isPaused != true); tick() } catch { self.error = error.localizedDescription }
    }
    var pendingQualityRecord: FocusRecord? {
        guard session == nil, let id = state.pendingQualityRecordID else { return nil }
        return state.records.first { $0.id == id }
    }
    func setRecordReview(_ record: FocusRecord, rating: Int?, difficulty: FocusDifficulty?) throws {
        try store.setRecordReview(id: record.id, rating: rating, difficulty: difficulty)
        tick()
    }
    func deleteRecord(_ record: FocusRecord) {
        do {
            deletedRecord = try store.deleteRecord(id: record.id)
            undoExpiresAt = deletedRecord == nil ? nil : Date().addingTimeInterval(8)
            lastFinished = nil; tick()
        }
        catch { self.error = error.localizedDescription }
    }
    func undoDelete() {
        guard let record = deletedRecord else { return }
        do { try store.restoreRecord(record); dismissUndo(); tick() }
        catch { self.error = error.localizedDescription }
    }
    func dismissUndo() {
        deletedRecord = nil
        undoExpiresAt = nil
    }
    func dismissExpiredUndo(at date: Date) {
        if let deadline = undoExpiresAt, date >= deadline { dismissUndo() }
    }
    var tasks: [FocusTask] { state.tasks ?? [] }
    var availableTasks: [FocusTask] {
        tasks.filter { canFocusTask($0) && (selectedGoalID == nil || $0.goalID == selectedGoalID) }
            .sorted { $0.plannedFor == $1.plannedFor ? $0.createdAt < $1.createdAt : $0.plannedFor < $1.plannedFor }
    }
    var goals: [FocusGoal] { (state.goals ?? []).sorted { $0.createdAt > $1.createdAt } }
    var openGoals: [FocusGoal] { goals.filter { $0.closedAt == nil } }
    func canFocusTask(_ task: FocusTask) -> Bool {
        task.completedAt == nil && task.archivedAt == nil && (task.goalID == nil || openGoals.contains { $0.id == task.goalID })
    }
    func goalName(_ id: String?) -> String {
        guard let id else { return "Sin objetivo" }
        return goals.first(where: { $0.id == id })?.title ?? "Objetivo guardado"
    }
    func goalSeconds(_ id: String) -> Double { GoalMetrics(state: state, goalID: id, now: now).seconds }
    func assignRecordGoal(_ record: FocusRecord, id: String?) {
        do { try store.assignRecordGoal(id: record.id, goalID: id); tick() }
        catch { self.error = error.localizedDescription }
    }
    func chooseGoalID(_ id: String?) {
        guard session == nil else { return }
        selectedGoalID = id
        if let selectedTaskID, !availableTasks.contains(where: { $0.id == selectedTaskID }) {
            self.selectedTaskID = nil
        }
    }
    func chooseGoal(_ goal: FocusGoal) {
        guard session == nil, goal.closedAt == nil else { return }
        selectedTaskID = nil; selectedGoalID = goal.id; section = .focus
    }
    func saveGoal(_ goal: FocusGoal?, title: String, hours: Double?) -> Bool {
        do {
            if let goal { try store.editGoal(id: goal.id, title: title, targetHours: hours) }
            else { try store.addGoal(title: title, targetHours: hours) }
            tick(); return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func finishGoal(_ goal: FocusGoal, outcome: GoalOutcome, note: String) -> Bool {
        do { try store.closeGoal(id: goal.id, outcome: outcome, note: note); tick(); return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func deleteGoal(_ goal: FocusGoal) {
        do {
            deletedGoal = try store.deleteGoal(id: goal.id)
            goalUndoExpiresAt = deletedGoal == nil ? nil : Date().addingTimeInterval(8)
            if selectedGoalID == goal.id { selectedGoalID = nil }
            tick()
        } catch { self.error = error.localizedDescription }
    }
    func undoGoalDelete() {
        guard let deletedGoal else { return }
        do { try store.restoreGoal(deletedGoal); dismissGoalUndo(); tick() }
        catch { self.error = error.localizedDescription }
    }
    func dismissGoalUndo() { deletedGoal = nil; goalUndoExpiresAt = nil }
    func dismissExpiredGoalUndo(at date: Date) { if let deadline = goalUndoExpiresAt, date >= deadline { dismissGoalUndo() } }
    func taskName(_ id: String?) -> String {
        guard let id else { return "Sin tarea" }
        return tasks.first(where: { $0.id == id })?.title ?? "Tarea guardada"
    }
    func taskSeconds(_ id: String) -> Double {
        TaskMetrics(state: state, now: now, interval: DateInterval(start: .distantPast, end: now)).seconds(for: id)
    }
    @discardableResult
    func addTask(title: String, day: Date, goalID: String? = nil) -> Bool {
        do { try store.addTask(title: title, day: day, goalID: goalID); tick(); return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func editTask(_ task: FocusTask, title: String, day: Date, goalID: String?, includePrevious: Bool = false) -> Bool {
        do { try store.editTask(id: task.id, title: title, day: day, goal: .set(goalID, includePrevious: includePrevious)); tick(); return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func completeTask(_ task: FocusTask) {
        do {
            try store.setTaskCompleted(id: task.id, completed: task.completedAt == nil)
            if selectedTaskID == task.id { selectedTaskID = nil }
            tick()
        } catch { self.error = error.localizedDescription }
    }
    func recordProgress(_ task: FocusTask, percent: Int, day: Date) -> Bool {
        do {
            try store.setTaskProgress(id: task.id, percent: percent, day: day)
            if percent == 100 && selectedTaskID == task.id { selectedTaskID = nil }
            tick(); return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func deleteTask(_ task: FocusTask) {
        do {
            deletedTask = try store.deleteTask(id: task.id)
            taskUndoExpiresAt = deletedTask == nil ? nil : Date().addingTimeInterval(8)
            if selectedTaskID == task.id { selectedTaskID = nil }
            tick()
        } catch { self.error = error.localizedDescription }
    }
    func undoTaskDelete() {
        guard let task = deletedTask else { return }
        do { try store.restoreTask(task); dismissTaskUndo(); tick() }
        catch { self.error = error.localizedDescription }
    }
    func dismissTaskUndo() { deletedTask = nil; taskUndoExpiresAt = nil }
    func dismissExpiredTaskUndo(at date: Date) {
        if let deadline = taskUndoExpiresAt, date >= deadline { dismissTaskUndo() }
    }
    func archiveTask(_ task: FocusTask) {
        do {
            try store.setTaskArchived(id: task.id, archived: task.archivedAt == nil)
            if selectedTaskID == task.id { selectedTaskID = nil }
            tick()
        } catch { self.error = error.localizedDescription }
    }
    func chooseTask(_ task: FocusTask) {
        guard session == nil else { return }
        selectedTaskID = task.id
        section = .focus
    }
    func saveConfiguration(_ config: BlockConfiguration) {
        do { try store.updateConfiguration(config); tick() }
        catch { self.error = error.localizedDescription }
    }
    func installBridge() throws {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Google/Chrome/NativeMessagingHosts", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let manifest: [String: Any] = ["name":"local.foco.bridge", "description":"Foco: conexión local con Chrome", "path":Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/FocoBridge").path, "type":"stdio", "allowed_origins":["chrome-extension://ffnpgijgkijehlmgedmniefkmodlnmgf/"]]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url.appendingPathComponent("local.foco.bridge.json"), options: .atomic)
    }
    var extensionPath: String { Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Extension-Chrome").path }
}

#if !RENDERING
@main
struct FocoApp: App {
    @StateObject var model = FocoModel()
    var body: some Scene {
        WindowGroup("Foco", id: "main") {
            ContentView().environmentObject(model)
                .frame(minWidth: 390, minHeight: 640)
                .onAppear { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
                .tint(Color.foco)
        }
        .defaultSize(width: 1000, height: 740)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Sesión") {
                Button("Iniciar cronómetro") { model.start(timed: false) }.keyboardShortcut("s", modifiers: [.command, .shift]).disabled(model.session != nil)
                Button("Elegir duración…") { model.showTimer = true }.disabled(model.session != nil)
                Button(model.session?.isPaused == true ? "Reanudar sesión" : "Pausar sesión") { model.togglePause() }
                    .keyboardShortcut("p", modifiers: [.command, .shift]).disabled(model.session == nil)
            }
            CommandMenu("Tamaño de ventana") {
                Button("Compacta") { resize(width: 420, height: 820) }
                Button("Amplia") { resize(width: 1000, height: 820) }
            }
        }
        MenuBarExtra {
            MenuPanel().environmentObject(model)
        } label: {
            if model.session != nil { Label(clockString(model.elapsed), systemImage: "circle.dotted.circle.fill") }
            else { Label("Foco", systemImage: "circle.dotted.circle") }
        }.menuBarExtraStyle(.window)
    }
    func resize(width: CGFloat, height: CGFloat) {
        guard let window = NSApp.windows.first(where: {$0.identifier?.rawValue.contains("main") == true || $0.title == "Foco"}) else {return}
        window.setContentSize(NSSize(width: width, height: height))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

#endif

extension Color {
    static let foco = Color(red: 0.20, green: 0.61, blue: 0.51)
}
// One clear action color, independent of inactive-window glass rendering.
struct FocoPrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(enabled ? Color.white : Color.focoSecondary)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(enabled ? Color(red: 0.08, green: 0.43, blue: 0.35) : Color.primary.opacity(0.07), in: .rect(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}
struct FocoSecondaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .foregroundStyle(enabled ? Color.primary : Color.focoSecondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.055), in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.10), lineWidth: 0.5))
            .opacity(enabled ? 1 : 0.55)
    }
}
extension Color {
    static let focoSecondary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.68, green: 0.74, blue: 0.77, alpha: 1)
            : NSColor(red: 0.31, green: 0.37, blue: 0.40, alpha: 1)
    })
}
struct GlassPanel: ViewModifier {
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        content.glassEffect(.regular, in: .rect(cornerRadius: radius))
    }
}
extension View { func panel(_ radius: CGFloat = 24) -> some View { modifier(GlassPanel(radius: radius)) } }

struct ContentView: View {
    @EnvironmentObject var model: FocoModel
    @Environment(\.colorScheme) var scheme
    @ViewState private var finishConfirm = false
    var body: some View {
        GeometryReader { geo in
            ZStack {
                background
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        Picker("Sección", selection: $model.section) {
                            ForEach(FocoSection.allCases) { Text($0.navigationTitle).tag($0) }
                        }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 460)
                        if model.section == .tasks {
                            TasksView().environmentObject(model)
                        } else if model.section == .goals {
                            GoalsView().environmentObject(model)
                        } else if model.section == .progress {
                            ProgressDashboard().environmentObject(model)
                        } else if geo.size.width >= 820 {
                            HStack(alignment: .top, spacing: 24) {
                                mainPanel.frame(maxWidth: .infinity)
                                companion.frame(width: 275)
                            }
                        } else {
                            mainPanel
                            companion
                        }
                        footer
                    }
                    .padding(.horizontal, geo.size.width < 500 ? 20 : 36)
                    .padding(.top, 24).padding(.bottom, 24)
                    .frame(maxWidth: model.section == .tasks ? 860 : 1040).frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(isPresented: $model.showEditor) { BlockEditor().environmentObject(model) }
        .sheet(isPresented: $model.showTimer) { TimerSheet().environmentObject(model) }
        .sheet(item: Binding(get: {
            model.showEditor || model.showTimer || model.showSetup || finishConfirm ? nil : model.pendingQualityRecord
        }, set: { _ in })) { record in
            SessionReviewSheet(record: record, isPrompt: true).environmentObject(model)
        }
        .sheet(isPresented: $model.showSetup) { SetupSheet().environmentObject(model) }
        .alert("No pudimos completar la acción", isPresented: Binding(get: {model.error != nil}, set: {if !$0 {model.error = nil}})) {
            Button("Entendido") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .confirmationDialog("¿Terminar esta sesión?", isPresented: $finishConfirm, titleVisibility: .visible) {
            Button("Terminar y desbloquear") { model.stop() }
            Button("Seguir concentrado", role: .cancel) {}
        } message: { Text("Se guardará el tiempo que llevás y terminará el bloqueo de esta sesión.") }
    }
    var background: some View {
        ZStack {
            (scheme == .dark ? Color(red: 0.055, green: 0.085, blue: 0.105) : Color(red: 0.925, green: 0.95, blue: 0.945))
            GeometryReader { geo in
                Ellipse().fill(Color.foco.opacity(scheme == .dark ? 0.22 : 0.17)).frame(width: geo.size.width * 0.9, height: 550).blur(radius: 100).offset(x: -250, y: -180)
                Ellipse().fill(Color(red: 0.52, green: 0.57, blue: 0.86).opacity(0.13)).frame(width: 500, height: 500).blur(radius: 100).offset(x: geo.size.width - 300, y: 300)
            }
        }.ignoresSafeArea()
    }
    var header: some View {
        HStack {
            HStack(spacing: 9) {
                Image(systemName: "circle.dotted.circle").font(.system(size: 30, weight: .medium)).foregroundStyle(Color.foco)
                Text("foco").font(.system(size: 28, weight: .semibold, design: .rounded)).tracking(-1)
            }
            Spacer()
            Button { model.showSetup = true } label: {
                HStack(spacing: 7) {
                    Circle().fill(model.connected ? Color.foco : .orange).frame(width: 6, height: 6)
                    Text(model.connected ? "Chrome conectado" : "Conectar Chrome").font(.system(size: 12, weight: .medium))
                }.padding(.horizontal, 13).padding(.vertical, 10)
            }.buttonStyle(.plain).glassEffect(.regular.interactive(), in: .capsule)
            .help("Configurar el complemento y revisar su conexión")
        }
    }
    var mainPanel: some View {
        VStack(spacing: 16) {
            HStack {
                Text(model.session == nil ? "Tu próximo bloque" : model.session?.isPaused == true ? "Un descanso" : "Tiempo para concentrarte")
                    .font(.system(size: 25, weight: .medium, design: .rounded)).tracking(-0.6)
                Spacer()
                if model.session?.firm == true { Image(systemName: "lock.fill").foregroundStyle(Color.foco) }
            }
            TaskSessionPicker().environmentObject(model)
            timerDial.padding(.vertical, 2)
            if model.session == nil {
                modePicker
                Button { model.start(timed: false) } label: {
                    Label(model.firm ? "Elegir tiempo e iniciar" : "Iniciar foco", systemImage: model.firm ? "lock.fill" : "play.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 3)
                }.buttonStyle(FocoPrimaryStyle())
                Button { model.showTimer = true } label: { Label("Configurar duración", systemImage: "timer") }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.focoSecondary)
            } else {
                sessionStatus
                Button { model.togglePause() } label: {
                    Label(model.session?.isPaused == true ? "Reanudar" : "Pausar", systemImage: model.session?.isPaused == true ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 3)
                }.buttonStyle(FocoPrimaryStyle())
                Text(model.session?.isPaused == true ? "El reloj está pausado. El bloqueo sigue activo." : "Podés pausar para descansar sin sumar tiempo.")
                    .font(.system(size: 12)).foregroundStyle(Color.focoSecondary).multilineTextAlignment(.center)
                if model.session!.firm {
                    Label("La sesión termina al cumplir el tiempo de foco.", systemImage: "lock.fill")
                        .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                } else {
                    Button { finishConfirm = true } label: { Label("Terminar sesión", systemImage: "stop.fill") }
                        .buttonStyle(FocoSecondaryStyle())
                }
            }
        }.padding(22).panel(24)
    }
    var timerDial: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.06), lineWidth: 2)
            Circle().trim(from: 0, to: progress)
                .stroke(AngularGradient(colors: [Color.foco.opacity(0.20), Color.foco.opacity(0.65), Color.foco], center: .center), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().fill(Color.foco.opacity(0.035)).padding(12)
            VStack(spacing: 10) {
                Image(systemName: model.session == nil ? "sparkle" : "circle.dotted.circle.fill")
                    .font(.system(size: 20, weight: .light)).foregroundStyle(Color.foco)
                Text(clockString(model.elapsed)).font(.system(size: 52, weight: .ultraLight, design: .rounded)).monospacedDigit().tracking(-2.5)
                    .contentTransition(.numericText()).accessibilityLabel("Tiempo de concentración: \(clockString(model.elapsed))")
                Text(model.session == nil ? "Listo para empezar" : model.session?.isPaused == true ? "en pausa" : "tiempo de concentración")
                    .font(.system(size: 11)).foregroundStyle(Color.focoSecondary)
                if let remaining = model.remaining {
                    Text("Quedan \(clockString(ceil(remaining)))").font(.system(size: 12, weight: .medium)).monospacedDigit().foregroundStyle(Color.foco)
                } else {
                    if model.session != nil { Text("Sin límite de tiempo").font(.system(size: 11)).foregroundStyle(Color.focoSecondary) }
                }
            }
        }.frame(width: 208, height: 208).frame(maxWidth: .infinity)
    }
    var progress: CGFloat {
        guard let s = model.session else { return 0.12 }
        if let d = s.duration { return CGFloat(max(0.01, min(1, model.elapsed / d))) }
        return CGFloat(max(0.02, min(1, model.elapsed / 3600)))
    }
    var modePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Modo de bloqueo").font(.system(size: 12, weight: .medium))
            Picker("Modo de bloqueo", selection: $model.firm) {
                Text("Flexible").tag(false)
                Text("Firme").tag(true)
            }.pickerStyle(.segmented).labelsHidden()
            Label(model.firm ? "Te comprometés hasta que termine el tiempo." : "Podés terminar la sesión cuando quieras.", systemImage: model.firm ? "lock" : "hand.raised")
                .font(.system(size: 11)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    var sessionStatus: some View {
        VStack(spacing: 9) {
            Label(model.confirmed ? "Sitios bloqueados en Chrome" : model.connected ? "Activando el bloqueo…" : "Revisá la conexión con Chrome", systemImage: model.confirmed ? "checkmark.shield.fill" : "exclamationmark.circle")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(model.confirmed ? Color.foco : Color.orange)
            Text(model.confirmed ? "El resto de Chrome sigue disponible." : "No podemos confirmar el bloqueo hasta recibir respuesta del complemento.")
                .font(.system(size: 11)).foregroundStyle(Color.focoSecondary).multilineTextAlignment(.center)
        }
    }
    var companion: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hoy").font(.system(size: 15, weight: .semibold))
                Text(durationLabel(model.totalToday)).font(.system(size: 32, weight: .light, design: .rounded)).monospacedDigit()
                Text("\(model.todayRecords.count) \(model.todayRecords.count == 1 ? "bloque terminado" : "bloques terminados")")
                    .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                if let finished = model.lastFinished {
                    Label("Último bloque: \(clockString(finished))", systemImage: "checkmark.circle")
                        .font(.system(size: 12)).foregroundStyle(Color.foco)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20).panel()
            VStack(alignment: .leading, spacing: 14) {
                Label("Durante el bloque", systemImage: "shield.lefthalf.filled").font(.system(size: 15, weight: .semibold))
                Text("\((model.state.configuration?.sites ?? []).filter(\.enabled).count) sitios · \((model.state.configuration?.applications ?? []).filter(\.enabled).count) \((model.state.configuration?.applications ?? []).filter(\.enabled).count == 1 ? "app" : "apps")")
                    .font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                DisclosureGroup("Ver lista") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach((model.state.configuration?.sites ?? []).filter(\.enabled)) { site in
                            Label(site.label, systemImage: "globe").font(.system(size: 12)).lineLimit(2)
                        }
                        ForEach((model.state.configuration?.applications ?? []).filter(\.enabled)) { app in
                            Label(app.name, systemImage: "app").font(.system(size: 12))
                        }
                    }.padding(.top, 10)
                }.font(.system(size: 12))
                Button("Editar bloqueos", systemImage: "slider.horizontal.3") { model.showEditor = true }
                    .buttonStyle(FocoSecondaryStyle()).disabled(model.session != nil)
                Text("Las apps elegidas se cierran al iniciar. Guardá tu trabajo antes.")
                    .font(.system(size: 12)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
                if model.session?.applications?.isEmpty == false {
                    Label(model.state.appBlockStatus == "closed" ? "Apps cerradas" : "Revisá el cierre de las apps", systemImage: model.state.appBlockStatus == "closed" ? "checkmark.circle" : "exclamationmark.circle")
                        .font(.system(size: 12)).foregroundStyle(model.state.appBlockStatus == "closed" ? Color.foco : Color.orange)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20).panel()
        }
    }
    func siteRow(_ title: String, domain: String, icon: String, color: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium)).foregroundStyle(color).frame(width: 36, height: 36).background(color.opacity(0.09), in: .rect(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 13, weight: .medium)); Text(domain).font(.system(size: 10)).foregroundStyle(Color.focoSecondary) }
            Spacer()
            Image(systemName: model.confirmed ? "lock.fill" : "minus").font(.system(size: 11)).foregroundStyle(.tertiary)
        }
    }
    var footer: some View {
        Label("Datos guardados en esta Mac", systemImage: "internaldrive")
            .font(.system(size: 11)).foregroundStyle(Color.focoSecondary).frame(maxWidth: .infinity)
    }

}

struct TimerSheet: View {
    @EnvironmentObject var model: FocoModel
    @Environment(\.dismiss) var dismiss
    @ViewState private var custom: String = "25"
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Image(systemName: "timer").font(.system(size: 28, weight: .light)).foregroundStyle(Color.foco); Spacer(); Button("Cerrar", systemImage: "xmark") {dismiss()}.labelStyle(.iconOnly).buttonStyle(.plain).help("Cerrar sin empezar") }
            Text("Un rato para lo importante.").font(.system(size: 25, weight: .medium, design: .rounded)).tracking(-0.6)
            Text("Elegí una duración. El bloqueo termina solo cuando se cumple.").font(.system(size: 13)).foregroundStyle(Color.focoSecondary)
            HStack(spacing: 10) {
                ForEach([25,50,90], id: \.self) { value in
                    Button { model.minutes = value; custom = "\(value)" } label: {
                        VStack(spacing: 4) { Text("\(value)").font(.system(size: 23, weight: .light, design: .rounded)); Text("minutos").font(.system(size: 11)) }.frame(maxWidth: .infinity).padding(.vertical, 16)
                    }.buttonStyle(.glass).tint(model.minutes == value ? Color.foco : .secondary)
                }
            }
            HStack {
                Text("Otro tiempo").font(.system(size: 13))
                Spacer()
                TextField("Minutos", text: $custom).frame(width: 64).textFieldStyle(.roundedBorder)
                    .onChange(of: custom) { _, value in if let number = Int(value), (1...180).contains(number) {model.minutes = number} }
                Text("min").font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
            }
            Picker("Modo", selection: $model.firm) { Text("Flexible").tag(false); Text("Firme").tag(true) }.pickerStyle(.segmented)
            Text(model.firm ? "Firme: no podés terminar desde la app antes de tiempo. Desactivar el complemento permite eludirlo." : "Flexible: podés terminar cuando quieras. Tu tiempo queda guardado.")
                .font(.system(size: 12)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
            Button { model.start(timed: true) } label: { Label("Iniciar \(model.minutes) \(model.minutes == 1 ? "minuto" : "minutos")", systemImage: "play.fill").frame(maxWidth: .infinity).padding(.vertical, 10) }.buttonStyle(FocoPrimaryStyle()).controlSize(.large)
                .disabled(Int(custom).map { !(1...180).contains($0) } ?? true)
        }.padding(24).frame(width: 370).onAppear { custom = "\(model.minutes)" }
    }
}

struct SetupSheet: View {
    @EnvironmentObject var model: FocoModel
    @Environment(\.dismiss) var dismiss
    @ViewState private var bridgeInstalled = false
    @ViewState private var setupError: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack { Image(systemName: "link").font(.system(size: 28, weight: .light)).foregroundStyle(Color.foco); Spacer(); Button("Cerrar", systemImage: "xmark") {dismiss()}.labelStyle(.iconOnly).buttonStyle(.plain) }
            Text(model.connected ? "Todo conectado." : "Una conexión. Y listo.").font(.system(size: 26, weight: .medium, design: .rounded)).tracking(-0.6)
            Text("Foco usa un complemento propio para bloquear los sitios que elijas. Los permisos se autorizan por dominio, desde el complemento.").font(.system(size: 13)).foregroundStyle(Color.focoSecondary).lineSpacing(4)
            if model.connected {
                Label("El complemento responde en tu perfil de Chrome.", systemImage: "checkmark.circle.fill").foregroundStyle(Color.foco)
                Text("Las sesiones se mantienen al cerrar esta ventana. Otros perfiles y el modo incógnito quedan fuera del bloqueo.").font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                Button("Listo") { dismiss() }.buttonStyle(FocoPrimaryStyle())
            } else {
                step("1", title: "Conectá la app con Chrome", text: "Crea una conexión local. No se envía información a Internet.")
                Button(bridgeInstalled ? "Conexión local preparada ✓" : "Preparar conexión local") {
                    do { try model.installBridge(); bridgeInstalled = true } catch { setupError = error.localizedDescription }
                }.buttonStyle(.glass).controlSize(.large)
                step("2", title: "Cargá el complemento en tu perfil", text: "En chrome://extensions, activá Modo de desarrollador → Cargar descomprimida. Elegí Extension-Chrome.")
                HStack {
                    Button("Ver complemento en Finder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: model.extensionPath) }.buttonStyle(.glass)
                    Button("Copiar ruta") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.extensionPath, forType: .string) }.buttonStyle(.plain)
                }
                Text("Hacelo en el perfil de Chrome donde quieras usar el bloqueo. La conexión queda vinculada al primer perfil que la active.").font(.system(size: 11)).foregroundStyle(Color.focoSecondary)
                if let setupError { Text(setupError).font(.system(size: 12)).foregroundStyle(.red) }
                Label("Esperando al complemento…", systemImage: "arrow.triangle.2.circlepath").font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
            }
            Divider()
            Text("Para desinstalar: terminá la sesión y quitá el complemento de Chrome. Los datos de tiempo se guardan localmente. Foco no controla otros bloqueadores que tengas activos.").font(.system(size: 11)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
        }.padding(30).frame(width: 450)
    }
    func step(_ number: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 12, weight: .semibold)).frame(width: 24, height: 24).background(Color.foco.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 13, weight: .semibold)); Text(text).font(.system(size: 12)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
}
struct MenuPanel: View {
    @EnvironmentObject var model: FocoModel
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack(spacing: 15) {
            Text("foco").font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(clockString(model.elapsed)).font(.system(size: 38, weight: .light, design: .rounded)).monospacedDigit()
            Text(model.session == nil ? "Tu próximo momento empieza acá." : model.confirmed ? "Sitios bloqueados en Chrome" : "Comprobando bloqueo…").font(.system(size: 11)).foregroundStyle(Color.focoSecondary)
            if model.session != nil {
                Button(model.session?.isPaused == true ? "Reanudar" : "Pausar") { model.togglePause() }.buttonStyle(.glass)
                if model.session?.isPaused == true { Text("En pausa · bloqueo activo").font(.system(size: 11)).foregroundStyle(Color.focoSecondary) }
            }
            Button("Abrir Foco") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }.buttonStyle(FocoPrimaryStyle())
        }.padding(24).frame(width: 245)
    }
}
