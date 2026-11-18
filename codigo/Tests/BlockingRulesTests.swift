import Foundation
@main struct BlockingRulesTests {
 static func main() throws {
    let parsed=try BlockedSite(input:" HTTPS://Example.com/study/?token=private#section ")
    precondition(parsed.host=="example.com" && parsed.path=="/study" && !parsed.label.contains("private"))
    for input in ["", "chrome://extensions", "file:///etc/hosts", "https://user:pass@example.com", "https://example.com:8080", "*.example.com", "127.0.0.1", "example.com|other.com"] {
        do { _=try BlockedSite(input:input);fatalError("Accepted invalid site: \(input)") } catch RuleError.invalidSite {}
    }
    precondition(BlockedApplication.isProtected("com.apple.finder",path:"/System/Library/CoreServices/Finder.app"))
    precondition(BlockedApplication.isProtected("com.fortinet.FortiClient",path:"/Applications/FortiClient.app"))
    precondition(BlockedApplication.isProtected("com.microsoft.rdc.macos",path:"/Applications/Windows App.app"))
    precondition(BlockedApplication.isProtected("com.google.Chrome",path:"/Applications/Google Chrome.app"))
    precondition(BlockedApplication.isProtected("local.francisco.Foco",path:"/Applications/Foco.app"))
    precondition(!BlockedApplication.isProtected("net.whatsapp.WhatsApp",path:"/Applications/WhatsApp.app"))
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent("FocoRules-\(UUID().uuidString)")
    defer {try? FileManager.default.removeItem(at:dir)}
    let store=FocusStore(directory:dir)
    _=try store.read(now:1000)
    let config=BlockConfiguration(sites:[parsed],applications:[])
    try store.updateConfiguration(config)
    try store.acknowledge(profile:"test-profile",appliedID:"",error:nil,grantedHosts:[],now:1000)
    do {try store.start(duration:nil,firm:false,useConfiguration:true,now:1000);fatalError("Started without site permission")} catch RuleError.missingPermission {}
    try store.acknowledge(profile:"test-profile",appliedID:"",error:nil,grantedHosts:["example.com"],now:1000)
    try store.start(duration:nil,firm:false,useConfiguration:true,now:1000)
    let session=try store.read(now:1000).session!
    precondition(session.sites==[parsed] && session.applications==[])
    do {try store.updateConfiguration(BlockConfiguration(sites:[],applications:[]));fatalError("Edited active session")} catch FocusError.busy {}
    try store.stop(now:1010)
    try store.updateConfiguration(BlockConfiguration(sites:[],applications:[]))
    try store.acknowledge(profile:"test-profile",appliedID:"",error:nil,grantedHosts:[],now:1010)
    do {try store.start(duration:nil,firm:false,useConfiguration:true,now:1010);fatalError("Empty block list")} catch RuleError.empty {}
    print("Blocking editor/security checks passed: domains, path/query normalization, protected apps, permissions, session snapshots and edit locks.")
 }
}
