//
//  JournalViewModel.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import Foundation
import CoreData
import SwiftUI

class JournalViewModel: ObservableObject {
    @Published var rawText: String = ""
    @Published var isTitleMode: Bool = false
    @Published var entries: [ParsedEntry] = []

    private let viewContext: NSManagedObjectContext
    private var existingTimestamps: [String: Date] = [:]

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        loadDocument()
    }

    func loadDocument() {
        let request: NSFetchRequest<JournalDocument> = JournalDocument.fetchRequest()
        request.fetchLimit = 1

        if let document = try? viewContext.fetch(request).first {
            rawText = document.rawText ?? ""
        } else {
            rawText = ""
        }

        // Load existing entries from Core Data to preserve timestamps
        loadExistingEntries()
        parseEntries()
    }

    private func loadExistingEntries() {
        existingTimestamps = [:]
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        if let coreDataEntries = try? viewContext.fetch(request) {
            for coreDataEntry in coreDataEntries {
                if let title = coreDataEntry.title {
                    // Store timestamp by title for lookup during parsing
                    existingTimestamps[title] = coreDataEntry.timestamp ?? Date()
                }
            }
        }
    }

    func saveDocument(reparseEntries: Bool = true) {
        let request: NSFetchRequest<JournalDocument> = JournalDocument.fetchRequest()
        request.fetchLimit = 1

        let document = (try? viewContext.fetch(request).first) ?? JournalDocument(context: viewContext)
        if document.id == nil {
            document.id = UUID()
        }
        document.rawText = rawText
        document.lastModified = Date()

        if reparseEntries {
            parseEntries()
        }
        saveToCoreData()

        // Refresh timestamp cache after saving
        loadExistingEntries()

        do {
            try viewContext.save()
        } catch {
            print("Error saving document: \(error)")
        }
    }

    func parseEntries() {
        entries = []
        let lines = rawText.components(separatedBy: .newlines)
        var currentEntry: ParsedEntry?
        var currentBody: [String] = []
        var hasSeenCategoryLine = false
        var previousLineWasEmpty = true

        for (_, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)

            // Check if this is a category line (starts with #)
            if trimmed.hasPrefix("#") {
                hasSeenCategoryLine = true
                let categoryText = String(trimmed.dropFirst()).trimmingCharacters(in: CharacterSet.whitespaces)
                if !categoryText.isEmpty {
                    let categories = categoryText.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
                        .filter { !$0.isEmpty }
                    currentEntry?.categories.append(contentsOf: categories)
                }
            }
            // Check if this is a title (non-empty, doesn't start with #, and either first line or previous line was empty)
            else if !trimmed.isEmpty && previousLineWasEmpty {
                // Save previous entry if exists
                if var entry = currentEntry { // ?.copy() TODO
                    entry.body = currentBody.joined(separator: "\n")
                    entries.append(entry)
                }

                // Start new entry - use existing timestamp from Core Data if available
                let entryTimestamp = existingTimestamps[trimmed] ?? Date()
                currentEntry = ParsedEntry(
                    title: trimmed,
                    categories: [],
                    body: "",
                    timestamp: entryTimestamp
                )
                currentBody = []
                hasSeenCategoryLine = false
                previousLineWasEmpty = false
            }
            // Body text (only if we have a current entry and it's not a category line)
            else if currentEntry != nil && !trimmed.hasPrefix("#") {
                if !trimmed.isEmpty {
                    currentBody.append(line)
                } else {
                    // Empty line in body - preserve it
                    currentBody.append("")
                }
                previousLineWasEmpty = trimmed.isEmpty
            } else {
                previousLineWasEmpty = trimmed.isEmpty
            }
        }

        // Save last entry
        if var entry = currentEntry { // ?.copy() TODO
            entry.body = currentBody.joined(separator: "\n")
            entries.append(entry)
        }

        // Sort by descending timestamp (newest first)
        entries.sort { $0.timestamp > $1.timestamp }
    }

    func saveToCoreData() {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()

        // Copy timestamps BEFORE deleting (don't hold references to deleted objects)
        var existingTimestampsMap: [String: Date] = [:]
        if let existingEntries = try? viewContext.fetch(fetchRequest) {
            for existingEntry in existingEntries {
                if let title = existingEntry.title, let timestamp = existingEntry.timestamp {
                    existingTimestampsMap[title] = timestamp
                }
            }
        }

        // Delete all existing entries
        if let existingEntries = try? viewContext.fetch(fetchRequest) {
            existingEntries.forEach { viewContext.delete($0) }
        }

        // Save parsed entries with preserved timestamps
        for (index, parsedEntry) in entries.enumerated() {
            let entry = JournalEntry(context: viewContext)
            entry.id = UUID()
            entry.title = parsedEntry.title
            entry.categories = parsedEntry.categories.joined(separator: ", ")
            entry.body = parsedEntry.body

            // Use timestamp from map (copied before deletion), fallback to parsed timestamp
            if let existingTimestamp = existingTimestampsMap[parsedEntry.title] {
                entry.timestamp = existingTimestamp
            } else {
                entry.timestamp = parsedEntry.timestamp
            }

            entry.lastModified = Date()
            entry.position = Int32(index)

            // Create or update categories
            for categoryName in parsedEntry.categories {
                let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
                categoryRequest.predicate = NSPredicate(format: "name == %@", categoryName)

                let category: Category
                if let existingCategory = try? viewContext.fetch(categoryRequest).first {
                    category = existingCategory
                } else {
                    category = Category(context: viewContext)
                    category.id = UUID()
                    category.name = categoryName
                    category.usageCount = 0
                }
                category.usageCount += 1
            }
        }
    }

    func getAllCategories() -> [String] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.usageCount, ascending: false)]

        if let categories = try? viewContext.fetch(request) {
            return categories.map { $0.name ?? "" }.filter { !$0.isEmpty }
        }
        return []
    }

    func getSimilarCategories(to searchText: String) -> [String] {
        let allCategories = getAllCategories()
        guard !allCategories.isEmpty else { return [] } // Return empty if no categories exist

        let lowerSearch = searchText.lowercased()
        guard !lowerSearch.isEmpty else { return allCategories.prefix(5).map { $0 } } // Return top 5 if search is empty

        return allCategories
            .filter { $0.lowercased().contains(lowerSearch) || lowerSearch.contains($0.lowercased()) }
            .sorted { category1, category2 in
                let score1 = similarityScore(category1.lowercased(), lowerSearch)
                let score2 = similarityScore(category2.lowercased(), lowerSearch)
                return score1 > score2
            }
            .prefix(5)
            .map { $0 }
    }

    private func similarityScore(_ str1: String, _ str2: String) -> Double {
        if str1 == str2 { return 1.0 }
        if str1.contains(str2) || str2.contains(str1) { return 0.8 }
        // Simple character overlap
        let set1 = Set(str1)
        let set2 = Set(str2)
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        return Double(intersection.count) / Double(union.count)
    }
}

struct ParsedEntry: Identifiable {
    let id = UUID()
    var title: String
    var categories: [String]
    var body: String
    var timestamp: Date

    init(title: String, categories: [String], body: String, timestamp: Date) {
        self.title = title
        self.categories = categories
        self.body = body
        self.timestamp = timestamp
    }
}
