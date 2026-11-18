import SwiftUI
import Charts

struct ProgressDashboard: View {
    @EnvironmentObject var model: FocoModel
    @ViewState private var period: FocusPeriod = .week
    @ViewState private var anchor = Date()
    @ViewState private var from = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
    @ViewState private var to = Date()
    @ViewState private var selectedDate: Date?
    @ViewState private var visibleRecords = 20
    var metrics: FocusMetrics {
        FocusMetrics(state: model.state, now: model.now, period: period, anchor: anchor, customStart: from, customEnd: to)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Mi progreso").font(.system(size: 26, weight: .medium, design: .rounded)).tracking(-1)
                Text("Tiempo de foco, tareas y avance en un mismo lugar.").font(.system(size: 14)).foregroundStyle(Color.focoSecondary)
            }
            VStack(alignment: .leading, spacing: 16) {
                Picker("Ver progreso por", selection: $period) { ForEach(FocusPeriod.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).labelsHidden()
                if period == .custom {
                    ViewThatFits(in: .horizontal) {
                        HStack { rangeFields }
                        VStack(alignment: .leading, spacing: 12) { rangeFields }
                    }
                } else {
                    DatePicker("Fecha de referencia", selection: $anchor, in: ...model.now, displayedComponents: .date).datePickerStyle(.field)
                }
                Text("\(metrics.bounds.start.formatted(date: .abbreviated, time: .omitted)) — \(Calendar.current.date(byAdding: .day, value: -1, to: metrics.bounds.end)!.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.foco)
            }.padding(18).panel()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 16)], spacing: 16) {
                metric("Tiempo en sesiones", value: durationLabel(metrics.total), detail: "Pausas excluidas", icon: "clock")
                metric("Promedio por día", value: durationLabel(metrics.dailyAverage), detail: "Incluye días sin actividad", icon: "calendar")
                metric("Promedio por sesión", value: durationLabel(metrics.sessionAverage), detail: "\(metrics.sessions.count) bloques terminados", icon: "circle.dotted.circle")
                metric("Días con sesiones", value: "\(metrics.activeDays) de \(metrics.dayCount)", detail: "Dentro de las fechas elegidas", icon: "sun.max")
            }
            chartPanel
            TaskProgressPanel(interval: metrics.bounds).environmentObject(model)
            AchievementsView().environmentObject(model)
            DisclosureGroup("Comparar con el período anterior") { comparisonPanel.padding(.top, 12) }
                .font(.system(size: 13, weight: .medium))
            DisclosureGroup("Meta diaria") { goalPanel.padding(.top, 12) }
                .font(.system(size: 13, weight: .medium))
            if let deleted = model.deletedRecord {
                HStack {
                    Text("Sesión de \(durationLabel(deleted.seconds)) eliminada.")
                    Spacer()
                    Button("Deshacer") { model.undoDelete() }.buttonStyle(FocoSecondaryStyle())
                    Button { model.dismissUndo() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless).help("Cerrar aviso").accessibilityLabel("Cerrar aviso de sesión eliminada")
                }.font(.system(size: 12)).padding(16).panel()
            }
            if !metrics.sessions.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sesiones del período").font(.system(size: 16, weight: .semibold))
                    ForEach(Array(metrics.sessions.prefix(visibleRecords))) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(Date(timeIntervalSince1970: record.startedAt).formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12, weight: .medium))
                                Text(model.taskName(record.taskID) + " · " + (record.completed ? "Temporizador completado" : "Sesión terminada manualmente")).font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                            }
                            Spacer()
                            Text(durationLabel(record.seconds)).font(.system(size: 14, weight: .medium, design: .rounded)).monospacedDigit()
                            Button { model.deleteRecord(record) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).help("Borrar esta sesión").accessibilityLabel("Borrar sesión de \(Date(timeIntervalSince1970: record.startedAt).formatted(date: .abbreviated, time: .shortened))")
                        }
                        Divider().opacity(0.4)
                    }
                    if metrics.sessions.count > visibleRecords { Button("Mostrar más sesiones") { visibleRecords += 20 }.buttonStyle(FocoSecondaryStyle()) }
                }.padding(22).panel()
            }
            DisclosureGroup("Acerca de estos datos") {
                Text("Son tiempos registrados, no una medición de tu atención. Las pausas se excluyen. Las sesiones se agrupan por su fecha de inicio; el gráfico reparte el tiempo al cruzar medianoche. Los promedios diarios incluyen días sin actividad y hoy es parcial. Podés borrar un bloque y deshacer durante 8 segundos.")
                    .font(.system(size: 12)).foregroundStyle(Color.focoSecondary).padding(.top, 10)
            }.font(.system(size: 12))
        }
    }
    @ViewBuilder var rangeFields: some View {
        DatePicker("Desde", selection: $from, in: ...model.now, displayedComponents: .date)
        DatePicker("Hasta", selection: $to, in: min(from, model.now)...model.now, displayedComponents: .date)
    }
    func metric(_ title: String, value: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.focoSecondary)
            Text(value).font(.system(size: 29, weight: .light, design: .rounded)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            Text(detail).font(.system(size: 12)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .topLeading).padding(18).panel()
    }
    var chartPanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Text(metrics.chartUnit == .hour ? "Tu día, hora a hora" : metrics.chartUnit == .month ? "Tiempo por mes" : "Tiempo por día").font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("minutos").font(.system(size: 11)).foregroundStyle(Color.focoSecondary)
            }
            if metrics.total == 0 && period != .week {
                VStack(spacing: 9) {
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 28, weight: .light)).foregroundStyle(Color.foco)
                    Text("Todavía no hay tiempo registrado en estas fechas.").font(.system(size: 13)).multilineTextAlignment(.center)
                    Text("Probá otro período o empezá una sesión.").font(.system(size: 11)).foregroundStyle(Color.focoSecondary)
                }.frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart(metrics.points) { point in
                    BarMark(x: .value("Fecha", point.date, unit: metrics.chartUnit), y: .value("Minutos", point.seconds / 60), width: .ratio(0.42))
                        .foregroundStyle(Color.foco.gradient).cornerRadius(4)
                        .accessibilityLabel(point.date.formatted(date: .abbreviated, time: metrics.chartUnit == .hour ? .shortened : .omitted))
                        .accessibilityValue(durationLabel(point.seconds))
                }
                .chartXScale(domain: metrics.bounds.start...metrics.chartEnd)
                .chartXAxis {
                    if period == .week {
                        AxisMarks(values: metrics.points.map(\.date)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(centered: true) {
                                if let date = value.as(Date.self) {
                                    VStack(spacing: 2) {
                                        Text(date, format: .dateTime.weekday(.abbreviated))
                                        Text(date, format: .dateTime.day())
                                    }.font(.system(size: 10))
                                }
                            }
                        }
                    } else { AxisMarks() }
                }
                .chartXSelection(value: $selectedDate)
                .chartYScale(domain: 0...max(1, (metrics.points.map { $0.seconds / 60 }.max() ?? 1) * 1.15))
                .frame(height: 220)
                if let selectedDate, let point = metrics.points.first(where: { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: metrics.chartUnit) }) {
                    Text("\(point.date.formatted(date: .abbreviated, time: metrics.chartUnit == .hour ? .shortened : .omitted)): \(durationLabel(point.seconds))").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.foco)
                } else { Text("Tocá o arrastrá sobre el gráfico para ver el detalle.").font(.system(size: 11)).foregroundStyle(Color.focoSecondary) }
            }
        }.padding(22).panel()
    }
    var comparisonPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("¿Cómo viene tu constancia?", systemImage: "chart.line.uptrend.xyaxis").font(.system(size: 15, weight: .semibold))
            if let c = metrics.comparison {
                Text("\(durationLabel(c.current)) en \(c.days) días completos").font(.system(size: 20, weight: .medium, design: .rounded))
                Text("Frente a \(durationLabel(c.previous)) en los \(c.days) días inmediatamente anteriores.").font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                if c.previous > 0 {
                    let change = (c.current - c.previous) / c.previous * 100
                    Text("\(change >= 0 ? "+" : "")\(Int(change.rounded()))% de tiempo en sesiones").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.foco)
                } else { Text("Sin base anterior suficiente para calcular un porcentaje.").font(.system(size: 11)).foregroundStyle(Color.focoSecondary) }
                Text("Hoy se excluye de la comparación para no enfrentar un día parcial con uno completo. Más tiempo no implica por sí solo mayor calidad de concentración.").font(.system(size: 11)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
            } else { Text("La comparación aparece cuando el filtro incluye al menos un día completo.").font(.system(size: 12)).foregroundStyle(Color.focoSecondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(22).panel()
    }
    var goalPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tu meta de hoy").font(.system(size: 15, weight: .semibold))
            Toggle("Usar una meta diaria", isOn: $model.goalEnabled)
            if model.goalEnabled {
                Stepper("\(model.goalMinutes) minutos", value: $model.goalMinutes, in: 5...720, step: 5)
                ProgressView(value: min(1, model.totalToday / Double(model.goalMinutes * 60))).tint(Color.foco)
                Text("\(durationLabel(model.totalToday)) de \(model.goalMinutes) min hoy. Vos elegís la meta; no hace falta subirla todos los días.").font(.system(size: 11)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(22).panel()
    }
}
