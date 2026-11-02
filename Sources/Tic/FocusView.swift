import SwiftUI
import AppKit

struct FocusView: View {
    @EnvironmentObject private var app: AppState
    var wide: Bool = false

    @State private var showEndConfirm = false
    @State private var showCustom = false
    @State private var customHours = 0
    @State private var customMinutes = 30

    private let presets: [TimeInterval] = [25 * 60, 50 * 60, 90 * 60]
    private var ringSize: CGFloat { wide ? 236 : 178 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(at: context.date)
        }
        .padding(.horizontal, wide ? 30 : 12)
        .padding(.top, wide ? 18 : 2)
        .padding(.bottom, wide ? 18 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("End this focus session?", isPresented: $showEndConfirm) {
            Button("End session", role: .destructive) {
                app.endFocus()
            }
            Button("Keep focusing", role: .cancel) {}
        } message: {
            Text("Ending is deliberate — there is no keyboard shortcut for it.")
        }
    }

    @ViewBuilder
    private func content(at now: Date) -> some View {
        let running = app.focus.isRunning
        let complete = app.focus.justFinished
        let remaining = app.focus.remaining(at: now) ?? (complete ? 0 : app.focus.duration)
        let progress = running
            ? max(0, min(1, 1 - remaining / max(1, app.focus.duration)))
            : (complete ? 1 : 0)

        VStack(spacing: wide ? 22 : 12) {
            HStack {
                SectionLabel(title: "Focus", count: nil)
                Spacer()
                dndPill(running: running)
            }
            .frame(maxWidth: wide ? 760 : .infinity)

            if wide {
                HStack(spacing: 40) {
                    ring(progress: progress, remaining: remaining, running: running, complete: complete)
                        .frame(maxWidth: .infinity)
                    controls(running: running, complete: complete)
                        .frame(maxWidth: 330)
                }
                .frame(maxWidth: 760)
            } else {
                Spacer(minLength: 0)
                ring(progress: progress, remaining: remaining, running: running, complete: complete)
                controls(running: running, complete: complete)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ring(progress: Double, remaining: TimeInterval, running: Bool, complete: Bool) -> some View {
        VStack(spacing: 12) {
            FocusRing(
                progress: progress,
                remaining: remaining,
                isRunning: running,
                isComplete: complete,
                size: ringSize
            )

            if running, let end = app.focus.endDate {
                Text("Ends at \(timeString(end))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if complete {
                if let finished = app.focus.lastFinishedAt {
                    Text("Finished at \(timeString(finished))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(TicFormat.durationLabel(app.focus.duration))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func controls(running: Bool, complete: Bool) -> some View {
        if running {
            VStack(spacing: 12) {
                Text("One thing at a time.")
                    .font(.system(size: wide ? 17 : 14, weight: .semibold, design: .rounded))

                Text("The countdown is in your menu bar. Tic keeps time through sleep, quitting and restarts.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 290)

                Button {
                    showEndConfirm = true
                } label: {
                    Text("End session")
                        .frame(maxWidth: 170)
                }
                .buttonStyle(SoftButtonStyle())

                Text("No shortcut can end it.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
        } else if complete {
            VStack(spacing: 10) {
                Text("That’s done.")
                    .font(.system(size: wide ? 19 : 15, weight: .semibold, design: .rounded))
                Text("The chime played and Focus mode was turned back off.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    Button {
                        app.dismissFocusCompletion()
                        app.startFocus()
                    } label: {
                        Text("Start another")
                            .frame(maxWidth: 140)
                    }
                    .buttonStyle(SoftButtonStyle(filled: true))

                    Button("Dismiss") {
                        app.dismissFocusCompletion()
                    }
                    .buttonStyle(SoftButtonStyle())
                }
            }
        } else {
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            app.setFocusDuration(preset)
                        } label: {
                            Text(presetLabel(preset))
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(abs(app.focus.duration - preset) < 1 ? Palette.accent : Palette.selection)
                                )
                                .foregroundStyle(abs(app.focus.duration - preset) < 1 ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        customHours = Int(app.focus.duration) / 3600
                        customMinutes = (Int(app.focus.duration) % 3600) / 60
                        showCustom.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Palette.selection)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Custom length (up to 24 hours)")
                    .popover(isPresented: $showCustom, arrowEdge: .bottom) {
                        customPopover
                    }
                }

                Button {
                    app.startFocus()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Start focus")
                        KeyCap(text: "↩")
                    }
                    .frame(maxWidth: 190)
                }
                .buttonStyle(SoftButtonStyle(filled: true))
                .keyboardShortcut(.defaultAction)
                .disabled(running)

                VStack(spacing: 4) {
                    Text(shortcutHint)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                    Text("Do Not Disturb turns on and off through Shortcuts.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var shortcutHint: String {
        if !app.hotkeysRegistered {
            return "Global shortcuts are unavailable. Open Focus with ⌘3."
        }
        if app.settings.focusDNDEnabled {
            return "⇧⌘F opens this from anywhere."
        }
        return "⇧⌘F opens this from anywhere. Focus mode is off."
    }

    private var customPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Any length")
                .font(.system(size: 12.5, weight: .bold))
            Text("From one minute to 24 hours.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            HStack {
                Stepper("\(customHours) hr", value: $customHours, in: 0...24)
                    .font(.system(size: 11))
                Stepper("\(customMinutes) min", value: $customMinutes, in: 0...59)
                    .font(.system(size: 11))
            }

            Text(TicFormat.durationLabel(max(60, Double(customHours * 3600 + customMinutes * 60))))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.accent)

            HStack {
                Spacer()
                Button("Set") {
                    let total = Double(customHours * 3600 + customMinutes * 60)
                    app.setFocusDuration(max(60, min(total, 24 * 3600)))
                    showCustom = false
                }
                .buttonStyle(SoftButtonStyle(filled: true))
            }
        }
        .padding(14)
        .frame(width: 250)
    }

    @ViewBuilder
    private func dndPill(running: Bool) -> some View {
        let (text, icon, color): (String, String, Color) = {
            if !app.settings.focusDNDEnabled {
                return ("Focus mode off", "moon", Color.secondary)
            }
            switch app.dndStatus {
            case .on:
                return ("Do Not Disturb on", "moon.fill", Palette.teal)
            case .working:
                return ("Turning on Focus…", "moon", Color.secondary)
            case .failed:
                return ("Shortcut needed", "exclamationmark.triangle", Palette.gold)
            case .off, .unknown:
                return (running ? "Do Not Disturb off" : "Via Shortcuts", "moon", Color.secondary)
            }
        }()

        Button {
            app.openSettings()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .bold))
                Text(text)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .help("Focus mode settings")
    }

    private func presetLabel(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }
        return "\(minutes)m"
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}
