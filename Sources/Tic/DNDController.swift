import Foundation
import AppKit

enum DNDStatus: Equatable {
    case unknown
    case off
    case working
    case on
    case failed(String)
}

/// Focus modes are toggled through user-authored Shortcuts, which is the only
/// supported, non-private way for a Mac app to change Do Not Disturb state.
final class DNDController {
    static let shared = DNDController()

    private let queue = DispatchQueue(label: "app.tic.shortcuts", qos: .userInitiated)

    private init() {}

    func run(shortcut name: String, completion: @escaping (Bool, String) -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async { completion(false, "No shortcut name is set.") }
            return
        }

        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", trimmed]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Could not run Shortcuts: \(error.localizedDescription)")
                }
                return
            }

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let success = process.terminationStatus == 0

            DispatchQueue.main.async {
                if success {
                    completion(true, "")
                } else {
                    let detail = output.isEmpty ? "The shortcut could not be run." : output
                    completion(false, "Shortcut “\(trimmed)” failed. Create it in Shortcuts. \(detail)")
                }
            }
        }
    }

    func availableShortcuts(completion: @escaping ([String]) -> Void) {
        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let names = String(data: data, encoding: .utf8)?
                .split(separator: "\n")
                .map(String.init) ?? []
            DispatchQueue.main.async { completion(names) }
        }
    }
}
