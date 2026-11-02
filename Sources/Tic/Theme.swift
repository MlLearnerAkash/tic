import SwiftUI
import AppKit

enum Palette {
    static let accent = Color(red: 0.93, green: 0.36, blue: 0.16)
    static let accentSoft = Color(red: 0.99, green: 0.72, blue: 0.52)
    static let teal = Color(red: 0.11, green: 0.55, blue: 0.51)
    static let pink = Color(red: 0.91, green: 0.35, blue: 0.49)
    static let gold = Color(red: 0.95, green: 0.68, blue: 0.15)
    static let blue = Color(red: 0.22, green: 0.48, blue: 0.91)
    static let violet = Color(red: 0.52, green: 0.36, blue: 0.88)

    static let canvas = Color(nsColor: NSColor(name: nil) { appearance in
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return dark
            ? NSColor(calibratedRed: 0.105, green: 0.102, blue: 0.098, alpha: 1)
            : NSColor(calibratedRed: 0.976, green: 0.965, blue: 0.94, alpha: 1)
    })

    static let card = Color(nsColor: NSColor(name: nil) { appearance in
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return dark
            ? NSColor(calibratedWhite: 1, alpha: 0.055)
            : NSColor(calibratedWhite: 1, alpha: 0.72)
    })

    static let cardStrong = Color(nsColor: NSColor(name: nil) { appearance in
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return dark
            ? NSColor(calibratedWhite: 1, alpha: 0.09)
            : NSColor(calibratedWhite: 1, alpha: 0.95)
    })

    static let hairline = Color.primary.opacity(0.09)
    static let selection = Color.primary.opacity(0.055)
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 12
    var radius: CGFloat = 14
    var strong: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(strong ? Palette.cardStrong : Palette.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func ticCard(padding: CGFloat = 12, radius: CGFloat = 14, strong: Bool = false) -> some View {
        modifier(CardBackground(padding: padding, radius: radius, strong: strong))
    }

    func ticTooltip(_ text: String) -> some View {
        help(text)
    }
}

struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    var radius: CGFloat = 9

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(hovering ? Palette.selection : Color.clear)
            )
            .onHover { hovering = $0 }
    }
}

struct SoftButtonStyle: ButtonStyle {
    var filled: Bool = false
    var tint: Color = Palette.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(filled ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(filled ? tint : Palette.selection)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed ? Palette.selection : Color.clear)
            )
            .contentShape(Rectangle())
    }
}

struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(Palette.selection)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    )
            )
    }
}

struct TicTabBar: View {
    @Binding var selection: TicTab
    var todoCount: Int
    var clipCount: Int
    var focusActive: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(TicTab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11.5, weight: .semibold))
                        badge(for: tab)
                    }
                    .foregroundStyle(selection == tab ? Color.primary : Color.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(selection == tab ? Palette.cardStrong : Color.clear)
                            .shadow(color: .black.opacity(selection == tab ? 0.06 : 0), radius: 3, y: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character(String(tabIndex(tab) + 1))), modifiers: .command)
                .help("\(tab.title) (⌘\(tabIndex(tab) + 1))")
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Palette.selection)
        )
    }

    private func tabIndex(_ tab: TicTab) -> Int {
        TicTab.allCases.firstIndex(of: tab) ?? 0
    }

    @ViewBuilder
    private func badge(for tab: TicTab) -> some View {
        let value: Int? = {
            switch tab {
            case .todos: return todoCount > 0 ? todoCount : nil
            case .clipboard: return clipCount > 0 ? clipCount : nil
            case .focus: return nil
            }
        }()

        if tab == .focus && focusActive {
            Circle()
                .fill(Palette.accent)
                .frame(width: 5, height: 5)
        } else if let value {
            Text("\(value)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(selection == tab ? Color.secondary : Color.secondary.opacity(0.8))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(Color.primary.opacity(0.07))
                )
        }
    }
}

struct SectionLabel: View {
    let title: String
    var count: Int? = nil
    var accent: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(accent ?? .secondary)
            if let count {
                Text("\(count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }
}

struct ThinDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 1)
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color.black.opacity(0.82))
            )
            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 230)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}

struct ConfettiBurst: View {
    let trigger: Int
    @State private var particles: [ConfettiParticle] = []
    @State private var animate = false

    private struct ConfettiParticle: Identifiable {
        let id = UUID()
        let color: Color
        let dx: CGFloat
        let dy: CGFloat
        let rotation: Double
        let scale: CGFloat
        let delay: Double
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(particle.color)
                    .frame(width: 5, height: 9)
                    .rotationEffect(.degrees(animate ? particle.rotation : 0))
                    .scaleEffect(animate ? particle.scale : 0.4)
                    .offset(x: animate ? particle.dx : 0, y: animate ? particle.dy : 0)
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.15).delay(particle.delay),
                        value: animate
                    )
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, newValue in
            guard newValue > 0 else { return }
            fire()
        }
    }

    private func fire() {
        let colors: [Color] = [Palette.accent, Palette.gold, Palette.teal, Palette.pink, Palette.blue, Palette.violet]
        particles = (0..<28).map { _ in
            let angle = Double.random(in: -0.95 * .pi ... -0.05 * .pi)
            let distance = CGFloat.random(in: 45...130)
            return ConfettiParticle(
                color: colors.randomElement() ?? Palette.accent,
                dx: CGFloat(cos(angle)) * distance,
                dy: CGFloat(sin(angle)) * distance + CGFloat.random(in: 18...42),
                rotation: Double.random(in: -240...240),
                scale: CGFloat.random(in: 0.6...1.1),
                delay: Double.random(in: 0...0.08)
            )
        }
        animate = false
        DispatchQueue.main.async {
            animate = true
        }
    }
}

struct FocusRing: View {
    let progress: Double
    let remaining: TimeInterval
    let isRunning: Bool
    let isComplete: Bool
    var size: CGFloat = 190

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.07), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    AngularGradient(
                        colors: isComplete
                            ? [Palette.teal, Palette.teal]
                            : [Palette.accent, Palette.gold, Palette.accent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)

            VStack(spacing: 4) {
                Text(isComplete ? "Done" : TicFormat.clock(remaining))
                    .font(.system(size: size > 180 ? 38 : 32, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(isComplete ? "Nice work" : (isRunning ? "in focus" : "ready"))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
