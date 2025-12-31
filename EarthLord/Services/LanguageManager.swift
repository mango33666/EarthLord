//
//  LanguageManager.swift
//  EarthLord
//
//  Language management service for in-app language switching
//

import SwiftUI
import Foundation
import Combine

/// App language options
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system = "system"
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    /// Display name for each language option
    var displayName: LocalizedStringKey {
        switch self {
        case .system:
            return "跟随系统"
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    /// Language code for Bundle override (nil for system)
    var languageCode: String? {
        switch self {
        case .system:
            return nil
        case .chinese, .english:
            return rawValue
        }
    }
}

/// Language manager for handling app-wide language switching
@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private let userDefaultsKey = "app_language"

    /// Current selected language
    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguagePreference()
            applyLanguage()
        }
    }

    /// Current locale based on selected language
    var currentLocale: Locale {
        if let code = currentLanguage.languageCode {
            return Locale(identifier: code)
        } else {
            return Locale.current
        }
    }

    private init() {
        // Load saved language preference
        if let savedLanguage = UserDefaults.standard.string(forKey: userDefaultsKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }

        // Apply language on initialization
        applyLanguage()
    }

    /// Set app language
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }

    /// Save language preference to UserDefaults
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
        UserDefaults.standard.synchronize()
    }

    /// Apply language by updating Bundle override
    private func applyLanguage() {
        if let languageCode = currentLanguage.languageCode {
            // Set specific language
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        } else {
            // Follow system language
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()

        // Trigger UI refresh by updating published property
        objectWillChange.send()
    }
}
