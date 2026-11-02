import Foundation
import ServiceManagement

enum LaunchAtLogin {
    private static let agentLabel = "app.tic.launch"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }

    static var isEnabled: Bool {
        if SMAppService.mainApp.status == .enabled { return true }
        return FileManager.default.fileExists(atPath: agentURL.path)
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            if Bundle.main.bundlePath.hasSuffix(".app") {
                do {
                    try SMAppService.mainApp.register()
                    try? removeAgent()
                    return
                } catch {
                    // Ad-hoc or non-Applications builds can fail to register a
                    // login item. Fall back to a per-user LaunchAgent.
                    try installAgent()
                    return
                }
            }
            try installAgent()
        } else {
            try? SMAppService.mainApp.unregister()
            try removeAgent()
        }
    }

    private static func installAgent() throws {
        let directory = agentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: agentURL, options: [.atomic])
    }

    private static func removeAgent() throws {
        if FileManager.default.fileExists(atPath: agentURL.path) {
            try FileManager.default.removeItem(at: agentURL)
        }
    }
}
