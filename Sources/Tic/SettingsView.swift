import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @State private var confirmErase = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                general
                focus
                clipboard
                data
                keys
                about
            }
            .padding(22)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.canvas)
        .confirmationDialog("Erase all todos and clipboard history?", isPresented: $confirmErase) {
            Button("Erase everything", role: .destructive) {
                app.eraseAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clipboard images are deleted too. Settings are kept. This cannot be undone.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Palette.accent, Palette.accent.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text("Tic Settings")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Todos, clipboard and focus. On your Mac.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 2)
    }

    // MARK: - General

    private var general: some View {
        settingsCard("General", icon: "gearshape") {
            VStack(spacing: 12) {
                HStack {
                    settingLabel("Appearance", detail: "Follow the system, or pick one.")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { app.settings.appearance },
                        set: { app.setAppearance($0) }
                    )) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 210)
                }

                ThinDivider()

                HStack {
                    settingLabel("Launch at login", detail: "Start quietly in the menu bar.")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { app.settings.launchAtLogin },
                        set: { app.setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                ThinDivider()

                HStack {
                    settingLabel("Completion chime", detail: "A soft sound when focus ends.")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { app.settings.playChime },
                        set: { value in app.updateSettings { $0.playChime = value } }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                ThinDivider()

                HStack {
                    settingLabel("Global shortcuts", detail: "⌃⌥⌘T opens Tic · ⇧⌘F opens Focus.")
                    Spacer()
                    Text(app.hotkeysRegistered ? "Registered" : "Unavailable")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(app.hotkeysRegistered ? Palette.teal : Palette.pink)
                }
            }
        }
    }

    // MARK: - Focus

    private var focus: some View {
        settingsCard("Focus mode", icon: "moon") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    settingLabel("Use Do Not Disturb", detail: "Turn Focus on while the timer runs.")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { app.settings.focusDNDEnabled },
                        set: { value in app.updateSettings { $0.focusDNDEnabled = value } }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                if app.settings.focusDNDEnabled {
                    ThinDivider()

                    Text("Tic runs two Shortcuts you create in the Shortcuts app. One turns your Focus mode on, the other turns it off. Tic only turns off a mode it turned on.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        shortcutField(
                            title: "Turn on",
                            value: Binding(
                                get: { app.settings.dndOnShortcut },
                                set: { value in app.updateSettings { $0.dndOnShortcut = value } }
                            )
                        )
                        shortcutField(
                            title: "Turn off",
                            value: Binding(
                                get: { app.settings.dndOffShortcut },
                                set: { value in app.updateSettings { $0.dndOffShortcut = value } }
                            )
                        )
                    }

                    HStack(spacing: 8) {
                        Button("Test on") { app.testDNDShortcut(on: true) }
                            .buttonStyle(SoftButtonStyle())
                        Button("Test off") { app.testDNDShortcut(on: false) }
                            .buttonStyle(SoftButtonStyle())
                        Spacer()
                        if case .failed(let message) = app.dndStatus {
                            Text(message)
                                .font(.system(size: 9.5))
                                .foregroundStyle(Palette.pink)
                                .lineLimit(2)
                                .frame(maxWidth: 230, alignment: .trailing)
                        } else if app.dndStatus == .on {
                            Text("Focus mode is on")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(Palette.teal)
                        }
                    }
                }
            }
        }
    }

    private func shortcutField(title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
            TextField("Shortcut name", text: value)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
        }
    }

    // MARK: - Clipboard

    private var clipboard: some View {
        settingsCard("Clipboard", icon: "doc.on.clipboard") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    settingLabel("Recording", detail: "Pause without losing anything already saved.")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { !app.settings.clipboardPaused },
                        set: { app.setClipboardPaused(!$0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                ThinDivider()

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.teal)
                    Text("Passwords are skipped. Tic ignores anything your password manager marks private, and never records from password manager apps.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Text("\(app.clipboard.count) items kept")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu("Clear history…") {
                        Button("Clear today") { app.clearClips(.today) }
                        Button("Clear last 7 days") { app.clearClips(.week) }
                        Button("Clear last 30 days") { app.clearClips(.month) }
                        Divider()
                        Button("Clear everything…", role: .destructive) { confirmErase = true }
                    }
                    .menuStyle(.borderlessButton)
                    .font(.system(size: 10.5))
                    .fixedSize()
                }
            }
        }
    }

    // MARK: - Data

    private var data: some View {
        settingsCard("Your data", icon: "internaldrive") {
            VStack(alignment: .leading, spacing: 12) {
                Text("No account. No cloud. No analytics. Everything lives in Tic’s own folder on this Mac. Export all of it, images included, as one JSON file.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        exportData()
                    } label: {
                        Label("Export everything", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SoftButtonStyle())

                    Button {
                        importData()
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(SoftButtonStyle())
                    .help("Import only ever adds; it never overwrites.")

                    Button {
                        app.revealDataFolder()
                    } label: {
                        Label("Show folder", systemImage: "folder")
                    }
                    .buttonStyle(SoftButtonStyle())

                    Spacer()
                }

                Text(app.dataFolderPath)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)

                ThinDivider()

                HStack {
                    settingLabel("Erase everything", detail: "Todos, clipboard history and images.")
                    Spacer()
                    Button("Erase…") { confirmErase = true }
                        .buttonStyle(SoftButtonStyle(tint: Palette.pink))
                        .foregroundStyle(Palette.pink)
                }
            }
        }
    }

    // MARK: - Keys

    private var keys: some View {
        settingsCard("Shortcuts", icon: "keyboard") {
            VStack(spacing: 7) {
                keyRow("⌃⌥⌘T", "Open Tic from any app")
                keyRow("⇧⌘F", "Open Focus, ready to start")
                keyRow("⌘1 ⌘2 ⌘3", "Todos, Clipboard, Focus")
                keyRow("⌘O", "Open the full window")
                keyRow("↑ ↓", "Move through a list")
                keyRow("space", "Complete a todo, preview a copy")
                keyRow("return", "Add, copy back, or start")
                keyRow("⌘D", "Pick a day for a todo")
                keyRow("delete", "Delete what’s selected")
            }
        }
    }

    private func keyRow(_ key: String, _ label: String) -> some View {
        HStack(spacing: 8) {
            KeyCap(text: key)
                .frame(width: 70, alignment: .leading)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - About

    private var about: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tic \(versionString)")
                    .font(.system(size: 11, weight: .semibold))
                Text("Native SwiftUI · sandbox-free · offline-first")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("Made for the Mac")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Building blocks

    private func settingLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1.5) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
            Text(detail)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
        }
    }

    private func settingsCard<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            content()
        }
        .ticCard(padding: 14, radius: 13, strong: true)
    }

    // MARK: - File panels

    private func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.title = "Export all Tic data"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "Tic Export \(formatter.string(from: Date())).json"

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try app.exportState(to: url)
            app.showToast("Exported all todos and clipboard history")
        } catch {
            presentError("Export failed", error: error)
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import Tic data"
        panel.message = "Import only adds. Nothing already in Tic is overwritten."

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let summary = try app.importState(from: url)
            app.showToast(summary.description)
        } catch {
            presentError("Import failed", error: error)
        }
    }

    private func presentError(_ title: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
