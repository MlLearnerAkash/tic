import Foundation
import AppKit
import Combine

protocol AppWindowControlling: AnyObject {
    func showPopover(tab: TicTab, focusTodoInput: Bool)
    func closePopover()
    func togglePopover()
    func showMainWindow(tab: TicTab)
    func showSettingsWindow()
}

enum ClipClearRange: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case everything

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Today"
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .everything: return "Everything"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var todos: [TodoItem] = []
    @Published private(set) var clipboard: [ClipboardItem] = []
    @Published var focus = FocusSession()
    @Published var settings = AppSettings()
    @Published var selectedTab: TicTab = .todos
    @Published var confettiTrigger = 0
    @Published var toast: ToastMessage?
    @Published var dndStatus: DNDStatus = .unknown
    @Published var hotkeysRegistered = true
    @Published var focusInputNonce = 0

    weak var windowController: AppWindowControlling?
    var clipboardMonitor: ClipboardMonitor?

    private let storage = TicStorage.shared
    private var saveWorkItem: DispatchWorkItem?
    private var toastWorkItem: DispatchWorkItem?

    private init() {
        let state = storage.load()
        todos = state.todos
        clipboard = state.clipboard.sorted { $0.createdAt > $1.createdAt }
        focus = state.focus
        settings = state.settings

        if focus.isRunning, let remaining = focus.remaining(at: Date()), remaining <= 0 {
            finishExpiredSession()
        }
        applyAppearance()
    }

    // MARK: - Window actions

    func openMainWindow(tab: TicTab? = nil) {
        windowController?.showMainWindow(tab: tab ?? selectedTab)
    }

    func openSettings() {
        windowController?.showSettingsWindow()
    }

    func closePopover() {
        windowController?.closePopover()
    }

    // MARK: - Todos

    var remainingTodoCount: Int { todos.filter { !$0.isCompleted }.count }
    var completedTodoCount: Int { todos.filter(\.isCompleted).count }

    var todoSections: [TodoSection] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var overdue: [TodoItem] = []
        var todayItems: [TodoItem] = []
        var tomorrowItems: [TodoItem] = []
        var future: [Date: [TodoItem]] = [:]

        for todo in todos {
            guard let due = todo.dueDate else {
                todayItems.append(todo)
                continue
            }
            let day = cal.startOfDay(for: due)
            if day < today {
                overdue.append(todo)
            } else if cal.isDateInToday(day) {
                todayItems.append(todo)
            } else if cal.isDateInTomorrow(day) {
                tomorrowItems.append(todo)
            } else {
                future[day, default: []].append(todo)
            }
        }

        func sorted(_ items: [TodoItem]) -> [TodoItem] {
            items.sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                if lhs.isCompleted, rhs.isCompleted {
                    return (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
                }
                return lhs.sortIndex > rhs.sortIndex
            }
        }

        var sections: [TodoSection] = []
        if !overdue.isEmpty {
            sections.append(TodoSection(id: "overdue", title: "Overdue", bucketDate: nil, isOverdue: true, items: sorted(overdue)))
        }
        sections.append(TodoSection(id: "today", title: "Today", bucketDate: today, items: sorted(todayItems)))
        sections.append(TodoSection(id: "tomorrow", title: "Tomorrow", bucketDate: cal.date(byAdding: .day, value: 1, to: today), items: sorted(tomorrowItems)))
        for day in future.keys.sorted() {
            sections.append(TodoSection(id: "day-\(day.timeIntervalSince1970)", title: TicFormat.dayTitle(day), bucketDate: day, items: sorted(future[day] ?? [])))
        }
        return sections
    }

    var flatTodoIDs: [UUID] {
        todoSections.flatMap { $0.items.map(\.id) }
    }

    func addTodo(title: String, dueDate: Date?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextIndex = (todos.map(\.sortIndex).max() ?? 0) + 1
        let item = TodoItem(title: trimmed, dueDate: dueDate, sortIndex: nextIndex)
        todos.append(item)
        saveSoon()
    }

    func toggleTodo(_ id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        if todos[index].isCompleted {
            todos[index].completedAt = nil
        } else {
            todos[index].completedAt = Date()
            confettiTrigger += 1
        }
        saveSoon()
    }

    func updateTodoTitle(_ id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].title = trimmed
        saveSoon()
    }

    func setTodoDueDate(_ id: UUID, date: Date?) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].dueDate = date
        if date != nil {
            todos[index].sortIndex = (todos.map(\.sortIndex).max() ?? 0) + 1
        }
        saveSoon()
    }

    func deleteTodo(_ id: UUID) {
        todos.removeAll { $0.id == id }
        saveSoon()
    }

    func clearCompletedTodos() {
        todos.removeAll(where: \.isCompleted)
        saveSoon()
    }

    /// Drop `draggedID` immediately above `targetID` (or at the top of the target bucket if no target).
    /// Dropping on a row in another day moves the todo to that day.
    func moveTodo(_ draggedID: UUID, above targetID: UUID?, inBucket bucketDate: Date?) {
        guard let fromIndex = todos.firstIndex(where: { $0.id == draggedID }) else { return }
        let dragged = todos.remove(at: fromIndex)

        var updated = dragged
        updated.dueDate = bucketDate

        if let targetID, let target = todos.first(where: { $0.id == targetID }) {
            let bucketItems = todos
                .filter { item in
                    guard let bucketDate else { return item.dueDate == nil }
                    guard let due = item.dueDate else { return false }
                    return Calendar.current.isDate(due, inSameDayAs: bucketDate)
                }
                .filter { !$0.isCompleted }
                .sorted { $0.sortIndex > $1.sortIndex }

            if let targetPosition = bucketItems.firstIndex(where: { $0.id == targetID }) {
                if targetPosition > 0 {
                    let above = bucketItems[targetPosition - 1]
                    updated.sortIndex = (above.sortIndex + target.sortIndex) / 2
                } else {
                    updated.sortIndex = target.sortIndex + 1
                }
            } else {
                updated.sortIndex = target.sortIndex + 1
            }
        } else {
            let bucketItems = todos.filter { item in
                guard let bucketDate else { return item.dueDate == nil }
                guard let due = item.dueDate else { return false }
                return Calendar.current.isDate(due, inSameDayAs: bucketDate)
            }
            updated.sortIndex = (bucketItems.map(\.sortIndex).max() ?? 0) + 1
        }

        todos.append(updated)
        saveSoon()
    }

    // MARK: - Clipboard

    func filteredClips(query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return clipboard }
        return clipboard.filter { $0.searchBlob.contains(trimmed) }
    }

    func recordClipboard(kind: ClipKind,
                         text: String?,
                         imageFileName: String?,
                         filePaths: [String],
                         sourceApp: String,
                         sourceBundleID: String?,
                         hash: String,
                         byteSize: Int) {
        guard !settings.clipboardPaused else { return }

        if let existingIndex = clipboard.firstIndex(where: { $0.hash == hash }) {
            var existing = clipboard.remove(at: existingIndex)
            existing.createdAt = Date()
            existing.copyCount += 1
            existing.sourceApp = sourceApp
            existing.sourceBundleID = sourceBundleID
            clipboard.insert(existing, at: 0)
        } else {
            let item = ClipboardItem(
                kind: kind,
                text: text,
                imageFileName: imageFileName,
                filePaths: filePaths,
                sourceApp: sourceApp,
                sourceBundleID: sourceBundleID,
                hash: hash,
                copyCount: 1,
                byteSize: byteSize
            )
            clipboard.insert(item, at: 0)
        }
        saveSoon()
    }

    func copyClipBack(_ item: ClipboardItem, closePopover shouldClose: Bool = true) {
        let pasteboard = NSPasteboard.general
        clipboardMonitor?.suppressNextChange()
        pasteboard.clearContents()

        switch item.kind {
        case .image:
            if let name = item.imageFileName, let data = storage.imageData(named: name) {
                pasteboard.setData(data, forType: .png)
            } else if let name = item.imageFileName, let image = ThumbnailCache.shared.image(named: name) {
                pasteboard.writeObjects([image])
            }
        case .file:
            let urls = item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }
            if !urls.isEmpty {
                pasteboard.writeObjects(urls)
            } else if let text = item.text {
                pasteboard.setString(text, forType: .string)
            }
        default:
            pasteboard.setString(item.text ?? "", forType: .string)
        }

        showToast("Copied to clipboard")
        if shouldClose { closePopover() }
    }

    func deleteClip(_ id: UUID) {
        if let index = clipboard.firstIndex(where: { $0.id == id }) {
            if let name = clipboard[index].imageFileName {
                ThumbnailCache.shared.remove(named: name)
                storage.deleteImage(named: name)
            }
            clipboard.remove(at: index)
            saveSoon()
        }
    }

    func clearClips(_ range: ClipClearRange) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let cutoff: Date?
        switch range {
        case .today: cutoff = today
        case .week: cutoff = cal.date(byAdding: .day, value: -7, to: Date())
        case .month: cutoff = cal.date(byAdding: .day, value: -30, to: Date())
        case .everything: cutoff = nil
        }

        let removed: [ClipboardItem]
        if let cutoff {
            removed = clipboard.filter { $0.createdAt >= cutoff }
            clipboard.removeAll { $0.createdAt >= cutoff }
        } else {
            removed = clipboard
            clipboard.removeAll()
        }
        for item in removed {
            if let name = item.imageFileName {
                ThumbnailCache.shared.remove(named: name)
                storage.deleteImage(named: name)
            }
        }
        saveSoon()
    }

    func setClipboardPaused(_ paused: Bool) {
        settings.clipboardPaused = paused
        saveNow()
    }

    // MARK: - Focus

    func setFocusDuration(_ seconds: TimeInterval) {
        guard !focus.isRunning else { return }
        focus.duration = min(max(60, seconds), 24 * 60 * 60)
        saveSoon()
    }

    func startFocus() {
        guard !focus.isRunning else { return }
        focus.startedAt = Date()
        focus.isRunning = true
        focus.justFinished = false
        focus.dndTurnedOnByTic = false
        saveNow()

        guard settings.focusDNDEnabled else {
            dndStatus = .off
            return
        }
        dndStatus = .working
        let name = settings.dndOnShortcut
        DNDController.shared.run(shortcut: name) { [weak self] success, message in
            guard let self else { return }
            if success {
                if self.focus.isRunning {
                    self.focus.dndTurnedOnByTic = true
                    self.dndStatus = .on
                } else {
                    // The session ended while the shortcut was starting. Turn
                    // the mode back off so it can never be left on by Tic.
                    DNDController.shared.run(shortcut: self.settings.dndOffShortcut) { _, _ in }
                    self.dndStatus = .off
                }
            } else {
                self.focus.dndTurnedOnByTic = false
                self.dndStatus = .failed(message)
            }
            self.saveSoon()
        }
    }

    func endFocus() {
        guard focus.isRunning else { return }
        let shouldTurnOffDND = focus.dndTurnedOnByTic
        focus.isRunning = false
        focus.startedAt = nil
        focus.justFinished = false
        focus.dndTurnedOnByTic = false
        if shouldTurnOffDND {
            turnOffDND()
        }
        dndStatus = .off
        saveNow()
    }

    func completeFocus() {
        guard focus.isRunning else { return }
        focus.isRunning = false
        focus.lastFinishedAt = Date()
        focus.justFinished = true
        if focus.dndTurnedOnByTic {
            turnOffDND()
        }
        focus.dndTurnedOnByTic = false
        dndStatus = .off
        if settings.playChime {
            NSSound(named: NSSound.Name("Glass"))?.play()
        }
        saveNow()
    }

    func dismissFocusCompletion() {
        focus.justFinished = false
        saveSoon()
    }

    private func turnOffDND() {
        let name = settings.dndOffShortcut
        DNDController.shared.run(shortcut: name) { _, _ in }
    }

    private func finishExpiredSession() {
        focus.isRunning = false
        focus.justFinished = false
        if focus.dndTurnedOnByTic {
            DNDController.shared.run(shortcut: settings.dndOffShortcut) { _, _ in }
        }
        focus.dndTurnedOnByTic = false
        saveNow()
    }

    /// Called by the app timer and after wake. Returns true when a session just ended.
    @discardableResult
    func focusTick() -> Bool {
        guard focus.isRunning, let remaining = focus.remaining(at: Date()) else { return false }
        if remaining <= 0 {
            completeFocus()
            return true
        }
        return false
    }

    func testDNDShortcut(on: Bool) {
        let name = on ? settings.dndOnShortcut : settings.dndOffShortcut
        dndStatus = .working
        DNDController.shared.run(shortcut: name) { [weak self] success, message in
            guard let self else { return }
            self.showToast(success ? "Ran shortcut “\(name)”" : message)
            self.dndStatus = success ? (on ? .on : .off) : .failed(message)
        }
    }

    // MARK: - Settings

    func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        var updated = settings
        mutate(&updated)
        settings = updated
        applyAppearance()
        saveSoon()
    }

    func setAppearance(_ mode: AppearanceMode) {
        settings.appearance = mode
        applyAppearance()
        saveSoon()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
            settings.launchAtLogin = enabled
            showToast(enabled ? "Tic will open at login" : "Launch at login turned off")
        } catch {
            settings.launchAtLogin = LaunchAtLogin.isEnabled
            showToast("Could not change login item: \(error.localizedDescription)")
        }
        saveSoon()
    }

    func applyAppearance() {
        switch settings.appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - Export / import / erase

    func exportState(to url: URL) throws {
        let data = try storage.export(currentSnapshot())
        try data.write(to: url, options: [.atomic])
    }

    func importState(from url: URL) throws -> ImportSummary {
        let data = try Data(contentsOf: url)
        let (newState, summary) = try storage.importBundle(from: data, existing: currentSnapshot())
        todos = newState.todos
        clipboard = newState.clipboard
        saveNow()
        return summary
    }

    func eraseAllData() {
        for item in clipboard {
            if let name = item.imageFileName {
                ThumbnailCache.shared.remove(named: name)
                storage.deleteImage(named: name)
            }
        }
        clipboard = []
        todos = []
        focus = FocusSession()
        confettiTrigger = 0
        saveNow()
        showToast("All todos and clipboard history erased")
    }

    func revealDataFolder() {
        storage.revealInFinder()
    }

    var dataFolderPath: String {
        storage.rootURL.path
    }

    private func currentSnapshot() -> PersistedState {
        PersistedState(todos: todos, clipboard: clipboard, focus: focus, settings: settings)
    }

    // MARK: - Persistence

    private func saveSoon() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.storage.save(self.currentSnapshot())
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    func saveNow() {
        saveWorkItem?.cancel()
        storage.save(currentSnapshot())
    }

    // MARK: - Toasts

    func showToast(_ text: String) {
        let message = ToastMessage(text: text)
        toast = message
        toastWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            if self?.toast?.id == message.id {
                self?.toast = nil
            }
        }
        toastWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: item)
    }
}
