import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            TicTabBar(
                selection: $app.selectedTab,
                todoCount: app.remainingTodoCount,
                clipCount: app.clipboard.count,
                focusActive: app.focus.isRunning
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Group {
                switch app.selectedTab {
                case .todos:
                    TodosView()
                case .clipboard:
                    ClipboardView()
                case .focus:
                    FocusView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .frame(width: 420, height: 570)
        .background(Palette.canvas)
        .background(
            LinearGradient(
                colors: [Palette.accent.opacity(0.045), .clear],
                startPoint: .top,
                endPoint: .center
            )
        )
        .overlay(alignment: .top) {
            ConfettiBurst(trigger: app.confettiTrigger)
                .offset(y: 90)
        }
        .overlay(alignment: .bottom) {
            if let toast = app.toast {
                ToastView(text: toast.text)
                    .padding(.bottom, 46)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.2), value: app.toast)
        .animation(.easeOut(duration: 0.15), value: app.selectedTab)
        .onExitCommand {
            app.closePopover()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ticFocusTodoInput)) { _ in
            app.selectedTab = .todos
            app.focusInputNonce += 1
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Palette.accent, Palette.accent.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)
            .shadow(color: Palette.accent.opacity(0.25), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 1) {
                Text("Tic")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(statusLine)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button {
                app.openMainWindow(tab: app.selectedTab)
            } label: {
                Image(systemName: "rectangle.inset.filled")
            }
            .buttonStyle(IconButtonStyle())
            .keyboardShortcut("o", modifiers: .command)
            .help("Open the full window (⌘O)")

            Button {
                app.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(IconButtonStyle())
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 9)
    }

    private var statusLine: String {
        if app.focus.isRunning, let remaining = app.focus.remaining(at: Date()) {
            return "Focus · \(TicFormat.clock(remaining)) left"
        }
        if app.focus.justFinished {
            return "Focus complete · nice work"
        }
        return "\(app.remainingTodoCount) left · \(app.clipboard.count) copied"
    }

    private var footer: some View {
        HStack(spacing: 9) {
            switch app.selectedTab {
            case .todos:
                hint("↑↓", "move")
                hint("space", "done")
                hint("return", "edit")
                hint("⌘D", "date")
            case .clipboard:
                hint("↑↓", "move")
                hint("space", "preview")
                hint("return", "copy")
                hint("delete", "remove")
            case .focus:
                hint("return", "start")
                hint("⇧⌘F", "from anywhere")
            }
            Spacer()
            if app.settings.clipboardPaused {
                Text("clipboard paused")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Palette.accent)
            } else {
                Text(app.selectedTab == .focus ? "no shortcut ends a session" : "⌃⌥⌘T anywhere")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 29)
        .background(Palette.hairline.opacity(0.5))
        .overlay(alignment: .top) {
            ThinDivider()
        }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            KeyCap(text: key)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Full window

struct FullWindowView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 1)
            content
        }
        .frame(minWidth: 820, minHeight: 600)
        .background(Palette.canvas)
        .overlay(alignment: .bottom) {
            if let toast = app.toast {
                ToastView(text: toast.text)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            ConfettiBurst(trigger: app.confettiTrigger)
                .offset(y: 120)
        }
        .animation(.easeOut(duration: 0.2), value: app.toast)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Palette.accent, Palette.accent.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Tic")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("One icon. Three tools.")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 36)
            .padding(.bottom, 22)

            VStack(spacing: 3) {
                navButton(.todos, count: app.remainingTodoCount)
                navButton(.clipboard, count: app.clipboard.count)
                navButton(.focus, count: nil)
            }
            .padding(.horizontal, 10)

            if app.focus.isRunning {
                focusCard
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    KeyCap(text: "⌃⌥⌘T")
                    Text("anywhere")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Button {
                    app.openSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11, weight: .medium))
                        Text("Settings")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("⌘,")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Palette.selection.opacity(0.6))
                )

                Text("Tic 1.0 · No account, no cloud")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 18)
        }
        .frame(width: 216)
        .background(.ultraThinMaterial)
    }

    private func navButton(_ tab: TicTab, count: Int?) -> some View {
        Button {
            app.selectedTab = tab
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)
                Text(tab.title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                }
                if tab == .focus && app.focus.isRunning {
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 5, height: 5)
                }
            }
            .foregroundStyle(app.selectedTab == tab ? Color.primary : Color.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(app.selectedTab == tab ? Palette.cardStrong : Color.clear)
                    .shadow(color: .black.opacity(app.selectedTab == tab ? 0.05 : 0), radius: 2, y: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character(String((TicTab.allCases.firstIndex(of: tab) ?? 0) + 1))), modifiers: .command)
    }

    private var focusCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = app.focus.remaining(at: context.date) ?? 0
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text("FOCUS")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .tracking(0.7)
                    Spacer()
                }
                .foregroundStyle(Palette.accent)
                Text(TicFormat.clock(remaining))
                    .font(.system(size: 19, weight: .light, design: .rounded))
                    .monospacedDigit()
                Text(focusModeLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.accent.opacity(0.075))
            )
        }
    }

    private var focusModeLabel: String {
        guard app.settings.focusDNDEnabled else { return "Focus mode off" }
        switch app.dndStatus {
        case .on: return "Do Not Disturb on"
        case .working: return "Turning on Focus…"
        case .failed: return "Focus shortcut needed"
        case .off, .unknown: return "Do Not Disturb off"
        }
    }

    @ViewBuilder
    private var content: some View {        switch app.selectedTab {
        case .todos:
            TodosView(wide: true)
        case .clipboard:
            ClipboardView(wide: true)
        case .focus:
            FocusView(wide: true)
        }
    }
}
