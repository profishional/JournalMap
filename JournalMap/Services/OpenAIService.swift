//
//  OpenAIService.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import Foundation

class OpenAIService {
    static let shared = OpenAIService()

    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private var apiKey: String? {
        return AppConfig.shared.openAIApiKey
    }

    private init() {}

    func sendMessage(_ message: String, journalContext: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = apiKey else {
            completion(.failure(OpenAIError.missingAPIKey))
            return
        }

        let systemPrompt = """
        You are a helpful assistant that can answer questions about the user's journal entries.
        Here are the user's journal entries for context:

        \(journalContext)

        Answer questions based on this journal content. Be helpful, concise, and respectful of the user's privacy.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ],
            "temperature": 0.7,
            "max_tokens": 500
        ]

        guard let url = URL(string: baseURL) else {
            completion(.failure(OpenAIError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(OpenAIError.noData))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let choices = json?["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    completion(.failure(OpenAIError.invalidResponse))
                    return
                }

                completion(.success(content))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case noData
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is not set. Please configure it in settings."
        case .invalidURL:
            return "Invalid API URL"
        case .noData:
            return "No data received from API"
        case .invalidResponse:
            return "Invalid response from API"
        }
    }
}
