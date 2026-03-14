import SwiftUI

// MARK: - Network Plans Overview (Standalone)

struct PlansOverviewView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        List {
            ForEach(MVGNetworkPlan.PlanCategory.allCases, id: \.rawValue) { category in
                let plans = MVGPlansData.networkPlans.filter { $0.category == category }
                if !plans.isEmpty {
                    Section(header: Text(category.rawValue)) {
                        ForEach(plans) { plan in
                            Button {
                                openURL(plan.url)
                            } label: {
                                NetworkPlanRow(plan: plan)
                            }
                        }
                    }
                }
            }
            
            Section {
                Button {
                    openURL(MVGPlansData.fahrplaeneNetzplaeneURL)
                } label: {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Alle Pläne auf MVG.de")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Fahrpläne, Netzpläne & mehr")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Pläne")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Network Plan Row

struct NetworkPlanRow: View {
    let plan: MVGNetworkPlan
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: plan.icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(iconColor(for: plan.category))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Text(plan.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func iconColor(for category: MVGNetworkPlan.PlanCategory) -> Color {
        switch category {
        case .netzplaene:
            return Color(red: 0/255, green: 101/255, blue: 189/255)
        case .linienplaene:
            return Color(red: 0/255, green: 142/255, blue: 78/255)
        case .barrierefreiheit:
            return Color(red: 0/255, green: 87/255, blue: 106/255)
        }
    }
}

// MARK: - Compact Plans Section (for embedding in StationsView)

struct PlansCompactSection: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                
                Text("Pläne & Netzpläne")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MVGPlansData.networkPlans.filter { $0.category == .netzplaene }) { plan in
                        PlanCard(plan: plan) {
                            openURL(plan.url)
                        }
                    }
                    
                    NavigationLink(destination: PlansOverviewView()) {
                        MorePlansCard()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Plan Card (for horizontal scroll)

struct PlanCard: View {
    let plan: MVGNetworkPlan
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: plan.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(cardColor)
                    .cornerRadius(12)
                
                VStack(spacing: 2) {
                    Text(plan.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text(plan.subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 90)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var cardColor: Color {
        switch plan.category {
        case .netzplaene:
            return Color(red: 0/255, green: 101/255, blue: 189/255)
        case .linienplaene:
            return Color(red: 0/255, green: 142/255, blue: 78/255)
        case .barrierefreiheit:
            return Color(red: 0/255, green: 87/255, blue: 106/255)
        }
    }
}

// MARK: - "More Plans" Card

struct MorePlansCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color(.systemGray3))
                .cornerRadius(12)
            
            VStack(spacing: 2) {
                Text("Alle Pläne")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text("Übersicht")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 90)
    }
}

// MARK: - Station Plans Sheet (for DepartureDetailView)

struct StationPlansSheet: View {
    let stationName: String
    let plans: [MVGStationPlan]
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if !plans.isEmpty {
                    Section(header: Text("Haltestellenpläne")) {
                        ForEach(plans) { plan in
                            Button {
                                openURL(plan.url)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: plan.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color(red: 0/255, green: 101/255, blue: 189/255))
                                        .cornerRadius(8)
                                    
                                    Text(plan.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                
                Section(header: Text("Netzpläne")) {
                    ForEach(Array(MVGPlansData.networkPlans.prefix(4))) { plan in
                        Button {
                            openURL(plan.url)
                        } label: {
                            NetworkPlanRow(plan: plan)
                        }
                    }
                }
                
                Section {
                    Button {
                        openURL(MVGPlansData.fahrplaeneNetzplaeneURL)
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                            
                            Text("Alle Pläne auf MVG.de")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Pläne")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Plans Overview") {
    NavigationView {
        PlansOverviewView()
    }
}

#Preview("Compact Section") {
    NavigationView {
        VStack {
            PlansCompactSection()
            Spacer()
        }
    }
}

#Preview("Station Plans Sheet") {
    StationPlansSheet(
        stationName: "Marienplatz",
        plans: MVGPlansData.stationPlans(for: "Marienplatz")
    )
}
