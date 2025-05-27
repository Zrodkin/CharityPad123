//
//  CharityPad123App.swift
//  CharityPad123
//
//  Created by Zalman Rodkin on 5/27/25.
//

import SwiftUI

@main
struct CharityPad123App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
