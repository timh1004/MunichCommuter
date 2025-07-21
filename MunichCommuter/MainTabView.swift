import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // Favoriten Tab
            NavigationView {
                FavoritesView()
            }
            .tabItem {
                Image(systemName: "star.fill")
                Text("Favoriten")
            }
            
            // Stationen Tab
            NavigationView {
                StationsView()
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Stationen")
            }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
} 