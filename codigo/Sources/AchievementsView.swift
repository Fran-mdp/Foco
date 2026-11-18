import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var model: FocoModel

    var achievements: FocusAchievements {
        FocusAchievements(state: model.state, now: model.now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            summaryRow
            milestoneCards
            rulesDisclosure
        }
        .padding(22)
        .panel()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Tus logros")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("Histórico")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.focoSecondary)
            }
            Text("Logros generales, independientes de las fechas y del objetivo elegido.")
                .font(.system(size: 12))
                .foregroundStyle(Color.focoSecondary)
        }
    }

    private var summaryRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    starsLabel
                    trophiesLabel
                }
                VStack(alignment: .leading, spacing: 6) {
                    starsLabel
                    trophiesLabel
                }
            }
            if achievements.todayPlanned == 0 {
                Text("Hoy: sin tareas planificadas.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.focoSecondary)
            } else {
                Text("Hoy (provisorio): \(achievements.todayCompleted) de \(achievements.todayPlanned) a tiempo.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.focoSecondary)
            }
        }
    }

    private var starsLabel: some View {
        Label("\(achievements.perfectDays) \(achievements.perfectDays == 1 ? "estrella por día completo" : "estrellas por días completos")", systemImage: "star.fill")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(achievements.perfectDays > 0 ? Color.foco : Color.focoSecondary)
    }

    private var trophiesLabel: some View {
        Label("\(achievements.perfectWeeks) \(achievements.perfectWeeks == 1 ? "trofeo por semana completa" : "trofeos por semanas completas")", systemImage: "trophy.fill")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(achievements.perfectWeeks > 0 ? Color.foco : Color.focoSecondary)
    }

    private var milestoneCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 14)], spacing: 14) {
            milestoneCard(
                title: "Primera tarea a tiempo",
                earnedDate: achievements.firstOnTimeDate,
                datePrefix: "Conseguido el ",
                icon: "checkmark.seal.fill",
                lockedSubtitle: "Completá tu primera tarea en su fecha planificada."
            )
            milestoneCard(
                title: "Día completo",
                earnedDate: achievements.firstPerfectDay,
                datePrefix: "Primer día: ",
                icon: "star.fill",
                lockedSubtitle: "Todas las tareas de un día a tiempo (se confirma al cerrar el día)."
            )
            milestoneCard(
                title: "Semana completa",
                earnedDate: achievements.firstPerfectWeek,
                datePrefix: "Semana del ",
                icon: "trophy.fill",
                lockedSubtitle: "Todas las tareas a tiempo en una semana cerrada."
            )
        }
    }

    private func milestoneCard(title: String, earnedDate: Date?, datePrefix: String, icon: String, lockedSubtitle: String) -> some View {
        let earned = earnedDate != nil
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(earned ? Color.foco : Color.focoSecondary.opacity(0.6))
                Spacer()
                if earned {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.foco)
                }
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(earned ? Color.primary : Color.primary.opacity(0.75))
                .lineLimit(1)
            if let earnedDate {
                Text("\(datePrefix)\(earnedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.foco)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(lockedSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.focoSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding(14)
        .background(Color.primary.opacity(earned ? 0.05 : 0.025), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(earned ? Color.foco.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var rulesDisclosure: some View {
        DisclosureGroup("Reglas de los logros") {
            VStack(alignment: .leading, spacing: 6) {
                Text("• El avance es declarado por vos y se evalúa según la fecha original de planificación.")
                Text("• Días y semanas completos se confirman al terminar cada período; hoy permanece provisorio.")
                Text("• Los días sin tareas planificadas son neutrales y no interrumpen una semana completa.")
                Text("• Mover o borrar una tarea no infla logros pasados ni desbloquea reconocimientos de forma artificial.")
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.focoSecondary)
            .padding(.top, 8)
        }
        .font(.system(size: 12))
    }
}
