import SwiftUI
import AppKit

@main
struct TicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(AppState.shared)
                .frame(width: 580, height: 680)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, AppWindowControlling, NSMenuDelegate, NSPopoverDelegate {
    private let app = AppState.shared
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var hotKeys: HotKeyManager?
    private var clipboardMonitor: ClipboardMonitor?
    private var tickTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var contextMenu: NSMenu?
    private var mouseMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        app.windowController = self

        setupStatusItem()
        setupPopover()

        let monitor = ClipboardMonitor(app: app)
        clipboardMonitor = monitor
        app.clipboardMonitor = monitor
        monitor.start()

        let hotKeys = HotKeyManager()
        hotKeys.onOpen = { [weak self] in
            self?.showPopover(tab: .todos, focusTodoInput: true)
        }
        hotKeys.onFocus = { [weak self] in
            self?.showPopover(tab: .focus, focusTodoInput: false)
        }
        hotKeys.register()
        self.hotKeys = hotKeys
        app.hotkeysRegistered = hotKeys.registered

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let ended = self.app.focusTick()
            self.updateStatusItem()
            if ended {
                self.app.selectedTab = .focus
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
        updateStatusItem()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.app.focusTick()
            self?.updateStatusItem()
        }

        if LaunchAtLogin.isEnabled != app.settings.launchAtLogin {
            app.settings.launchAtLogin = LaunchAtLogin.isEnabled
        }
        app.applyAppearance()

        if ProcessInfo.processInfo.environment["TIC_RENDER_SNAPSHOTS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.renderSnapshots()
            }
        } else if ProcessInfo.processInfo.environment["TIC_SEED_DEMO"] == "1", app.todos.isEmpty {
            seedDemoData()
            app.saveNow()
        }
    }

    @MainActor
    private func renderSnapshots() {
        if ProcessInfo.processInfo.environment["TIC_DEMO"] == "1" {
            seedDemoData()
        }

        let tabs: [TicTab] = [.todos, .clipboard, .focus]
        for tab in tabs {
            app.selectedTab = tab
            let view = MenuBarView()
                .environmentObject(app)
                .frame(width: 420, height: 570)
            render(view, to: "/tmp/tic-popover-\(tab.rawValue).png")
        }

        app.selectedTab = .todos
        render(
            FullWindowView().environmentObject(app).frame(width: 1000, height: 680),
            to: "/tmp/tic-window-todos.png"
        )
        app.selectedTab = .clipboard
        render(
            FullWindowView().environmentObject(app).frame(width: 1000, height: 680),
            to: "/tmp/tic-window-clipboard.png"
        )
        app.selectedTab = .focus
        render(
            FullWindowView().environmentObject(app).frame(width: 1000, height: 680),
            to: "/tmp/tic-window-focus.png"
        )
        render(
            SettingsView().environmentObject(app).frame(width: 580, height: 680),
            to: "/tmp/tic-settings.png"
        )

        if ProcessInfo.processInfo.environment["TIC_DEMO"] == "1" {
            app.eraseAllData()
        }
        NSApp.terminate(nil)
    }

    @MainActor
    private func render<V: View>(_ view: V, to path: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            NSLog("Tic: snapshot render failed for \(path)")
            return
        }
        try? png.write(to: URL(fileURLWithPath: path))
        NSLog("Tic: wrote snapshot \(path)")
    }

    private func seedDemoData() {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)
        let later = Calendar.current.date(byAdding: .day, value: 3, to: today)
        app.addTodo(title: "Renew passport", dueDate: nil)
        app.addTodo(title: "Push the hotfix", dueDate: today)
        app.addTodo(title: "Reply to Aisha about Friday", dueDate: nil)
        app.addTodo(title: "Call Mom", dueDate: tomorrow)
        app.addTodo(title: "Book train tickets", dueDate: later)
        if let first = app.todos.first { app.toggleTodo(first.id) }

        app.recordClipboard(
            kind: .link, text: "https://github.com/sparkle-project/Sparkle",
            imageFileName: nil, filePaths: [], sourceApp: "Safari",
            sourceBundleID: "com.apple.Safari", hash: "demo-link", byteSize: 44
        )
        app.recordClipboard(
            kind: .code, text: "npm run build && npm run deploy",
            imageFileName: nil, filePaths: [], sourceApp: "Terminal",
            sourceBundleID: "com.apple.Terminal", hash: "demo-code", byteSize: 29
        )
        app.recordClipboard(
            kind: .text, text: "Standup moved to 4:30",
            imageFileName: nil, filePaths: [], sourceApp: "Mail",
            sourceBundleID: "com.apple.mail", hash: "demo-text", byteSize: 20
        )
        app.recordClipboard(
            kind: .text, text: "Invoice #1042 is due on the 30th",
            imageFileName: nil, filePaths: [], sourceApp: "Mail",
            sourceBundleID: "com.apple.mail", hash: "demo-text-2", byteSize: 32
        )

        app.focus.duration = 25 * 60
        app.focus.startedAt = Date().addingTimeInterval(-8 * 60)
        app.focus.isRunning = true
        app.focus.justFinished = false
        app.dndStatus = .on
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        tickTimer?.invalidate()
        app.saveNow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow(tab: app.selectedTab)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme?.lowercased() == "tic" else { continue }
            switch (url.host ?? url.path).lowercased() {
            case "todos", "":
                showPopover(tab: .todos, focusTodoInput: true)
            case "clipboard":
                showPopover(tab: .clipboard, focusTodoInput: false)
            case "focus":
                showPopover(tab: .focus, focusTodoInput: false)
                if url.path.lowercased().contains("start") {
                    app.startFocus()
                }
            case "window":
                showMainWindow(tab: app.selectedTab)
            case "settings":
                showSettingsWindow()
            default:
                showPopover(tab: app.selectedTab, focusTodoInput: false)
            }
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "checkmark.square", accessibilityDescription: "Tic")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Tic — todos, clipboard, focus"
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 420, height: 570)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(app)
                .frame(width: 420, height: 570)
        )
        self.popover = popover
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        if app.focus.isRunning, let remaining = app.focus.remaining(at: Date()) {
            let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Focus session running")
            image?.isTemplate = true
            button.image = image
            button.title = " " + TicFormat.menuCountdown(remaining)
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        } else {
            let image = NSImage(systemSymbolName: "checkmark.square", accessibilityDescription: "Tic")
            image?.isTemplate = true
            button.image = image
            button.title = ""
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let open = NSMenuItem(title: "Open Tic", action: #selector(menuOpen(_:)), keyEquivalent: "o")
        open.target = self
        menu.addItem(open)

        let settings = NSMenuItem(title: "Settings…", action: #selector(menuSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let pauseTitle = app.settings.clipboardPaused ? "Resume Clipboard Recording" : "Pause Clipboard Recording"
        let pause = NSMenuItem(title: pauseTitle, action: #selector(menuToggleClipboard(_:)), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Tic", action: #selector(menuQuit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        contextMenu = menu
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
        contextMenu = nil
    }

    @objc private func menuOpen(_ sender: Any?) {
        showMainWindow(tab: app.selectedTab)
    }

    @objc private func menuSettings(_ sender: Any?) {
        showSettingsWindow()
    }

    @objc private func menuToggleClipboard(_ sender: Any?) {
        app.setClipboardPaused(!app.settings.clipboardPaused)
        app.showToast(app.settings.clipboardPaused ? "Clipboard recording paused" : "Clipboard recording on")
    }

    @objc private func menuQuit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    // MARK: - AppWindowControlling

    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(tab: app.selectedTab, focusTodoInput: false)
        }
    }

    func showPopover(tab: TicTab, focusTodoInput: Bool) {
        app.selectedTab = tab
        NSApp.activate(ignoringOtherApps: true)
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        installPopoverMonitors()
        if focusTodoInput {
            app.focusInputNonce += 1
        }
    }

    func closePopover() {
        popover.performClose(nil)
        removePopoverMonitors()
    }

    func popoverDidClose(_ notification: Notification) {
        removePopoverMonitors()
    }

    /// With an application-defined popover, outside clicks are our job. The
    /// status item itself is excluded so its action can toggle the popover.
    private func installPopoverMonitors() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            if event.window === self.popover.contentViewController?.view.window {
                return event
            }
            if let statusWindow = self.statusItem.button?.window, event.window === statusWindow {
                return event
            }
            self.closePopover()
            return event
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.closePopover()
        }
    }

    private func removePopoverMonitors() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }

    func showMainWindow(tab: TicTab) {
        app.selectedTab = tab
        closePopover()

        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Tic"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.contentMinSize = NSSize(width: 820, height: 600)
            window.contentView = NSHostingView(
                rootView: FullWindowView()
                    .environmentObject(app)
            )
            window.setContentSize(NSSize(width: 1000, height: 680))
            window.setFrameAutosaveName("TicMainWindow")
            placeOnActiveScreen(window)
            mainWindow = window
        }

        if let mainWindow, !isOnVisibleScreen(mainWindow) {
            placeOnActiveScreen(mainWindow)
        }

        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
        mainWindow?.orderFrontRegardless()
        if let mainWindow, mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }
    }

    private func placeOnActiveScreen(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.main
            ?? NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        window.setFrameOrigin(origin)
    }

    private func isOnVisibleScreen(_ window: NSWindow) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(window.frame) }
    }

    func showSettingsWindow() {
        closePopover()
        NSApp.activate(ignoringOtherApps: true)
        let opened = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        if !opened {
            showFallbackSettingsWindow()
        }
    }

    private func showFallbackSettingsWindow() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 680),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Tic Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: SettingsView()
                    .environmentObject(app)
            )
            window.setContentSize(NSSize(width: 580, height: 680))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
