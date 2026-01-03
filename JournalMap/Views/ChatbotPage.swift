//
//  ChatbotPage.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import SwiftUI
import CoreData

struct ChatbotPage: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: ChatbotViewModel
    @State private var messageText: String = ""
    @State private var showAPIKeyAlert = false
    @State private var apiKeyInput: String = ""

    init(viewContext: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: ChatbotViewModel(viewContext: viewContext))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if viewModel.messages.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    Text("Ask me anything about your journal entries")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("I can help you find patterns, summarize entries, or answer questions about your thoughts and experiences.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                            }

                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .padding(.leading, 16)
                                    Text("Thinking...")
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 8)
                                    Spacer()
                                }
                            }

                            if let error = viewModel.errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                    Text(error)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { oldCount, newCount in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input area
                HStack(spacing: 12) {
                    TextField("Ask a question...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .onSubmit {
                            sendMessage()
                        }

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(messageText.isEmpty ? .gray : .accentColor)
                    }
                    .disabled(messageText.isEmpty || viewModel.isLoading)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAPIKeyAlert = true
                    }) {
                        Image(systemName: "key")
                    }
                }
            }
            .alert("OpenAI API Key", isPresented: $showAPIKeyAlert) {
                TextField("Enter API Key", text: $apiKeyInput)
                Button("Save") {
                    AppConfig.shared.openAIApiKey = apiKeyInput
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter your OpenAI API key to enable the chatbot feature.")
            }
            .onAppear {
                apiKeyInput = AppConfig.shared.openAIApiKey ?? ""
                // Don't auto-show alert, let user click key icon if needed
            }
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        viewModel.sendMessage(messageText)
        messageText = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(message.isUser ? Color.accentColor : Color(.systemGray5))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(18)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser {
                Spacer()
            }
        }
    }
}
