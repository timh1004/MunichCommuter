//
//  ContentView.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import SwiftUI

struct ContentView: View {
    @StateObject private var favoritesManager = WatchFavoritesManager.shared
    @StateObject private var locationManager = WatchLocationManager.shared
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Favorites Tab
            FavoritesWatchView()
                .tabItem {
                    Image(systemName: "star.fill")
                    Text("Favoriten")
                }
                .tag(0)
            
            // Search Tab
            StationSearchWatchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Suchen")
                }
                .tag(1)
            
            // Settings Tab
            SettingsWatchView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Einstellungen")
                }
                .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .onAppear {
            // Initialize services
            setupApp()
        }
    }
    
    private func setupApp() {
        // Request location permission if not determined
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestLocationPermission()
        }
        
        // Sync favorites from iPhone
        favoritesManager.requestFavoritesFromPhone()
        
        // Set initial tab based on favorites
        if favoritesManager.favorites.isEmpty {
            selectedTab = 1 // Search tab
        } else {
            selectedTab = 0 // Favorites tab
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif