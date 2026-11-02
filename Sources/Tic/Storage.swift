import Foundation
import AppKit

// MARK: - On-disk storage

final class TicStorage {
    static let shared = TicStorage()

    let rootURL: URL
    let imagesURL: URL
    private let stateURL: URL
    private let fileManager = FileManager.default

    private init() {
        if let custom = ProcessInfo.processInfo.environment["TIC_DATA_DIR"], !custom.isEmpty {
            rootURL = URL(fileURLWithPath: custom, isDirectory: true)
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
            rootURL = base.appendingPathComponent("Tic", isDirectory: true)
        }
        imagesURL = rootURL.appendingPathComponent("Clipboard", isDirectory: true)
        stateURL = rootURL.appendingPathComponent("state.json")
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
    }

    private static func encoder(pretty: Bool = false) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : []
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func load() -> PersistedState {
        guard fileManager.fileExists(atPath: stateURL.path) else { return PersistedState() }
        do {
            let data = try Data(contentsOf: stateURL)
            return try Self.decoder().decode(PersistedState.self, from: data)
        } catch {
            // Keep a copy of anything unreadable rather than silently destroying it.
            let backup = rootURL.appendingPathComponent("state-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? fileManager.copyItem(at: stateURL, to: backup)
            return PersistedState()
        }
    }

    func save(_ state: PersistedState) {
        do {
            let data = try Self.encoder().encode(state)
            try data.write(to: stateURL, options: [.atomic])
        } catch {
            NSLog("Tic: could not save state: \(error)")
        }
    }

    // MARK: Images

    func imageURL(for fileName: String) -> URL {
        imagesURL.appendingPathComponent(fileName)
    }

    func writeImage(_ data: Data) -> String? {
        let name = UUID().uuidString + ".png"
        do {
            try data.write(to: imageURL(for: name), options: [.atomic])
            return name
        } catch {
            NSLog("Tic: could not write clipboard image: \(error)")
            return nil
        }
    }

    func deleteImage(named name: String) {
        try? fileManager.removeItem(at: imageURL(for: name))
    }

    func imageData(named name: String) -> Data? {
        try? Data(contentsOf: imageURL(for: name))
    }

    // MARK: Export / import

    func export(_ state: PersistedState) throws -> Data {
        let clips = state.clipboard.map { item -> ExportedClip in
            let data = item.imageFileName.flatMap { imageData(named: $0) }
            return ExportedClip(item: item, imageData: data)
        }
        let bundle = ExportBundle(
            app: "Tic",
            version: 1,
            exportedAt: Date(),
            todos: state.todos,
            clipboard: clips,
            focus: state.focus,
            settings: state.settings
        )
        return try Self.encoder(pretty: true).encode(bundle)
    }

    func importBundle(from data: Data, existing: PersistedState) throws -> (PersistedState, ImportSummary) {
        let bundle = try Self.decoder().decode(ExportBundle.self, from: data)
        var result = existing
        var summary = ImportSummary()

        // Todos are merged by identity only. Import never overwrites.
        var knownTodoIDs = Set(result.todos.map(\.id))
        for todo in bundle.todos where !knownTodoIDs.contains(todo.id) {
            result.todos.append(todo)
            knownTodoIDs.insert(todo.id)
            summary.todosAdded += 1
        }

        // Clipboard is merged by content hash. Images are copied with fresh filenames.
        var knownHashes = Set(result.clipboard.map(\.hash))
        for exported in bundle.clipboard {
            var item = exported.item
            if knownHashes.contains(item.hash) {
                summary.clipsSkipped += 1
                continue
            }
            if let imageData = exported.imageData {
                item.imageFileName = writeImage(imageData)
            }
            result.clipboard.append(item)
            knownHashes.insert(item.hash)
            summary.clipsAdded += 1
        }

        result.clipboard.sort { $0.createdAt > $1.createdAt }
        result.todos.sort { $0.sortIndex > $1.sortIndex }
        return (result, summary)
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([rootURL])
    }
}

struct ExportedClip: Codable {
    var item: ClipboardItem
    var imageData: Data?
}

struct ExportBundle: Codable {
    var app: String
    var version: Int
    var exportedAt: Date
    var todos: [TodoItem]
    var clipboard: [ExportedClip]
    var focus: FocusSession
    var settings: AppSettings
}

struct ImportSummary {
    var todosAdded = 0
    var clipsAdded = 0
    var clipsSkipped = 0

    var description: String {
        let todoPart = "\(todosAdded) todo\(todosAdded == 1 ? "" : "s")"
        let clipPart = "\(clipsAdded) clipboard item\(clipsAdded == 1 ? "" : "s")"
        return "Added \(todoPart) and \(clipPart)."
    }
}

// MARK: - Image cache

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 300
    }

    func image(named name: String) -> NSImage? {
        if let cached = cache.object(forKey: name as NSString) {
            return cached
        }
        guard let image = NSImage(contentsOf: TicStorage.shared.imageURL(for: name)) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    func remove(named name: String) {
        cache.removeObject(forKey: name as NSString)
    }
}
