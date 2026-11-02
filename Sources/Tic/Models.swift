import Foundation
import AppKit

// MARK: - Todos

struct TodoItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var title: String
    var dueDate: Date?
    var createdAt: Date = Date()
    var completedAt: Date?
    var sortIndex: Double = 0

    var isCompleted: Bool { completedAt != nil }
}

struct TodoSection: Identifiable {
    var id: String
    var title: String
    var bucketDate: Date?
    var isOverdue: Bool = false
    var items: [TodoItem]
}

// MARK: - Clipboard

enum ClipKind: String, Codable, CaseIterable {
    case text
    case link
    case code
    case image
    case file

    var label: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .code: return "Code"
        case .image: return "Image"
        case .file: return "File"
        }
    }

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var kind: ClipKind
    var text: String?
    var imageFileName: String?
    var filePaths: [String] = []
    var sourceApp: String = "Unknown"
    var sourceBundleID: String?
    var hash: String
    var copyCount: Int = 1
    var byteSize: Int = 0

    var displayText: String {
        switch kind {
        case .image:
            return "Image"
        case .file:
            if filePaths.count == 1 {
                return (filePaths[0] as NSString).lastPathComponent
            }
            return "\(filePaths.count) files"
        default:
            return text ?? ""
        }
    }

    var secondaryText: String {
        switch kind {
        case .file:
            return filePaths.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
        default:
            return text ?? ""
        }
    }

    var searchBlob: String {
        var parts: [String] = [kind.label, sourceApp, text ?? ""]
        parts.append(contentsOf: filePaths.map { ($0 as NSString).lastPathComponent })
        return parts.joined(separator: " ").lowercased()
    }
}

// MARK: - Focus

struct FocusSession: Codable, Equatable {
    var startedAt: Date?
    var duration: TimeInterval = 25 * 60
    var isRunning: Bool = false
    var dndTurnedOnByTic: Bool = false
    var lastFinishedAt: Date?
    var justFinished: Bool = false

    var endDate: Date? {
        guard let startedAt else { return nil }
        return startedAt.addingTimeInterval(duration)
    }

    func remaining(at now: Date) -> TimeInterval? {
        guard isRunning, let endDate else { return nil }
        return endDate.timeIntervalSince(now)
    }

    var elapsedFraction: Double {
        guard duration > 0 else { return 0 }
        guard let remaining = remaining(at: Date()) else { return isRunning ? 1 : 0 }
        return max(0, min(1, 1 - (remaining / duration)))
    }
}

// MARK: - Settings

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var appearance: AppearanceMode = .system
    var launchAtLogin: Bool = false
    var clipboardPaused: Bool = false
    var focusDNDEnabled: Bool = true
    var dndOnShortcut: String = "Tic Focus On"
    var dndOffShortcut: String = "Tic Focus Off"
    var playChime: Bool = true

    var clipboardFontSize: Double = 12
}

// MARK: - Persistence wrapper

struct PersistedState: Codable {
    var todos: [TodoItem] = []
    var clipboard: [ClipboardItem] = []
    var focus: FocusSession = FocusSession()
    var settings: AppSettings = AppSettings()
}

// MARK: - Tabs

enum TicTab: String, CaseIterable, Identifiable {
    case todos
    case clipboard
    case focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todos: return "Todos"
        case .clipboard: return "Clipboard"
        case .focus: return "Focus"
        }
    }

    var icon: String {
        switch self {
        case .todos: return "checklist"
        case .clipboard: return "doc.on.clipboard"
        case .focus: return "timer"
        }
    }
}

// MARK: - Formatting

enum TicFormat {
    static func menuCountdown(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    static func clock(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    static func durationLabel(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
        }
        return "\(minutes) min"
    }

    static func dayTitle(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = cal.component(.year, from: date) == cal.component(.year, from: Date()) ? "EEEE, MMM d" : "MMM d, yyyy"
        return f.string(from: date)
    }

    static func shortDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }

    static func bytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let ticFocusTodoInput = Notification.Name("tic.focusTodoInput")
    static let ticFocusAddField = Notification.Name("tic.focusAddField")
    static let ticFocusSearch = Notification.Name("tic.focusSearch")
    static let ticShowTab = Notification.Name("tic.showTab")
}
