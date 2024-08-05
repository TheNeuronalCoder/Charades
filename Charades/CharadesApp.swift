//
//  CharadesApp.swift
//  Charades
//
//  Created by Menelik Eyasu on 7/20/24.
//

import SwiftUI

@main
struct CharadesApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
