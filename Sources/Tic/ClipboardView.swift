import SwiftUI
import AppKit

struct ClipboardView: View {
    @EnvironmentObject private var app: AppState
    var wide: Bool = false

    @State private var search = ""
    @State private var selectedID: UUID?
    @State private var showPreview = false
    @State private var confirmErase = false
    @State private var hoveringRow: UUID?

    @FocusState private var searchFocused: Bool
    @FocusState private var listFocused: Bool

    private var items: [ClipboardItem] { app.filteredClips(query: search) }
    private var selectedItem: ClipboardItem? {
        items.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 8) {
            toolbar
            if app.settings.clipboardPaused {
                pausedBanner
            }
            if wide {
                HStack(spacing: 0) {
                    listPane
                    ThinDivider().frame(width: 1)
                    detailPane
                        .frame(width: 330)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Palette.hairline, lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ZStack {
                    listPane
                    if showPreview, let selectedItem {
                        previewOverlay(selectedItem)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(2)
                    }
                }
            }
        }
        .padding(.horizontal, wide ? 22 : 12)
        .padding(.top, wide ? 14 : 2)
        .padding(.bottom, wide ? 14 : 8)
        .frame(maxWidth: wide ? 980 : .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: items.count) { _, _ in
            if let selectedID, !items.contains(where: { $0.id == selectedID }) {
                self.selectedID = items.first?.id
            }
        }
        .onAppear {
            if selectedID == nil { selectedID = items.first?.id }
            DispatchQueue.main.async { listFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ticFocusSearch)) { _ in
            DispatchQueue.main.async { searchFocused = true }
        }
        .confirmationDialog(
            "Erase all clipboard history?",
            isPresented: $confirmErase
        ) {
            Button("Erase everything", role: .destructive) {
                app.clearClips(.everything)
                selectedID = nil
                showPreview = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Todos are not touched. This cannot be undone.")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                    TextField("Search everything you copied", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($searchFocused)
                        .onKeyPress(.downArrow) {
                            listFocused = true
                            return .handled
                        }
                    if !search.isEmpty {
                        Button {
                            search = ""
                            searchFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Palette.cardStrong)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(searchFocused ? Palette.accent.opacity(0.45) : Palette.hairline, lineWidth: 1)
                        )
                )

                Button {
                    app.setClipboardPaused(!app.settings.clipboardPaused)
                } label: {
                    Image(systemName: app.settings.clipboardPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(app.settings.clipboardPaused ? Palette.accent : Color.secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(app.settings.clipboardPaused ? Palette.accent.opacity(0.12) : Palette.selection)
                        )
                }
                .buttonStyle(.plain)
                .help(app.settings.clipboardPaused ? "Resume recording" : "Pause recording")

                Menu {
                    Button("Clear today") { app.clearClips(.today) }
                    Button("Clear last 7 days") { app.clearClips(.week) }
                    Button("Clear last 30 days") { app.clearClips(.month) }
                    Divider()
                    Button("Clear everything…", role: .destructive) { confirmErase = true }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Palette.selection)
                        )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 26)
                .help("Clear clipboard history")
            }
            HStack {
                SectionLabel(title: search.isEmpty ? "Everything you copied" : "Results", count: items.count)
                Spacer()
                if app.settings.clipboardPaused {
                    Text("PAUSED")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(Palette.accent)
                }
            }
            .padding(.horizontal, 3)
        }
        .background(
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
    }

    private var pausedBanner: some View {
        HStack(spacing: 7) {
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(Palette.accent)
            Text("Recording is paused. New copies won’t be saved.")
                .font(.system(size: 10.5, weight: .medium))
            Spacer()
            Button("Resume") { app.setClipboardPaused(false) }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Palette.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Palette.accent.opacity(0.09))
        )
    }

    // MARK: - List

    private var listPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if items.isEmpty {
                        EmptyState(
                            icon: search.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
                            title: search.isEmpty ? "Nothing copied yet" : "No matches",
                            message: search.isEmpty
                                ? "Copy text, links, code, images or files. They’ll show up here, kept until you clear them."
                                : "Try a different word, app name, or a kind like “images”."
                        )
                        .padding(.top, wide ? 60 : 36)
                    } else {
                        ForEach(items) { item in
                            ClipboardRow(
                                item: item,
                                isSelected: selectedID == item.id,
                                isHovering: hoveringRow == item.id,
                                wide: wide,
                                onSelect: {
                                    selectedID = item.id
                                    listFocused = true
                                    if wide { showPreview = true }
                                },
                                onCopy: {
                                    app.copyClipBack(item, closePopover: !wide)
                                    if wide { selectedID = item.id }
                                },
                                onDelete: {
                                    app.deleteClip(item.id)
                                    selectedID = nextSelection(after: item.id)
                                }
                            )
                            .id(item.id)
                            .onHover { hoveringRow = $0 ? item.id : (hoveringRow == item.id ? nil : hoveringRow) }
                        }
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .focusable()
            .focused($listFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) { moveSelection(up: true); return .handled }
            .onKeyPress(.downArrow) { moveSelection(up: false); return .handled }
            .onKeyPress(.space) {
                guard selectedItem != nil else { return .ignored }
                if wide { showPreview = true } else { showPreview.toggle() }
                return .handled
            }
            .onKeyPress(.return) {
                guard let selectedItem else { return .ignored }
                app.copyClipBack(selectedItem, closePopover: !wide)
                return .handled
            }
            .onKeyPress(.delete) {
                guard let selectedID else { return .ignored }
                app.deleteClip(selectedID)
                self.selectedID = nextSelection(after: selectedID)
                return .handled
            }
            .onKeyPress(.escape) {
                if showPreview {
                    showPreview = false
                } else {
                    searchFocused = true
                }
                return .handled
            }
            .onChange(of: selectedID) { _, newValue in
                if let newValue {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }

    private func moveSelection(up: Bool) {
        guard !items.isEmpty else { return }
        guard let selectedID, let index = items.firstIndex(where: { $0.id == selectedID }) else {
            self.selectedID = up ? items.last?.id : items.first?.id
            return
        }
        let next = up ? max(0, index - 1) : min(items.count - 1, index + 1)
        self.selectedID = items[next].id
    }

    private func nextSelection(after id: UUID) -> UUID? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return items.first?.id }
        if index < items.count - 1 { return items[index + 1].id }
        if index > 0 { return items[index - 1].id }
        return nil
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let selectedItem {
            ClipboardDetail(item: selectedItem, wide: true) {
                app.copyClipBack(selectedItem, closePopover: false)
            } onDelete: {
                app.deleteClip(selectedItem.id)
                self.selectedID = nextSelection(after: selectedItem.id)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 24, weight: .ultraLight))
                    .foregroundStyle(.tertiary)
                Text("Select something to preview")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func previewOverlay(_ item: ClipboardItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "eye")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Preview")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showPreview = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Palette.selection))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            ThinDivider()

            ClipboardDetail(item: item, wide: false) {
                app.copyClipBack(item, closePopover: true)
            } onDelete: {
                app.deleteClip(item.id)
                selectedID = nextSelection(after: item.id)
                showPreview = false
            }
        }
        .background(Palette.canvas)
    }
}

// MARK: - Row

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isHovering: Bool
    let wide: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            leading

            VStack(alignment: .leading, spacing: 2.5) {
                Text(previewText)
                    .font(.system(size: wide ? 12.5 : 11.5, weight: .medium, design: item.kind == .code ? .monospaced : .default))
                    .foregroundStyle(.primary)
                    .lineLimit(item.kind == .code ? 2 : 2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 5) {
                    Text(item.kind.label)
                        .foregroundStyle(kindColor.opacity(0.9))
                    Text("·")
                    Text(item.sourceApp)
                    Text("·")
                    Text(TicFormat.relative(item.createdAt))
                    if item.copyCount > 1 {
                        Text("· \(item.copyCount)×")
                    }
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }

            if isHovering || isSelected {
                HStack(spacing: 2) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .buttonStyle(IconButtonStyle())
                    .help("Copy back (Return)")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .buttonStyle(IconButtonStyle())
                    .help("Delete")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Palette.selection : (isHovering ? Palette.selection.opacity(0.5) : Color.clear))
        )
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Palette.accent)
                    .frame(width: 2, height: 28)
                    .offset(x: -3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onCopy() }
        .onTapGesture { onSelect() }
    }

    @ViewBuilder
    private var leading: some View {
        if item.kind == .image, let name = item.imageFileName, let image = ThumbnailCache.shared.image(named: name) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                )
        } else {
            Image(systemName: item.kind.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(kindColor)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(kindColor.opacity(0.1))
                )
        }
    }

    private var previewText: String {
        let text = item.displayText.replacingOccurrences(of: "\n", with: "  ")
        return text.isEmpty ? item.kind.label : text
    }

    private var kindColor: Color {
        switch item.kind {
        case .text: return .secondary
        case .link: return Palette.blue
        case .code: return Palette.violet
        case .image: return Palette.teal
        case .file: return Palette.gold
        }
    }
}

// MARK: - Detail pane

private struct ClipboardDetail: View {
    let item: ClipboardItem
    let wide: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    metadata

                    ThinDivider()

                    content
                }
                .padding(14)
            }
            .scrollIndicators(.hidden)

            ThinDivider()

            HStack(spacing: 7) {
                Button(action: onCopy) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy back")
                        KeyCap(text: "↩")
                    }
                }
                .buttonStyle(SoftButtonStyle(filled: true))

                if item.kind == .link, let text = item.text, let url = URL(string: text) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "arrow.up.right")
                    }
                    .buttonStyle(SoftButtonStyle())
                    .help("Open link")
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(SoftButtonStyle())
                .help("Delete")
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.kind.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(kindColor)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(kindColor.opacity(0.11)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.kind.label)
                        .font(.system(size: 12, weight: .semibold))
                    Text("Copied from \(item.sourceApp)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Label(TicFormat.relative(item.createdAt), systemImage: "clock")
                if item.byteSize > 0 {
                    Label(TicFormat.bytes(item.byteSize), systemImage: "internaldrive")
                }
                if item.copyCount > 1 {
                    Label("\(item.copyCount)×", systemImage: "arrow.2.squarepath")
                }
            }
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .image:
            if let name = item.imageFileName, let image = ThumbnailCache.shared.image(named: name) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Text("Image unavailable")
                    .foregroundStyle(.secondary)
            }

        case .file:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(item.filePaths, id: \.self) { path in
                    HStack(spacing: 7) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                            .resizable()
                            .frame(width: 18, height: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text((path as NSString).lastPathComponent)
                                .font(.system(size: 11, weight: .medium))
                            Text(path)
                                .font(.system(size: 9.5))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }

        default:
            Text(item.text ?? "")
                .font(.system(size: item.kind == .code ? 11.5 : 12.5, design: item.kind == .code ? .monospaced : .default))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var kindColor: Color {
        switch item.kind {
        case .text: return .secondary
        case .link: return Palette.blue
        case .code: return Palette.violet
        case .image: return Palette.teal
        case .file: return Palette.gold
        }
    }
}
