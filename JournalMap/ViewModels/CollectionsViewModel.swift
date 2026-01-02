//
//  CollectionsViewModel.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import Foundation
import CoreData

class CollectionsViewModel: ObservableObject {
    @Published var dateSections: [DateSection] = []
    @Published var categorySections: [CategorySection] = []
    @Published var searchText: String = ""

    private let viewContext: NSManagedObjectContext

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        loadSections()
    }

    func loadSections() {
        loadDateSections()
        loadCategorySections()
    }

    private func loadDateSections() {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.timestamp, ascending: false)]

        guard let entries = try? viewContext.fetch(request) else {
            dateSections = []
            return
        }

        let calendar = Calendar.current
        var yearGroups: [Int: [JournalEntry]] = [:]
        var monthGroups: [String: [JournalEntry]] = [:]

        for entry in entries {
            guard let date = entry.timestamp else { continue }
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let key = "\(year)-\(month)"

            if yearGroups[year] == nil {
                yearGroups[year] = []
            }
            yearGroups[year]?.append(entry)

            if monthGroups[key] == nil {
                monthGroups[key] = []
            }
            monthGroups[key]?.append(entry)
        }

        dateSections = yearGroups.map { year, entries in
            DateSection(year: year, entries: entries)
        }.sorted { $0.year > $1.year }
    }

    private func loadCategorySections() {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.usageCount, ascending: false)]

        guard let categories = try? viewContext.fetch(request) else {
            categorySections = []
            return
        }

        categorySections = categories.compactMap { category in
            guard let name = category.name else { return nil }
            let entryRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
            entryRequest.predicate = NSPredicate(format: "categories CONTAINS[cd] %@", name)
            entryRequest.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.timestamp, ascending: false)]

            guard let entries = try? viewContext.fetch(entryRequest) else { return nil }

            return CategorySection(name: name, entryCount: entries.count, entries: entries)
        }
    }

    func filterEntries(by category: String) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "categories CONTAINS[cd] %@", category)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.timestamp, ascending: false)]

        return (try? viewContext.fetch(request)) ?? []
    }

    func filterEntries(by year: Int, month: Int? = nil) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        let calendar = Calendar.current

        var predicates: [NSPredicate] = []

        if let month = month {
            let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1))
            let endDate = calendar.date(byAdding: .month, value: 1, to: startDate ?? Date())
            predicates.append(NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startDate! as NSDate, endDate! as NSDate))
        } else {
            let startDate = calendar.date(from: DateComponents(year: year, month: 1, day: 1))
            let endDate = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
            predicates.append(NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startDate! as NSDate, endDate! as NSDate))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.timestamp, ascending: false)]

        return (try? viewContext.fetch(request)) ?? []
    }
}

struct DateSection: Identifiable {
    let id = UUID()
    let year: Int
    let entries: [JournalEntry]
}

struct CategorySection: Identifiable {
    let id = UUID()
    let name: String
    let entryCount: Int
    let entries: [JournalEntry]
}
