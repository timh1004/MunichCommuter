import SwiftUI

struct FavoritesView: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var locationManager = LocationManager.shared
    
    private var sortedFavorites: [FilteredFavorite] {
        if locationManager.location != nil {
            return favoritesManager.favorites.sorted { favorite1, favorite2 in
                let distance1 = locationManager.distanceFrom(favorite1.location.coord ?? []) ?? Double.infinity
                let distance2 = locationManager.distanceFrom(favorite2.location.coord ?? []) ?? Double.infinity
                return distance1 < distance2
            }
        } else {
            return favoritesManager.favorites
        }
    }
    
    var body: some View {
        VStack {
            if favoritesManager.favorites.isEmpty {
                // Empty State
                VStack(spacing: 20) {
                    Image(systemName: "star")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("Keine Favoriten")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Fügen Sie Stationen zu Ihren Favoriten hinzu, um sie hier zu sehen")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Text("Tippen Sie auf ⭐ in einer Station")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                // Favorites List
                List {
                    ForEach(sortedFavorites) { favorite in
                        NavigationLink(destination: DepartureDetailView(
                            locationId: favorite.location.id,
                            locationName: favorite.location.disassembledName ?? favorite.location.name,
                            initialFilter: favorite.destinationFilter,
                            initialTransportTypes: favorite.transportTypeFilters
                        )) {
                            FilteredFavoriteRowView(favorite: favorite)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    .onDelete(perform: deleteFavorites)
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Favoriten")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            locationManager.requestLocation()
        }
    }
    
    private func deleteFavorites(offsets: IndexSet) {
        for index in offsets {
            let favorite = sortedFavorites[index]
            favoritesManager.removeFavorite(favorite)
        }
    }
}

struct FilteredFavoriteRowView: View {
    let favorite: FilteredFavorite
    @StateObject private var locationManager = LocationManager.shared
    
    var body: some View {
        HStack {
            // Star Icon
            Image(systemName: favorite.hasFilters ? "star.circle.fill" : "star.fill")
                .frame(width: 24, height: 24)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.location.disassembledName ?? favorite.location.name ?? "Unbekannte Haltestelle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack {
                    if let parent = favorite.location.parent?.name,
                       parent != (favorite.location.disassembledName ?? favorite.location.name) {
                        Text(parent)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    if let filterText = favorite.filterDisplayText {
                        if let parent = favorite.location.parent?.name,
                           parent != (favorite.location.disassembledName ?? favorite.location.name) {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Text(filterText)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Distance Display
            if let distance = locationManager.distanceFrom(favorite.location.coord ?? []) {
                Text(locationManager.formattedDistance(distance))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationView {
        FavoritesView()
    }
} 