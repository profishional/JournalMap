//
//  ContentView.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        TabView {
            JournalEntriesPage(viewContext: viewContext)
                .tag(0)

            CollectionsPage(viewContext: viewContext)
                .tag(1)

            ChatbotPage(viewContext: viewContext)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
