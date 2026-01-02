//
//  CategoryAutocompleteView.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import SwiftUI

struct CategoryAutocompleteView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        onSelect(suggestion)
                    }) {
                        HStack {
                            Text(suggestion)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if suggestion != suggestions.last {
                        Divider()
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
}
