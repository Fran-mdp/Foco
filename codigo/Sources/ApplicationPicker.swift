import SwiftUI
import AppKit

struct ApplicationPicker: View {
    let existing: Set<String>
    var add: ([BlockedApplication]) -> Void
    @Environment(\.dismiss) var dismiss
    @ViewState private var applications: [BlockedApplication] = []
    @ViewState private var selection: Set<String> = []
    @ViewState private var query = ""
    var filtered: [BlockedApplication] {
        applications.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tus aplicaciones").font(.system(size: 24, weight: .medium, design: .rounded))
            Text("Elegí las que querés cerrar durante tus sesiones.").font(.system(size: 12)).foregroundStyle(Color.focoSecondary)
            TextField("Buscar una app", text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filtered) { app in
                        HStack(spacing: 12) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path)).resizable().frame(width: 30, height: 30)
                            Toggle(app.name, isOn: Binding(get: {existing.contains(app.path) || selection.contains(app.path)}, set: { enabled in
                                if enabled {selection.insert(app.path)} else {selection.remove(app.path)}
                            })).toggleStyle(.checkbox).disabled(existing.contains(app.path))
                            Spacer()
                            if existing.contains(app.path) {Text("Agregada").font(.system(size: 10)).foregroundStyle(Color.focoSecondary)}
                        }.padding(9)
                    }
                    if filtered.isEmpty { Text("No hay coincidencias.").foregroundStyle(Color.focoSecondary).padding(24) }
                }
            }.frame(minHeight: 260)
            Text("Se revisan las carpetas de aplicaciones de esta Mac. Las apps esenciales y las herramientas protegidas no aparecen en la lista.")
                .font(.system(size: 11)).foregroundStyle(Color.focoSecondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancelar") {dismiss()}.buttonStyle(.plain)
                Spacer()
                Button("Agregar selección (\(selection.count))") {add(applications.filter {selection.contains($0.path)});dismiss()}
                    .buttonStyle(FocoPrimaryStyle()).disabled(selection.isEmpty)
            }
        }.padding(24).frame(width: 470, height: 550).onAppear { applications = Self.installed() }
    }
    static func installed() -> [BlockedApplication] {
        let roots = [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        var result: [String: BlockedApplication] = [:]
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {continue}
            while let url = enumerator.nextObject() as? URL {
                if url.pathExtension.lowercased() == "app" {
                    enumerator.skipDescendants()
                    if let app = try? BlockedApplication(url: url) {result[app.path] = app}
                } else if url.pathComponents.count - root.pathComponents.count >= 2 {enumerator.skipDescendants()}
            }
        }
        return result.values.sorted {$0.name.localizedStandardCompare($1.name) == .orderedAscending}
    }
}
