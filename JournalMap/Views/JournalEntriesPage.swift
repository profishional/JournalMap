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
    @State private var showCategoryAutocomplete = false
    @State private var categorySuggestions: [String] = []
    @State private var autocompletePosition: CGPoint = .zero
    @State private var currentCategoryText: String = ""
    @State private var zoomScale: CGFloat = 1.0
    @State private var showTitlesOnly = false
    @GestureState private var magnification: CGFloat = 1.0

    init(viewContext: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: JournalViewModel(viewContext: viewContext))
    }

    var body: some View {
        ZStack {
            if showTitlesOnly {
                titlesOnlyView
            } else {
                fullTextView
            }

            // Floating plus button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        // Move cursor to end and add newline if needed
                        if !viewModel.rawText.isEmpty && !viewModel.rawText.hasSuffix("\n") {
                            viewModel.rawText += "\n"
                        }
                        if !viewModel.rawText.isEmpty {
                            viewModel.rawText += "\n"
                        }
                        viewModel.isTitleMode = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .gesture(
            MagnificationGesture()
                .updating($magnification) { currentState, gestureState, _ in
                    gestureState = currentState
                }
                .onEnded { value in
                    if value > 1.3 {
                        withAnimation(.spring()) {
                            showTitlesOnly = true
                        }
                    } else if value < 0.8 {
                        withAnimation(.spring()) {
                            showTitlesOnly = false
                        }
                    }
                }
        )
        .onAppear {
            viewModel.loadDocument()
        }
        .onChange(of: viewModel.rawText) { _ in
            viewModel.saveDocument()
        }
    }

    private func updateCategoryAutocomplete(for text: String) {
        // Find the current line and check if it's a category line
        let lines = text.components(separatedBy: .newlines)
        // For simplicity, check the last line
        if let lastLine = lines.last, lastLine.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            let categoryText = String(lastLine.dropFirst()).trimmingCharacters(in: .whitespaces)
            if !categoryText.isEmpty && !categoryText.hasSuffix(",") {
                let currentCategory = categoryText.components(separatedBy: ",").last?.trimmingCharacters(in: .whitespaces) ?? ""
                if !currentCategory.isEmpty {
                    currentCategoryText = currentCategory
                    categorySuggestions = viewModel.getSimilarCategories(to: currentCategory)
                    showCategoryAutocomplete = !categorySuggestions.isEmpty
                } else {
                    showCategoryAutocomplete = false
                }
            } else {
                showCategoryAutocomplete = false
            }
        } else {
            showCategoryAutocomplete = false
        }
    }

    private func insertCategory(_ category: String) {
        // This would need to be implemented with proper cursor position tracking
        // For now, just hide the autocomplete
        showCategoryAutocomplete = false
    }

    private var fullTextView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    ContinuousTextEditor(
                        text: $viewModel.rawText,
                        isTitleMode: $viewModel.isTitleMode,
                        onTextChange: { text in
                            // Check for category autocomplete
                            updateCategoryAutocomplete(for: text)
                        },
                        onReturnKey: {
                            // Return key handled in coordinator
                        },
                        getCategorySuggestions: { searchText in
                            viewModel.getSimilarCategories(to: searchText)
                        },
                        onCategorySelect: { category in
                            insertCategory(category)
                        }
                    )
                    .frame(minHeight: UIScreen.main.bounds.height)

                    // Category autocomplete dropdown
                    if showCategoryAutocomplete && !categorySuggestions.isEmpty {
                        VStack {
                            CategoryAutocompleteView(
                                suggestions: categorySuggestions,
                                onSelect: { category in
                                    insertCategory(category)
                                }
                            )
                            Spacer()
                        }
                        .padding(.leading, 16)
                        .padding(.top, 100) // Adjust based on cursor position
                    }
                }
            }
        }
    }

    private var titlesOnlyView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                ForEach(Array(viewModel.entries.enumerated()), id: \.element.title) { index, entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(2)
                        Text(entry.timestamp, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}
