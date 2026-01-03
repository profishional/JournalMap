//
//  CollectionsPage.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import SwiftUI
import CoreData

struct CollectionsPage: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: CollectionsViewModel
    @State private var selectedFilter: FilterType? = nil
    @State private var filteredEntries: [JournalEntry] = []

    enum FilterType {
        case date(year: Int, month: Int?)
        case category(String)
    }

    init(viewContext: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: CollectionsViewModel(viewContext: viewContext))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Category Sections - Show first
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Categories")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        if viewModel.categorySections.isEmpty {
                            Text("No categories yet. Add categories to your journal entries to see them here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                                ForEach(viewModel.categorySections) { section in
                                    Button(action: {
                                        selectedFilter = .category(section.name)
                                        filteredEntries = viewModel.filterEntries(by: section.name)
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(section.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text("\(section.entryCount) entries")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Date Sections
                    VStack(alignment: .leading, spacing: 16) {
                        Text("By Date")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        if viewModel.dateSections.isEmpty {
                            Text("No entries yet. Start journaling to see entries organized by date.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            ForEach(viewModel.dateSections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(section.year)")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(1...12, id: \.self) { month in
                                            let monthEntries = section.entries.filter { entry in
                                                Calendar.current.component(.month, from: entry.timestamp ?? Date()) == month
                                            }

                                            if !monthEntries.isEmpty {
                                                Button(action: {
                                                    selectedFilter = .date(year: section.year, month: month)
                                                    filteredEntries = viewModel.filterEntries(by: section.year, month: month)
                                                }) {
                                                    VStack {
                                                        Text(monthName(month))
                                                            .font(.caption)
                                                            .fontWeight(.semibold)
                                                        Text("\(monthEntries.count)")
                                                            .font(.title3)
                                                            .fontWeight(.bold)
                                                    }
                                                    .frame(width: 80, height: 80)
                                                    .background(Color.accentColor.opacity(0.1))
                                                    .foregroundColor(.accentColor)
                                                    .cornerRadius(12)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Collections")
            .sheet(item: Binding(
                get: { selectedFilter != nil ? FilterWrapper(filter: selectedFilter!) : nil },
                set: { if $0 == nil { selectedFilter = nil } }
            )) { filterWrapper in
                FilteredEntriesView(entries: filteredEntries, filter: filterWrapper.filter)
            }
        }
        .onAppear {
            viewModel.loadSections()
        }
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let date = Calendar.current.date(from: DateComponents(year: 2000, month: month, day: 1)) ?? Date()
        return formatter.string(from: date)
    }
}

struct FilterWrapper: Identifiable {
    let id = UUID()
    let filter: CollectionsPage.FilterType
}

struct FilteredEntriesView: View {
    let entries: [JournalEntry]
    let filter: CollectionsPage.FilterType

    var body: some View {
        NavigationView {
            List {
                ForEach(entries, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.title ?? "Untitled")
                            .font(.headline)
                        if let categories = entry.categories, !categories.isEmpty {
                            Text(categories)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let body = entry.body, !body.isEmpty {
                            Text(body)
                                .font(.body)
                                .lineLimit(3)
                        }
                        Text(entry.timestamp ?? Date(), style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(filterTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var filterTitle: String {
        switch filter {
        case .date(let year, let month):
            if let month = month {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                let date = Calendar.current.date(from: DateComponents(year: year, month: month))!
                return formatter.string(from: date)
            }
            return "\(year)"
        case .category(let name):
            return name
        }
    }
}
