//
//  ExtensionDelegate.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import WatchKit
import Foundation
import WatchConnectivity

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    private var favoritesManager: WatchFavoritesManager!
    private var locationManager: WatchLocationManager!
    
    func applicationDidFinishLaunching() {
        print("🚀 Watch Extension launched")
        
        // Initialize managers
        favoritesManager = WatchFavoritesManager.shared
        locationManager = WatchLocationManager.shared
        
        // Setup background refresh
        setupBackgroundRefresh()
        
        // Request favorites from iPhone
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.favoritesManager.requestFavoritesFromPhone()
        }
    }
    
    func applicationDidBecomeActive() {
        print("📱 Watch Extension became active")
        
        // Refresh location if authorized
        if locationManager.hasLocationPermission {
            locationManager.requestLocationUpdate()
        }
        
        // Sync with iPhone
        favoritesManager.requestFavoritesFromPhone()
    }
    
    func applicationWillResignActive() {
        print("💤 Watch Extension will resign active")
        
        // Stop location updates to save battery
        locationManager.stopLocationUpdates()
    }
    
    // MARK: - Background Refresh
    private func setupBackgroundRefresh() {
        // Schedule background refresh for departure updates
        let fireDate = Date().addingTimeInterval(15 * 60) // 15 minutes
        
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: fireDate,
            userInfo: ["task": "refreshDepartures"]
        ) { error in
            if let error = error {
                print("❌ Failed to schedule background refresh: \(error)")
            } else {
                print("✅ Background refresh scheduled")
            }
        }
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let backgroundRefreshTask as WKApplicationRefreshBackgroundTask:
                handleBackgroundRefresh(backgroundRefreshTask)
                
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                handleSnapshot(snapshotTask)
                
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                handleConnectivityRefresh(connectivityTask)
                
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                handleURLSessionRefresh(urlSessionTask)
                
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
    private func handleBackgroundRefresh(_ task: WKApplicationRefreshBackgroundTask) {
        print("🔄 Handling background refresh")
        
        // Update departures for top favorites
        Task {
            await updateTopFavorites()
            
            // Schedule next refresh
            setupBackgroundRefresh()
            
            // Complete the task
            task.setTaskCompletedWithSnapshot(false)
        }
    }
    
    private func handleSnapshot(_ task: WKSnapshotRefreshBackgroundTask) {
        print("📸 Handling snapshot refresh")
        
        // Restore user context if needed
        task.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date().addingTimeInterval(60 * 60)) // 1 hour
    }
    
    private func handleConnectivityRefresh(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        print("📡 Handling connectivity refresh")
        
        // Handle data from iPhone
        favoritesManager.requestFavoritesFromPhone()
        
        task.setTaskCompletedWithSnapshot(false)
    }
    
    private func handleURLSessionRefresh(_ task: WKURLSessionRefreshBackgroundTask) {
        print("🌐 Handling URL session refresh")
        
        // Handle completed network requests
        task.setTaskCompletedWithSnapshot(false)
    }
    
    @MainActor
    private func updateTopFavorites() async {
        let topFavorites = Array(favoritesManager.favorites.prefix(3))
        
        for favorite in topFavorites {
            let mvvService = WatchMVVService()
            await mvvService.loadDepartures(locationId: favorite.location.id, limit: 5)
        }
        
        print("✅ Updated \(topFavorites.count) top favorites")
    }
    
    // MARK: - Complications Support
    func getComplicationData() -> [String: Any] {
        let topFavorite = favoritesManager.favorites.first
        
        return [
            "hasTopFavorite": topFavorite != nil,
            "topFavoriteName": topFavorite?.location.displayName ?? "",
            "topFavoriteId": topFavorite?.location.id ?? "",
            "favoritesCount": favoritesManager.favorites.count
        ]
    }
}

// MARK: - Battery Optimization
extension ExtensionDelegate {
    private func optimizeForBattery() {
        // Reduce location accuracy
        locationManager.optimizeForBattery()
        
        // Reduce background refresh frequency
        let fireDate = Date().addingTimeInterval(30 * 60) // 30 minutes instead of 15
        
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: fireDate,
            userInfo: ["task": "refreshDepartures", "batteryOptimized": true]
        ) { error in
            if let error = error {
                print("❌ Failed to schedule battery-optimized refresh: \(error)")
            }
        }
    }
}