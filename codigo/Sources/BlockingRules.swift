import Foundation

struct BlockedSite: Codable, Identifiable, Equatable {
    var id: String
    var host: String
    var path: String
    var enabled: Bool = true
    var label: String { host + (path == "/" ? "" : path) }
    var originPattern: String { "*://*.\(host)/*" }

    init(input: String) throws {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count <= 512, !text.isEmpty,
              let parts = URLComponents(string: text.contains("://") ? text : "https://" + text),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              parts.user == nil, parts.password == nil, parts.port == nil,
              let hostname = parts.host?.lowercased(), Self.validHost(hostname) else { throw RuleError.invalidSite }
        let encodedPath = parts.percentEncodedPath.isEmpty ? "/" : parts.percentEncodedPath
        guard encodedPath.hasPrefix("/"), encodedPath.count <= 400,
              !encodedPath.contains("\\"), !encodedPath.contains("\n"),
              !encodedPath.split(separator: "/").contains(where: { [".", ".."].contains(String($0)) }) else { throw RuleError.invalidSite }
        host = hostname
        path = encodedPath.count > 1 ? encodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")) : ""
        path = "/" + path
        id = UUID().uuidString
    }
    static func validHost(_ host: String) -> Bool {
        guard host.count <= 253, host.contains("."), !host.hasSuffix("."),
              host.unicodeScalars.allSatisfy({ $0.isASCII }),
              host.range(of: #"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$"#, options: .regularExpression) != nil,
              !host.split(separator: ".").allSatisfy({ Int($0) != nil }),
              host.split(separator: ".").allSatisfy({ $0.count <= 63 }) else { return false }
        return true
    }
    func validated() throws -> BlockedSite {
        let parsed = try BlockedSite(input: "https://" + host + path)
        guard parsed.host == host, parsed.path == path, UUID(uuidString: id) != nil else { throw RuleError.invalidSite }
        return self
    }
}
struct BlockedApplication: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var bundleID: String
    var path: String
    var enabled: Bool = true
    static let protectedIDs: Set<String> = [
        "local.francisco.Foco", "local.foco.Foco", "com.apple.finder", "com.apple.dock",
        "com.apple.systemuiserver", "com.apple.loginwindow", "com.apple.systempreferences",
        "com.apple.WindowManager", "com.apple.controlcenter", "com.google.Chrome",
        "com.microsoft.rdc.macos", "com.microsoft.windowsapp"
    ]
    static func isProtected(_ identifier: String, path: String) -> Bool {
        let lower = identifier.lowercased()
        return protectedIDs.contains(where: { $0.lowercased() == lower }) ||
            lower.hasPrefix("com.fortinet.") || lower.contains("forticlient") ||
            lower.hasPrefix("com.google.chrome.") || lower.hasPrefix("com.apple.security") ||
            path.hasPrefix("/System/Library/") || path.hasPrefix("/Library/Apple/")
    }
    init(url: URL) throws {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        guard resolved.pathExtension.lowercased() == "app", let bundle = Bundle(url: resolved),
              let identifier = bundle.bundleIdentifier, !identifier.isEmpty,
              !Self.isProtected(identifier, path: resolved.path) else { throw RuleError.protectedApplication }
        id = UUID().uuidString; path = resolved.path; bundleID = identifier
        name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
               (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? resolved.deletingPathExtension().lastPathComponent
    }
    func validated() throws -> BlockedApplication {
        let current = try BlockedApplication(url: URL(fileURLWithPath: path))
        guard current.bundleID == bundleID, current.path == path, UUID(uuidString: id) != nil else { throw RuleError.protectedApplication }
        return self
    }
}
struct BlockConfiguration: Codable, Equatable {
    var sites: [BlockedSite]
    var applications: [BlockedApplication]
    static func initial() -> BlockConfiguration {
        let sites = ["youtube.com", "instagram.com", "youtu.be", "web.whatsapp.com"].compactMap { try? BlockedSite(input: $0) }
        let apps = ["/Applications/WhatsApp.app"].compactMap { try? BlockedApplication(url: URL(fileURLWithPath: $0)) }
        return BlockConfiguration(sites: sites, applications: apps)
    }
}
enum RuleError: LocalizedError {
    case invalidSite, protectedApplication, limit, missingPermission, empty
    var errorDescription: String? {
        switch self {
        case .invalidSite: return "Ingresá un dominio como instagram.com o una URL con ruta. Usá http o https, sin usuario, contraseña, puerto ni comodines."
        case .protectedApplication: return "Esta aplicación no se puede agregar: está protegida, no es una app válida o cambió desde que la elegiste."
        case .limit: return "Podés guardar hasta 100 sitios y 50 aplicaciones."
        case .missingPermission: return "Falta autorizar un sitio en Chrome. Abrí el complemento Foco y tocá Autorizar junto al sitio."
        case .empty: return "Seleccioná al menos un sitio o una aplicación para bloquear."
        }
    }
}
