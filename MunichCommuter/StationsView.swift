import SwiftUI
import Combine

struct StationsView: View {
    @StateObject private var mvvService = MVVService()
    @State private var searchText = ""
    @State private var debounceTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Search Bar with Auto-search and Clear Button
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                    
                    TextField("Haltestelle suchen...", text: $searchText)
                        .onChange(of: searchText) { _, newValue in
                            startDebounceTimer(for: newValue)
                        }
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            mvvService.locations = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
            
            // Content Area
            if mvvService.isLoading {
                Spacer()
                ProgressView("Suche Haltestellen...")
                Spacer()
            } else if let errorMessage = mvvService.errorMessage {
                Spacer()
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Fehler")
                        .font(.headline)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Erneut versuchen") {
                        mvvService.searchStops(name: searchText)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else if mvvService.locations.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Keine Haltestellen gefunden")
                        .font(.headline)
                    Text("Versuchen Sie eine andere Suche")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                // Results List
                List(mvvService.locations) { location in
                    NavigationLink(destination: DepartureDetailView(location: location)) {
                        LocationRowView(location: location)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Stationen")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Search Functions
    private func startDebounceTimer(for searchText: String) {
        // Cancel existing timer
        debounceTimer?.invalidate()
        
        // Don't search for very short queries
        guard searchText.count >= 2 else {
            mvvService.locations = []
            return
        }
        
        // Start new timer with 0.5 second delay
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            performSearch()
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        mvvService.searchStops(name: searchText)
    }
}

struct LocationRowView: View {
    let location: Location
    
    var body: some View {
        HStack {
            // Location Type Icon
            Image(systemName: locationIcon)
                .frame(width: 24, height: 24)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(locationDisplayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if let parent = location.parent?.name {
                    Text(parent)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
    
    private var locationDisplayName: String {
        // Use the proper disassembled name from API - no manual string manipulation needed!
        return location.disassembledName ?? location.name ?? "Unbekannte Haltestelle"
    }
    
    private var locationIcon: String {
        switch location.type {
        case "stop":
            return "tram.circle"
        case "poi":
            return "mappin.circle"
        default:
            return "location.circle"
        }
    }
}

#Preview {
    NavigationView {
        StationsView()
    }
} 