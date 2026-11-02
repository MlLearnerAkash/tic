import SwiftUI
import AppKit

struct TodosView: View {
    @EnvironmentObject private var app: AppState
    var wide: Bool = false

    @State private var draft = ""
    @State private var draftDate: Date?
    @State private var showCalendar = false
    @State private var selectedID: UUID?
    @State private var editingID: UUID?
    @State private var editingText = ""

    @FocusState private var addFocused: Bool
    @FocusState private var listFocused: Bool
    @FocusState private var editFocused: Bool

    private var textSize: CGFloat { wide ? 13.5 : 12.5 }
    private var rowHeight: CGFloat { wide ? 38 : 33 }

    var body: some View {
        VStack(spacing: wide ? 12 : 9) {
            addBar
            list
        }
        .frame(maxWidth: wide ? 760 : .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, wide ? 22 : 12)
        .padding(.top, wide ? 14 : 2)
        .padding(.bottom, wide ? 14 : 6)
        .onAppear {
            if !wide {
                DispatchQueue.main.async { addFocused = true }
            }
        }
        .onChange(of: app.focusInputNonce) { _, _ in
            app.selectedTab = .todos
            DispatchQueue.main.async { addFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ticFocusAddField)) { _ in
            DispatchQueue.main.async { addFocused = true }
        }
    }

    // MARK: - Add bar

    private var addBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Palette.accent.opacity(0.11)))

                TextField("What needs doing?", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: textSize + 0.5, weight: .medium))
                    .focused($addFocused)
                    .onSubmit(addTodo)
                    .onKeyPress(.downArrow) {
                        moveSelection(down: true)
                        listFocused = true
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        moveSelection(down: false)
                        listFocused = true
                        return .handled
                    }

                if !draft.isEmpty {
                    Button(action: addTodo) {
                        Image(systemName: "return")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add (Return)")
                    .transition(.opacity)
                }

                Button {
                    showCalendar.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: draftDate == nil ? "calendar" : "calendar.badge.clock")
                            .font(.system(size: 11, weight: .medium))
                        if let draftDate {
                            Text(shortDate(draftDate))
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .foregroundStyle(draftDate == nil ? Color.secondary : Palette.accent)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("d", modifiers: .command)
                .help("Choose a day (⌘D)")
                .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
                    calendarPopover
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Palette.cardStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(addFocused ? Palette.accent.opacity(0.5) : Palette.hairline, lineWidth: 1)
                )
        )
        .animation(.easeOut(duration: 0.12), value: addFocused)
        .animation(.easeOut(duration: 0.12), value: draftDate)
    }

    private var calendarPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("When?")
                .font(.system(size: 12.5, weight: .bold))

            HStack(spacing: 6) {
                quickDateButton("Today", date: Calendar.current.startOfDay(for: Date()))
                quickDateButton("Tomorrow", date: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())))
                Button("Any day") { draftDate = nil }
                    .buttonStyle(SoftButtonStyle())
            }

            DatePicker(
                "",
                selection: Binding(
                    get: { draftDate ?? Date() },
                    set: { draftDate = Calendar.current.startOfDay(for: $0) }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(width: 250)

            HStack {
                Spacer()
                Button("Done") { showCalendar = false }
                    .buttonStyle(SoftButtonStyle(filled: true))
            }
        }
        .padding(14)
        .frame(width: 286)
    }

    private func quickDateButton(_ title: String, date: Date?) -> some View {
        Button(title) {
            draftDate = date
        }
        .buttonStyle(SoftButtonStyle(filled: draftDate == date && date != nil))
    }

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func addTodo() {
        let title = draft
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        app.addTodo(title: title, dueDate: draftDate)
        draft = ""
        if let newID = app.todos.last?.id {
            selectedID = newID
        }
        addFocused = true
    }

    // MARK: - List

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: wide ? 7 : 5, pinnedViews: []) {
                    ForEach(app.todoSections) { section in
                        sectionView(section)
                            .id(section.id)
                    }

                    if app.todos.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.dashed")
                                .font(.system(size: 28, weight: .ultraLight))
                                .foregroundStyle(.tertiary)
                            Text("Nothing on your plate.")
                                .font(.system(size: 12.5, weight: .semibold))
                            Text("Type above and press Return. It lands on today.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 34)
                    }

                    if !app.todos.isEmpty {
                        HStack {
                            Text("\(app.remainingTodoCount) left")
                            Text("·")
                            Text("\(app.completedTodoCount) done")
                            Spacer()
                            if app.completedTodoCount > 0 {
                                Button("Clear done") { app.clearCompletedTodos() }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .focusable()
            .focused($listFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) {
                moveSelection(down: false)
                return .handled
            }
            .onKeyPress(.downArrow) {
                moveSelection(down: true)
                return .handled
            }
            .onKeyPress(.space) {
                guard let selectedID else { return .ignored }
                app.toggleTodo(selectedID)
                return .handled
            }
            .onKeyPress(.return) {
                guard let selectedID else { return .ignored }
                beginEditing(selectedID)
                return .handled
            }
            .onKeyPress(.delete) {
                guard let selectedID else { return .ignored }
                app.deleteTodo(selectedID)
                self.selectedID = nextSelection(after: selectedID)
                return .handled
            }
            .onKeyPress(.escape) {
                addFocused = true
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

    @ViewBuilder
    private func sectionView(_ section: TodoSection) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                SectionLabel(
                    title: section.title,
                    count: section.items.isEmpty ? nil : section.items.count,
                    accent: section.isOverdue ? Palette.pink : nil
                )
                if section.id == "today" && section.items.isEmpty {
                    Text("All clear")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 5)
            .padding(.top, section.id == "today" ? 2 : 8)
            .padding(.bottom, 1)
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { items, _ in
                guard section.id != "overdue",
                      let value = items.first,
                      let id = UUID(uuidString: value),
                      let bucket = section.bucketDate else { return false }
                app.moveTodo(id, above: nil, inBucket: bucket)
                return true
            }

            if section.items.isEmpty && section.id == "today" {
                Text("Type above to add the first thing.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
            }

            ForEach(section.items) { todo in
                todoRow(todo, in: section)
                    .id(todo.id)
            }
        }
    }

    @ViewBuilder
    private func todoRow(_ todo: TodoItem, in section: TodoSection) -> some View {
        TodoRow(
            todo: todo,
            wide: wide,
            rowHeight: rowHeight,
            isSelected: selectedID == todo.id,
            isEditing: editingID == todo.id,
            editingText: $editingText,
            editFocused: $editFocused,
            onSelect: {
                selectedID = todo.id
                listFocused = true
            },
            onToggle: {
                app.toggleTodo(todo.id)
                selectedID = todo.id
            },
            onBeginEdit: { beginEditing(todo.id) },
            onCommitEdit: {
                app.updateTodoTitle(todo.id, title: editingText)
                editingID = nil
                listFocused = true
            },
            onCancelEdit: {
                editingID = nil
                listFocused = true
            },
            onDelete: {
                app.deleteTodo(todo.id)
                selectedID = nextSelection(after: todo.id)
            }
        )
        .dropDestination(for: String.self) { items, _ in
            guard section.id != "overdue",
                  let value = items.first,
                  let dragged = UUID(uuidString: value),
                  dragged != todo.id,
                  let bucket = section.bucketDate else { return false }
            app.moveTodo(dragged, above: todo.id, inBucket: bucket)
            selectedID = dragged
            return true
        }
    }

    // MARK: - Selection and editing

    private func moveSelection(down: Bool) {
        let ids = app.flatTodoIDs
        guard !ids.isEmpty else { return }
        guard let selectedID, let index = ids.firstIndex(of: selectedID) else {
            self.selectedID = down ? ids.first : ids.last
            return
        }
        let next = down ? min(index + 1, ids.count - 1) : max(index - 1, 0)
        self.selectedID = ids[next]
    }

    private func nextSelection(after id: UUID) -> UUID? {
        let ids = app.flatTodoIDs
        guard let index = ids.firstIndex(of: id) else { return ids.first }
        if index < ids.count - 1 { return ids[index + 1] }
        if index > 0 { return ids[index - 1] }
        return nil
    }

    private func beginEditing(_ id: UUID) {
        guard let todo = app.todos.first(where: { $0.id == id }) else { return }
        editingText = todo.title
        editingID = id
        selectedID = id
        DispatchQueue.main.async { editFocused = true }
    }
}

private struct TodoRow: View {
    let todo: TodoItem
    let wide: Bool
    let rowHeight: CGFloat
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingText: String
    var editFocused: FocusState<Bool>.Binding

    let onSelect: () -> Void
    let onToggle: () -> Void
    let onBeginEdit: () -> Void
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 9) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(todo.isCompleted ? Palette.accent : Color.primary.opacity(0.26), lineWidth: 1.4)
                        .frame(width: 17, height: 17)
                    if todo.isCompleted {
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: 17, height: 17)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(todo.isCompleted ? "Mark incomplete (Space)" : "Complete (Space)")

            if isEditing {
                TextField("", text: $editingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: wide ? 13.5 : 12.5, weight: .medium))
                    .focused(editFocused)
                    .onSubmit(onCommitEdit)
                    .onExitCommand(perform: onCancelEdit)
                    .onAppear {
                        DispatchQueue.main.async { editFocused.wrappedValue = true }
                    }
            } else {
                Text(todo.title)
                    .font(.system(size: wide ? 13.5 : 12.5, weight: .medium))
                    .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(todo.isCompleted, color: .secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { onToggle() }
                    .onTapGesture { onSelect() }
            }

            if !isEditing {
                if let due = todo.dueDate, !Calendar.current.isDateInToday(due) {
                    Text(TicFormat.shortDay(due))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                if hovering {
                    Button(action: onBeginEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit (Return)")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }
        }
        .padding(.horizontal, 9)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Palette.selection : (hovering ? Palette.selection.opacity(0.55) : Color.clear))
        )
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Palette.accent)
                    .frame(width: 2, height: rowHeight - 14)
                    .offset(x: -3)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { onSelect() }
        .draggable(todo.id.uuidString) {
            Text(todo.title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.cardStrong))
        }
    }
}
