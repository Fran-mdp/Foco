import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct BlockEditor: View {
    @EnvironmentObject var model: FocoModel
    @Environment(\.dismiss) var dismiss
    @ViewState private var config = BlockConfiguration.initial()
    @ViewState private var siteInput = ""
    @ViewState private var message: String?
    @ViewState private var showApps = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Elegí qué puede esperar.").font(.system(size: 25, weight: .medium, design: .rounded))
                    Text("Tu lista se usa en la próxima sesión.").font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
                }
                Spacer()
                Button("Cancelar") { dismiss() }.buttonStyle(.plain)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Sitios de Chrome", systemImage: "globe").font(.system(size: 16, weight: .semibold))
                        HStack {
                            TextField("instagram.com o ejemplo.com/una-ruta", text: $siteInput).textFieldStyle(.roundedBorder).onSubmit(addSite)
                            Button("Agregar", action: addSite).buttonStyle(.glass).disabled(siteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        Text("Un dominio incluye sus subdominios. Una URL con ruta bloquea esa ruta y lo que cuelga de ella. Se ignoran parámetros y fragmentos.")
                            .font(.system(size: 11)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
                        if config.sites.isEmpty { Text("No hay sitios en la lista.").font(.system(size: 12)).foregroundStyle(Color.focoSecondary) }
                        ForEach(config.sites) { site in
                            HStack(spacing: 10) {
                                Toggle(site.label, isOn: Binding(get: {config.sites.first(where: {$0.id == site.id})?.enabled ?? false}, set: { enabled in if let index = config.sites.firstIndex(where: {$0.id == site.id}) {config.sites[index].enabled = enabled} }))
                                    .toggleStyle(.checkbox).font(.system(size: 12)).lineLimit(2)
                                Spacer()
                                Text((model.state.grantedHosts ?? []).contains(site.host) ? "Autorizado" : "Falta permiso")
                                    .font(.system(size: 10)).foregroundStyle((model.state.grantedHosts ?? []).contains(site.host) ? Color.foco : .orange)
                                Button("Quitar", systemImage: "trash") { config.sites.removeAll(where: {$0.id == site.id}) }.labelStyle(.iconOnly).buttonStyle(.plain).help("Quitar este sitio de la lista")
                            }.padding(.vertical, 5)
                        }
                        Text("Después de guardar, abrí Foco desde el ícono de extensiones de Chrome y tocá Autorizar para cada dominio pendiente. Podés quitar permisos desde ese mismo panel.")
                            .font(.system(size: 11)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
                    }.padding(20).panel()
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Aplicaciones de la Mac", systemImage: "app.badge").font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Button("Agregar app…") { showApps = true }.buttonStyle(.glass)
                        }
                        Text("Se pide un cierre normal durante la sesión. Guardá el trabajo y enviá mensajes pendientes antes de iniciar. Foco nunca fuerza el cierre.")
                            .font(.system(size: 11)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
                        if config.applications.isEmpty { Text("No hay aplicaciones en la lista.").font(.system(size: 12)).foregroundStyle(Color.focoSecondary) }
                        ForEach(config.applications) { app in
                            HStack(spacing: 10) {
                                Toggle(app.name, isOn: Binding(get: {config.applications.first(where: {$0.id == app.id})?.enabled ?? false}, set: { enabled in if let index = config.applications.firstIndex(where: {$0.id == app.id}) {config.applications[index].enabled = enabled} }))
                                    .toggleStyle(.checkbox).font(.system(size: 12))
                                Spacer()
                                Button("Quitar", systemImage: "trash") { config.applications.removeAll(where: {$0.id == app.id}) }.labelStyle(.iconOnly).buttonStyle(.plain).help("Quitar esta aplicación de la lista")
                            }.padding(.vertical, 5)
                        }
                        Text("No se pueden agregar Foco, Chrome, componentes esenciales de macOS ni las herramientas de acceso de trabajo protegidas.")
                            .font(.system(size: 11)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
                    }.padding(20).panel()
                }.padding(.vertical, 3)
            }
            if let message { Text(message).font(.system(size: 12)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Text("Desmarcar conserva el elemento. La papelera lo quita.").font(.system(size: 11)).foregroundStyle(Color.focoSecondary)
                Spacer()
                Button("Guardar cambios") {
                    model.error = nil
                    model.saveConfiguration(config)
                    if model.error == nil { dismiss() }
                }.buttonStyle(FocoPrimaryStyle()).disabled(model.session != nil)
            }
        }
        .padding(26).frame(minWidth: 480, idealWidth: 700, maxWidth: 780, minHeight: 580, idealHeight: 700, maxHeight: 780)
        .onAppear { config = model.state.configuration ?? BlockConfiguration.initial() }
        .sheet(isPresented: $showApps) {
            ApplicationPicker(existing: Set(config.applications.map(\.path))) { apps in
                for app in apps where !config.applications.contains(where: {$0.path == app.path}) {
                    if config.applications.count < 50 { config.applications.append(app) }
                    else { message = RuleError.limit.localizedDescription }
                }
            }
        }
    }
    func addSite() {
        do {
            guard config.sites.count < 100 else { throw RuleError.limit }
            let site = try BlockedSite(input: siteInput)
            guard !config.sites.contains(where: {$0.host == site.host && $0.path == site.path}) else { message = "Ese sitio ya está en tu lista."; return }
            config.sites.append(site); siteInput = ""; message = nil
        } catch { message = error.localizedDescription }
    }
}
