import Foundation
import Darwin
import AppKit

@main
struct NativeHost {
    static func main() {
        guard CommandLine.arguments.count > 1,
              CommandLine.arguments[1] == "chrome-extension://ffnpgijgkijehlmgedmniefkmodlnmgf/" else { exit(1) }
        #if TESTING
        let store = FocusStore(directory: URL(fileURLWithPath: ProcessInfo.processInfo.environment["FOCO_TEST_DIRECTORY"]!))
        #else
        let store = FocusStore()
        #endif
        let appGuard = ApplicationGuard()
        var profile: String?
        var buffer = Data()
        var lastSent = Data()
        var lastPush = Date.distantPast
        func send(_ object: [String: Any]) {
            guard let data = try? JSONSerialization.data(withJSONObject: object), data.count < 1_000_000 else { return }
            var size = UInt32(data.count).littleEndian
            FileHandle.standardOutput.write(Data(bytes: &size, count: 4))
            FileHandle.standardOutput.write(data)
        }
        func snapshot() {
            guard let profile else { return }
            do {
                let state = try store.read()
                guard state.ownerProfile == nil || state.ownerProfile == profile else { send(["error":"wrongProfile"]); return }
                let status = appGuard.enforce(session: state.session, now: Date().timeIntervalSince1970)
                if state.appBlockStatus != status { try store.transaction { $0.appBlockStatus = status } }
                guard state.ownerProfile == nil || state.ownerProfile == profile else { send(["error":"wrongProfile"]); return }
                var object: [String: Any] = ["revision": state.revision, "session": NSNull()]
                if let config = state.configuration {
                    object["configuration"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(config))
                }
                if let s = state.session, let data = try? JSONEncoder().encode(s), var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    json.removeValue(forKey: "taskID")
                    object["session"] = json
                }
                let encoded = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
                if encoded != lastSent || Date().timeIntervalSince(lastPush) > 4 {
                    send(object); lastSent = encoded; lastPush = Date()
                }
            } catch { send(["error":"stateUnreadable"]) }
        }
        while true {
            var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            let available = poll(&descriptor, 1, 200)
            if available < 0 { break }
            if available > 0 {
                if descriptor.revents & Int16(POLLHUP | POLLERR | POLLNVAL) != 0 { break }
                var bytes = [UInt8](repeating: 0, count: 8192)
                let count = read(STDIN_FILENO, &bytes, bytes.count)
                if count <= 0 { break }
                buffer.append(contentsOf: bytes.prefix(count))
                while buffer.count >= 4 {
                    let length = buffer.prefix(4).enumerated().reduce(0) { $0 | (Int($1.element) << ($1.offset * 8)) }
                    if length > 65536 { exit(2) }
                    guard buffer.count >= length + 4 else { break }
                    let payload = buffer.subdata(in: 4..<(length + 4)); buffer = Data(buffer.dropFirst(length + 4))
                    guard let message = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                          let token = message["profile"] as? String, UUID(uuidString: token) != nil else { exit(3) }
                    guard ["hello", "ack"].contains(message["op"] as? String ?? ""),
                          (message["appliedID"] as? String ?? "").count <= 128,
                          (message["error"] as? String ?? "").count <= 256,
                          (message["grantedHosts"] as? [String] ?? []).count <= 100 else { exit(3) }
                    profile = token
                    do {
                        if message["op"] as? String == "ack" {
                            try store.acknowledge(profile: token, appliedID: message["appliedID"] as? String ?? "", error: message["error"] as? String, grantedHosts: message["grantedHosts"] as? [String])
                        }
                    } catch { send(["error":"wrongProfile"]) }
                }
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
            snapshot()
        }
    }
}
