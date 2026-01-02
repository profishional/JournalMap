//
//  ContinuousTextEditor.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import SwiftUI
import UIKit

struct ContinuousTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isTitleMode: Bool
    var onTextChange: (String) -> Void
    var onReturnKey: () -> Void
    var getCategorySuggestions: (String) -> [String]
    var onCategorySelect: (String) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let shouldUpdateText = uiView.text != text
        if shouldUpdateText {
            let currentRange = uiView.selectedRange
            uiView.text = text
            // Restore cursor position if possible
            if currentRange.location <= text.count {
                uiView.selectedRange = currentRange
            }
        }

        // Update font styling for entire document
        context.coordinator.updateFontForDocument(uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: ContinuousTextEditor
        var currentCategorySuggestions: [String] = []
        var showingAutocomplete = false

        init(_ parent: ContinuousTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange(textView.text)

            // Check if we're in a category line and show autocomplete
            let cursorPosition = textView.selectedRange.location
            let lineRange = getLineRange(for: textView, at: cursorPosition)
            let lineText = (textView.text as NSString).substring(with: lineRange)

            if lineText.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                let categoryText = String(lineText.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !categoryText.isEmpty && !categoryText.hasSuffix(",") {
                    let currentCategory = categoryText.components(separatedBy: ",").last?.trimmingCharacters(in: .whitespaces) ?? ""
                    if !currentCategory.isEmpty {
                        currentCategorySuggestions = parent.getCategorySuggestions(currentCategory)
                        showingAutocomplete = !currentCategorySuggestions.isEmpty
                    } else {
                        showingAutocomplete = false
                    }
                } else {
                    showingAutocomplete = false
                }
            } else {
                showingAutocomplete = false
            }

            updateFontForDocument(textView)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Handle Return key
            if text == "\n" {
                let cursorPosition = range.location
                let lineRange = getLineRange(for: textView, at: cursorPosition)
                let lineText = (textView.text as NSString).substring(with: lineRange)
                let trimmed = lineText.trimmingCharacters(in: .whitespaces)

                // If in title mode and pressing return on empty or title line, add "#" for category
                if parent.isTitleMode {
                    parent.isTitleMode = false
                    DispatchQueue.main.async {
                        let newText = (textView.text as NSString).replacingCharacters(in: range, with: "\n#")
                        textView.text = newText
                        let newPosition = range.location + 2
                        textView.selectedRange = NSRange(location: newPosition, length: 0)
                        self.parent.text = newText
                        self.parent.onTextChange(newText)
                        self.updateFontForDocument(textView)
                    }
                    return false
                }
                // If in category line and pressing return, move to body
                else if trimmed.hasPrefix("#") {
                    parent.isTitleMode = false
                    return true // Allow normal return
                }
            }

            // Handle comma in category line - auto-add "#" after comma
            if text == "," {
                let cursorPosition = range.location
                let lineRange = getLineRange(for: textView, at: cursorPosition)
                let lineText = (textView.text as NSString).substring(with: lineRange)
                let trimmed = lineText.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("#") {
                    DispatchQueue.main.async {
                        let newText = (textView.text as NSString).replacingCharacters(in: range, with: ", #")
                        textView.text = newText
                        let newPosition = range.location + 3
                        textView.selectedRange = NSRange(location: newPosition, length: 0)
                        self.parent.text = newText
                        self.parent.onTextChange(newText)
                        self.updateFontForDocument(textView)
                    }
                    return false
                }
            }

            return true
        }

        private func getLineRange(for textView: UITextView, at position: Int) -> NSRange {
            let text = textView.text as NSString
            let lineRange = text.lineRange(for: NSRange(location: position, length: 0))
            return lineRange
        }

        func updateFontForDocument(_ textView: UITextView) {
            let text = textView.text
            guard !text.isEmpty else {
                // Set default font for empty text
                textView.font = UIFont.systemFont(ofSize: 16, weight: .regular)
                return
            }

            let mutableAttributedString = NSMutableAttributedString(string: text)
            let allLines = text.components(separatedBy: .newlines)
            var currentLocation = 0
            let cursorPosition = textView.selectedRange.location

            for (index, line) in allLines.enumerated() {
                let lineLength = (line as NSString).length
                let lineRange = NSRange(location: currentLocation, length: lineLength)
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                var font: UIFont

                // Check if this is the current line and in title mode (for empty line or new line)
                let isCurrentLine = cursorPosition >= currentLocation && cursorPosition <= currentLocation + lineLength + 1

                if parent.isTitleMode && isCurrentLine && trimmed.isEmpty {
                    // New line in title mode - use title font
                    font = UIFont.systemFont(ofSize: 24, weight: .bold)
                }
                // Check if line starts with # (category line)
                else if trimmed.hasPrefix("#") {
                    font = UIFont.systemFont(ofSize: 16, weight: .medium)
                }
                // Determine if this is a title line (non-empty, not starting with #, followed by category line)
                else if !trimmed.isEmpty {
                    // Check if next line is a category line
                    let isFollowedByCategory = index + 1 < allLines.count &&
                                               allLines[index + 1].trimmingCharacters(in: .whitespaces).hasPrefix("#")

                    // Also check if previous line was empty or category (new entry)
                    let isNewEntry = index == 0 ||
                                    (index > 0 && (allLines[index - 1].trimmingCharacters(in: .whitespaces).isEmpty ||
                                     allLines[index - 1].trimmingCharacters(in: .whitespaces).hasPrefix("#")))

                    if isFollowedByCategory && isNewEntry {
                        font = UIFont.systemFont(ofSize: 24, weight: .bold)
                    } else {
                        font = UIFont.systemFont(ofSize: 16, weight: .regular)
                    }
                } else {
                    font = UIFont.systemFont(ofSize: 16, weight: .regular)
                }

                mutableAttributedString.addAttribute(.font, value: font, range: lineRange)

                // Add newline character styling (except for last line)
                if index < allLines.count - 1 {
                    let newlineRange = NSRange(location: currentLocation + lineLength, length: 1)
                    mutableAttributedString.addAttribute(.font, value: font, range: newlineRange)
                }

                currentLocation += lineLength + 1 // +1 for newline
            }

            textView.attributedText = mutableAttributedString
        }
    }
}
