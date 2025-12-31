//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 芒果888 on 2025/12/27.
//

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct EarthLordApp: App {
    @StateObject private var languageManager = LanguageManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.currentLocale)
                .onOpenURL { url in
                    print("📱 收到 URL 回调: \(url)")
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
