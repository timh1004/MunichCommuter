//
//  SettingsWatchView.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import SwiftUI

struct SettingsWatchView: View {
    @StateObject private var locationManager = WatchLocationManager.shared
    @StateObject private var favoritesManager = WatchFavoritesManager.shared
    @AppStorage("batteryOptimization") private var batteryOptimization = true
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("autoRefresh") private var autoRefresh = true
    
    @State private var showingLocationSettings = false
    @State private var showingAbout = false
    @State private var showingClearCache = false
    
    var body: some View {
        NavigationStack {
            List {
                // Location Settings
                Section("Standort") {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Standortzugriff")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text(locationStatusText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                            Button("Einstellungen") {
                                // Open Watch Settings
                                if let url = URL(string: "x-apple-watchkit://"), 
                                   UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption2)
                        } else if locationManager.authorizationStatus == .notDetermined {
                            Button("Aktivieren") {
                                locationManager.requestLocationPermission()
                            }
                            .font(.caption2)
                        }
                    }
                }
                
                // Performance Settings
                Section("Leistung") {
                    HStack {
                        Image(systemName: "battery.100")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Batterieoptimierung")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text("Reduziert Standortgenauigkeit")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $batteryOptimization)
                            .labelsHidden()
                    }
                    .onChange(of: batteryOptimization) { _, newValue in
                        if newValue {
                            locationManager.optimizeForBattery()
                        } else {
                            locationManager.optimizeForAccuracy()
                        }
                    }
                    
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Automatische Aktualisierung")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text("Regelmäßige Datenaktualisierung")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $autoRefresh)
                            .labelsHidden()
                    }
                }
                
                // User Experience Settings
                Section("Benutzererfahrung") {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Haptisches Feedback")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text("Vibrationen für Aktionen")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $hapticFeedback)
                            .labelsHidden()
                    }
                }
                
                // Data Management
                Section("Daten") {
                    Button {
                        favoritesManager.requestFavoritesFromPhone()
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        HStack {
                            Image(systemName: "iphone.and.watch")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Mit iPhone synchronisieren")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Favoriten vom iPhone laden")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button {
                        showingClearCache = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Cache leeren")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Gespeicherte Daten löschen")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // About Section
                Section("Info") {
                    Button {
                        showingAbout = true
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            
                            Text("Über die App")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.plain)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingAbout) {
            AboutWatchView()
        }
        .confirmationDialog("Cache leeren", isPresented: $showingClearCache) {
            Button("Cache leeren", role: .destructive) {
                clearAllCache()
                WKInterfaceDevice.current().play(.click)
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Alle gespeicherten Daten werden gelöscht. Favoriten bleiben erhalten.")
        }
    }
    
    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Aktiviert"
        case .denied:
            return "Verweigert"
        case .restricted:
            return "Beschränkt"
        case .notDetermined:
            return "Nicht festgelegt"
        @unknown default:
            return "Unbekannt"
        }
    }
    
    private func clearAllCache() {
        // Clear MVV Service cache (create temporary instance to clear cache)
        let mvvService = WatchMVVService()
        mvvService.clearCache()
        
        // Don't clear favorites as they are synced with iPhone
        print("✅ Cache cleared")
    }
}

// MARK: - About View
struct AboutWatchView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "tram.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                Text("München Commuter")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("Öffentliche Verkehrsmittel in München")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    
                    Text("Live-Abfahrtszeiten • Favoriten • Standortbasierte Suche")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Daten bereitgestellt von MVG")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("© 2024 München Commuter")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Über")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .font(.caption)
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct SettingsWatchView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsWatchView()
    }
}
#endif