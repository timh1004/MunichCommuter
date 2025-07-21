import SwiftUI

struct FavoritesView: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    
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
                    ForEach(favoritesManager.favorites) { favorite in
                        NavigationLink(destination: DepartureDetailView(location: favorite)) {
                            FavoriteRowView(location: favorite)
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
    }
    
    private func deleteFavorites(offsets: IndexSet) {
        for index in offsets {
            let location = favoritesManager.favorites[index]
            favoritesManager.removeFavorite(location)
        }
    }
}

struct FavoriteRowView: View {
    let location: Location
    
    var body: some View {
        HStack {
            // Star Icon
            Image(systemName: "star.fill")
                .frame(width: 24, height: 24)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(location.disassembledName ?? location.name ?? "Unbekannte Haltestelle")
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
}

#Preview {
    NavigationView {
        FavoritesView()
    }
} 