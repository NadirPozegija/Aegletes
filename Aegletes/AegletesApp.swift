//
// AegletesApp.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/7/26 - RootView with Meter ↔ Film DB navigation
//

import SwiftUI

@main
struct AegletesApp: App {
    @StateObject private var filmStore = FilmRollStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(filmStore)
        }
    }
}

private enum AppMode {
    case meter
    case filmDB
}

struct RootView: View {
    @State private var mode: AppMode = .meter

    var body: some View {
        Group {
            switch mode {
            case .meter:
                // Metering UI
                ContentView(onShowFilmDB: {
                    mode = .filmDB
                })

            case .filmDB:
                // Film Database UI
                FilmDBRootView {
                    mode = .meter
                }
            }
        }
    }
}
