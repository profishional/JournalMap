//
//  JournalEntriesPage.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import SwiftUI
import CoreData

struct JournalEntriesPage: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: JournalViewModel
    @State private var zoomLevel: ZoomLevel = .normal
    @State private var editingEntryId: UUID?
    @State private var editingField: EditingField?
    @GestureState private var magnification: CGFloat = 1.0

    enum ZoomLevel {
        case normal
        case titlesWithPreview
        case titlesOnly
    }

    enum EditingField {
        case title
        case category
        case body
    }

    init(viewContext: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: JournalViewModel(viewContext: viewContext))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background to detect taps outside cards
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Cancel editing when tapping outside cards
                        if editingEntryId != nil {
                            editingEntryId = nil
                            editingField = nil
                        }
                    }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.entries) { entry in
                        if editingEntryId == entry.id {
                            // Inline editable entry
                            EditableEntryCard(
                                entry: entry,
                                zoomLevel: zoomLevel,
                                editingField: $editingField,
                                viewModel: viewModel,
                                onSave: { updatedEntry in
                                    saveEntry(updatedEntry)
                                    editingEntryId = nil
                                    editingField = nil
                                },
                                onCancel: {
                                    // If this is a new entry with empty title, remove it
                                    if let entryId = editingEntryId,
                                       let entry = viewModel.entries.first(where: { $0.id == entryId }),
                                       entry.title.isEmpty {
                                        if let index = viewModel.entries.firstIndex(where: { $0.id == entryId }) {
                                            viewModel.entries.remove(at: index)
                                        }
                                    }
                                    editingEntryId = nil
                                    editingField = nil
                                },
                                onDelete: {
                                    deleteEntry(entry)
                                    editingEntryId = nil
                                    editingField = nil
                                }
                            )
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(Color(.systemGray5)),
                                alignment: .bottom
                            )
                        } else {
                            // Regular card with swipe to delete
                            SwipeableEntryCard(
                                entry: entry,
                                zoomLevel: zoomLevel,
                                onDoubleTap: {
                                    editingEntryId = entry.id
                                    editingField = .title
                                },
                                onDelete: {
                                    deleteEntry(entry)
                                }
                            )
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(Color(.systemGray5)),
                                alignment: .bottom
                            )
                        }
                    }
                }
                
                // Empty state
                if viewModel.entries.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                            .frame(height: 100)
                        
                        Image(systemName: "book.closed")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary.opacity(0.4))
                        
                        Text("No entries yet")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text("Tap + to create your first journal entry")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary.opacity(0.7))
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }

                // Floating plus button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                let newEntry = ParsedEntry(
                                    title: "",
                                    categories: [],
                                    body: "",
                                    timestamp: Date()
                                )
                                viewModel.entries.insert(newEntry, at: 0)
                                editingEntryId = newEntry.id
                                editingField = .title
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
        }
        .simultaneousGesture(
            MagnificationGesture()
                .updating($magnification) { currentState, gestureState, _ in
                    gestureState = currentState
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        switch zoomLevel {
                        case .normal:
                            // Pinch in (value < 1) goes to less detail
                            if value < 0.8 {
                                zoomLevel = .titlesWithPreview
                            }
                        case .titlesWithPreview:
                            // Pinch in more goes to titlesOnly, pinch out goes back to normal
                            if value < 0.8 {
                                zoomLevel = .titlesOnly
                            } else if value > 1.2 {
                                zoomLevel = .normal
                            }
                        case .titlesOnly:
                            // Pinch out goes back to titlesWithPreview
                            if value > 1.2 {
                                zoomLevel = .titlesWithPreview
                            }
                        }
                    }
                }
        )
    }

    private func saveEntry(_ entry: ParsedEntry) {
        // Don't save if title is empty
        guard !entry.title.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty else {
            // Remove empty entry if it exists
            if let index = viewModel.entries.firstIndex(where: { $0.id == entry.id }) {
                viewModel.entries.remove(at: index)
            }
            return
        }

        // Find existing entry by ID or add new one
        if let index = viewModel.entries.firstIndex(where: { $0.id == entry.id }) {
            // Preserve original timestamp for existing entries
            let originalTimestamp = viewModel.entries[index].timestamp
            viewModel.entries[index] = entry
            viewModel.entries[index].timestamp = originalTimestamp
        } else {
            // New entry - use current timestamp
            viewModel.entries.append(entry)
        }

        // Sort by descending timestamp (newest first)
        viewModel.entries.sort { $0.timestamp > $1.timestamp }

        // Rebuild raw text from entries
        rebuildRawText()
        viewModel.saveDocument(reparseEntries: false)
    }

    private func deleteEntry(_ entry: ParsedEntry) {
        // Remove from entries array
        if let index = viewModel.entries.firstIndex(where: { $0.id == entry.id }) {
            viewModel.entries.remove(at: index)
            // Rebuild raw text from remaining entries
            rebuildRawText()
            viewModel.saveDocument()
        }
    }

    private func rebuildRawText() {
        var text = ""
        // Entries are already in newest-to-oldest order (newest at index 0)
        for (index, entry) in viewModel.entries.enumerated() {
            if index > 0 {
                text += "\n\n"
            }
            text += entry.title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !entry.categories.isEmpty {
                text += "\n#" + entry.categories.joined(separator: ", #")
            }
            if !entry.body.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                text += "\n" + entry.body.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
        }
        viewModel.rawText = text
    }
}

struct SwipeableEntryCard: View {
    let entry: ParsedEntry
    let zoomLevel: JournalEntriesPage.ZoomLevel
    let onDoubleTap: () -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGFloat = 0
    private let deleteButtonWidth: CGFloat = 80

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background - always present but hidden
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    dragOffset = 0
                    onDelete()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20))
                    Text("Delete")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: deleteButtonWidth)
                .frame(maxHeight: .infinity)
                .background(Color.red)
            }
            .opacity(dragOffset < -10 ? 1 : 0)

            // Card content
            EntryCard(entry: entry, zoomLevel: zoomLevel, onDoubleTap: onDoubleTap)
                .background(Color(.systemBackground))
                .offset(x: dragOffset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            // Only allow left swipe (negative width)
                            if value.translation.width < 0 {
                                dragOffset = max(value.translation.width, -deleteButtonWidth)
                            } else if dragOffset < 0 {
                                // Allow dragging back to the right if already swiped
                                dragOffset = min(0, dragOffset + value.translation.width)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if value.translation.width < -deleteButtonWidth / 2 || dragOffset < -deleteButtonWidth / 2 {
                                    // Swiped far enough, show delete button
                                    dragOffset = -deleteButtonWidth
                                } else {
                                    // Not far enough, snap back
                                    dragOffset = 0
                                }
                            }
                        }
                )
        }
    }
}

struct EntryCard: View {
    let entry: ParsedEntry
    let zoomLevel: JournalEntriesPage.ZoomLevel
    let onDoubleTap: () -> Void

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private func firstFewWords(of text: String, maxWords: Int) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        if words.count <= maxWords {
            return text
        }
        return words.prefix(maxWords).joined(separator: " ") + "..."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title and timestamp row
            HStack(alignment: .firstTextBaseline) {
                Text(entry.title.isEmpty ? "Untitled" : entry.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(zoomLevel == .titlesOnly ? 2 : nil)

                Spacer()

                Text(formatTimestamp(entry.timestamp))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Categories as pills
            if !entry.categories.isEmpty && zoomLevel != .titlesOnly {
                HStack(spacing: 6) {
                    ForEach(Array(entry.categories.prefix(3)), id: \.self) { category in
                        Text("#\(category)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            // Body
            if zoomLevel == .normal && !entry.body.isEmpty {
                Text(entry.body)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .lineSpacing(2)
            } else if zoomLevel == .titlesWithPreview && !entry.body.isEmpty {
                Text(firstFewWords(of: entry.body, maxWords: 12))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
    }
}

struct EditableEntryCard: View {
    var entry: ParsedEntry
    let zoomLevel: JournalEntriesPage.ZoomLevel
    @Binding var editingField: JournalEntriesPage.EditingField?
    let viewModel: JournalViewModel
    let onSave: (ParsedEntry) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var titleText: String = ""
    @State private var categoriesText: String = ""
    @State private var bodyText: String = ""
    @State private var showCategoryAutocomplete = false
    @State private var categorySuggestions: [String] = []
    @FocusState private var focusedField: JournalEntriesPage.EditingField?

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title and timestamp row
            HStack(alignment: .firstTextBaseline) {
                TextField("Title", text: $titleText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .focused($focusedField, equals: .title)
                    .onSubmit {
                        if !titleText.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty {
                            editingField = .category
                            focusedField = .category
                        }
                    }

                Spacer()

                Text(formatTimestamp(entry.timestamp))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Categories line
            VStack(alignment: .leading, spacing: 4) {
                TextField("category1, category2, category3", text: $categoriesText)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .focused($focusedField, equals: .category)
                    .onSubmit {
                        // Check category count
                        let categoryCount = categoriesText.components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
                            .filter { !$0.isEmpty }
                            .count

                        // If less than 3 categories, return goes to body
                        if categoryCount <= 3 {
                            editingField = .body
                            focusedField = .body
                        }
                    }
                    .onChange(of: categoriesText) { oldValue, newValue in
                        // Only update autocomplete if we're in category field
                        if focusedField == .category {
                            updateCategoryAutocomplete(for: newValue)
                        }

                        // Auto-add "#" after comma
                        if newValue.hasSuffix(",") && !newValue.hasSuffix(", #") {
                            DispatchQueue.main.async {
                                categoriesText = newValue + " #"
                            }
                        }
                    }
                    .onChange(of: focusedField) { oldValue, newValue in
                        if newValue == .category {
                            // Pre-type hashtag if field is empty
                            if categoriesText.isEmpty {
                                categoriesText = "#"
                            } else if !categoriesText.hasPrefix("#") && !categoriesText.contains("#") {
                                // If no hashtag at all, add one at the start
                                categoriesText = "#" + categoriesText
                            }
                            // Show autocomplete when entering category field
                            updateCategoryAutocomplete(for: categoriesText)
                        } else if newValue == .body {
                            // Hide autocomplete when leaving category field
                            showCategoryAutocomplete = false
                        }
                    }
                    .onKeyPress { press in
                            if press.key == .tab {
                                // Tab always adds next category
                                if !categoriesText.isEmpty && !categoriesText.hasSuffix(", #") {
                                    if categoriesText.hasSuffix(",") {
                                        categoriesText += " #"
                                    } else {
                                        categoriesText += ", #"
                                    }
                                }
                                return .handled
                        }
                        return .ignored
                    }

                if showCategoryAutocomplete && !categorySuggestions.isEmpty && focusedField == .category {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categorySuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    insertCategory(suggestion)
                                }) {
                                    Text("#\(suggestion)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Body
            TextEditor(text: $bodyText)
                .font(.system(size: 15))
                .frame(minHeight: 120)
                .focused($focusedField, equals: .body)
                .scrollContentBackground(.hidden)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .onAppear {
            titleText = entry.title
            categoriesText = entry.categories.prefix(3).map { cat in
                let cleaned = cat.hasPrefix("#") ? String(cat.dropFirst()) : cat
                return "#\(cleaned)"
            }.joined(separator: ", ")
            bodyText = entry.body
            focusedField = editingField
        }
        .onChange(of: editingField) { oldValue, newValue in
            focusedField = newValue
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Button("Delete") {
                        onDelete()
                    }
                    .foregroundColor(.red)
                    Spacer()
                    Button("Cancel") {
                        onCancel()
                    }
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func updateCategoryAutocomplete(for text: String) {
        let parts = text.components(separatedBy: ",")
        if let lastPart = parts.last {
            let trimmed = lastPart.trimmingCharacters(in: CharacterSet.whitespaces)
            if trimmed.hasPrefix("#") {
                let categoryText = String(trimmed.dropFirst()).trimmingCharacters(in: CharacterSet.whitespaces)
                if !categoryText.isEmpty {
                    categorySuggestions = viewModel.getSimilarCategories(to: categoryText)
                    showCategoryAutocomplete = !categorySuggestions.isEmpty
                } else {
                    showCategoryAutocomplete = false
                }
            } else {
                showCategoryAutocomplete = false
            }
        }
    }

    private func insertCategory(_ category: String) {
        let parts = categoriesText.components(separatedBy: ",")
        if parts.count > 0 {
            let lastPart = parts.last ?? ""
            if lastPart.trimmingCharacters(in: CharacterSet.whitespaces).hasPrefix("#") {
                var newParts = Array(parts.dropLast())
                newParts.append("#\(category)")
                categoriesText = newParts.joined(separator: ", ")
            } else {
                categoriesText += ", #\(category)"
            }
        } else {
            categoriesText = "#\(category)"
        }
        showCategoryAutocomplete = false
    }

    private func saveEntry() {
        // Parse categories
        let categories = categoriesText.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
            .compactMap { part -> String? in
                if part.hasPrefix("#") {
                    return String(part.dropFirst()).trimmingCharacters(in: CharacterSet.whitespaces)
                }
                return part.isEmpty ? nil : part
            }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { $0 }

        // Don't save if title is empty
        guard !titleText.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty else {
            return
        }

        var entry = entry
        entry.title = titleText.trimmingCharacters(in: CharacterSet.whitespaces)
        entry.categories = Array(categories)
        entry.body = bodyText

        onSave(entry)
    }
}
