//
//  WatchLoadingStates.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import SwiftUI

// MARK: - Loading Indicator
struct LoadingIndicatorWatch: View {
    let text: String
    let compact: Bool
    
    init(text: String = "Laden...", compact: Bool = false) {
        self.text = text
        self.compact = compact
    }
    
    var body: some View {
        HStack(spacing: compact ? 4 : 8) {
            ProgressView()
                .scaleEffect(compact ? 0.7 : 0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            Text(text)
                .font(compact ? .caption2 : .caption)
                .foregroundColor(.secondary)
        }
        .padding(compact ? 4 : 8)
    }
}

// MARK: - Error State
struct ErrorStateWatch: View {
    let message: String
    let action: (() -> Void)?
    let compact: Bool
    
    init(message: String, action: (() -> Void)? = nil, compact: Bool = false) {
        self.message = message
        self.action = action
        self.compact = compact
    }
    
    var body: some View {
        VStack(spacing: compact ? 4 : 8) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(compact ? .caption2 : .caption)
                
                Text(message)
                    .font(compact ? .caption2 : .caption)
                    .foregroundColor(.secondary)
                    .lineLimit(compact ? 1 : 2)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action, !compact {
                Button("Erneut versuchen") {
                    action()
                }
                .font(.caption2)
                .padding(.top, 4)
            }
        }
        .padding(compact ? 4 : 8)
    }
}

// MARK: - Empty State
struct EmptyStateWatch: View {
    let icon: String
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        action: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.actionTitle = actionTitle
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.gray.opacity(0.6))
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            if let action = action, let actionTitle = actionTitle {
                Button(actionTitle) {
                    action()
                }
                .font(.caption2)
                .padding(.top, 4)
            }
        }
        .padding()
    }
}

// MARK: - Skeleton Loading (for departures)
struct DepartureSkeletonWatch: View {
    var body: some View {
        HStack(spacing: 4) {
            // Transport badge skeleton
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 24, height: 12)
                .cornerRadius(2)
            
            // Destination skeleton
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 10)
                .cornerRadius(2)
            
            Spacer()
            
            // Time skeleton
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 30, height: 10)
                .cornerRadius(2)
        }
        .padding(.vertical, 2)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Skeleton for Favorites
struct FavoriteSkeletonWatch: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 16, height: 16)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 12)
                    .cornerRadius(2)
                
                Spacer()
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 10)
                    .cornerRadius(2)
            }
            
            VStack(spacing: 2) {
                DepartureSkeletonWatch()
                DepartureSkeletonWatch()
            }
            .padding(.leading, 20)
        }
        .padding(.vertical, 8)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Network Status Indicator
struct NetworkStatusWatch: View {
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isConnected ? "wifi" : "wifi.slash")
                .font(.caption2)
                .foregroundColor(isConnected ? .green : .orange)
            
            Text(isConnected ? "Online" : "Offline")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Refresh Indicator
struct RefreshIndicatorWatch: View {
    @State private var isRotating = false
    
    var body: some View {
        Image(systemName: "arrow.clockwise")
            .font(.caption)
            .foregroundColor(.blue)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRotating)
            .onAppear {
                isRotating = true
            }
            .onDisappear {
                isRotating = false
            }
    }
}

// MARK: - Previews
#if DEBUG
struct WatchLoadingStates_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoadingIndicatorWatch()
                .previewDisplayName("Loading Normal")
            
            LoadingIndicatorWatch(text: "Lade Abfahrten...", compact: true)
                .previewDisplayName("Loading Compact")
            
            ErrorStateWatch(message: "Verbindung fehlgeschlagen")
                .previewDisplayName("Error Normal")
            
            ErrorStateWatch(message: "Fehler", compact: true)
                .previewDisplayName("Error Compact")
            
            EmptyStateWatch(
                icon: "star",
                title: "Keine Favoriten",
                subtitle: "Fügen Sie Stationen zu Ihren Favoriten hinzu",
                action: {},
                actionTitle: "Station suchen"
            )
            .previewDisplayName("Empty State")
            
            VStack {
                DepartureSkeletonWatch()
                DepartureSkeletonWatch()
                DepartureSkeletonWatch()
            }
            .previewDisplayName("Departure Skeleton")
            
            FavoriteSkeletonWatch()
                .previewDisplayName("Favorite Skeleton")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif