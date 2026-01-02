//
//  ChatbotViewModel.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import Foundation
import CoreData

class ChatbotViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let viewContext: NSManagedObjectContext
    private let openAIService = OpenAIService.shared

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }

    func sendMessage(_ content: String) {
        let userMessage = ChatMessage(content: content, isUser: true)
        messages.append(userMessage)

        isLoading = true
        errorMessage = nil

        let journalContext = getJournalContext()

        openAIService.sendMessage(content, journalContext: journalContext) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let response):
                    let assistantMessage = ChatMessage(content: response, isUser: false)
                    self?.messages.append(assistantMessage)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func getJournalContext() -> String {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.timestamp, ascending: false)]
        request.fetchLimit = 50 // Limit to recent 50 entries

        guard let entries = try? viewContext.fetch(request) else {
            return "No journal entries available."
        }

        return entries.map { entry in
            var text = "Title: \(entry.title ?? "")\n"
            if let categories = entry.categories, !categories.isEmpty {
                text += "Categories: \(categories)\n"
            }
            if let body = entry.body, !body.isEmpty {
                text += "Body: \(body)\n"
            }
            text += "Date: \(entry.timestamp ?? Date())\n"
            return text
        }.joined(separator: "\n---\n\n")
    }
}
