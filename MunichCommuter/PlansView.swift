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
                            NavigationLink(destination: PDFViewerView(title: plan.name, url: plan.url)) {
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
                    ExternalLinkRow(
                        title: "Alle Pläne auf MVG.de",
                        subtitle: "Fahrpläne, Netzpläne & mehr",
                        icon: "globe"
                    )
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
                .background(plan.category.color)
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
        }
        .padding(.vertical, 2)
    }
}

// MARK: - External Link Row

struct ExternalLinkRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    
    init(title: String, subtitle: String? = nil, icon: String = "globe") {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Compact Plans Section (for embedding in StationsView)

struct PlansCompactSection: View {
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
                        NavigationLink(destination: PDFViewerView(title: plan.name, url: plan.url)) {
                            PlanCardLabel(plan: plan)
                        }
                        .buttonStyle(PlainButtonStyle())
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

// MARK: - Plan Card Label (non-interactive display for NavigationLink)

struct PlanCardLabel: View {
    let plan: MVGNetworkPlan
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: plan.icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(plan.category.color)
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
                            if plan.url.pathExtension.lowercased() == "pdf" {
                                NavigationLink(destination: PDFViewerView(title: plan.name, url: plan.url)) {
                                    StationPlanRow(plan: plan)
                                }
                            } else {
                                Button {
                                    openURL(plan.url)
                                } label: {
                                    StationPlanRow(plan: plan, isExternal: true)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Netzpläne")) {
                    ForEach(Array(MVGPlansData.networkPlans.prefix(4))) { plan in
                        NavigationLink(destination: PDFViewerView(title: plan.name, url: plan.url)) {
                            NetworkPlanRow(plan: plan)
                        }
                    }
                }
                
                Section {
                    Button {
                        openURL(MVGPlansData.fahrplaeneNetzplaeneURL)
                    } label: {
                        ExternalLinkRow(
                            title: "Alle Pläne auf MVG.de",
                            subtitle: "Fahrpläne, Netzpläne & mehr"
                        )
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

// MARK: - Station Plan Row

struct StationPlanRow: View {
    let plan: MVGStationPlan
    var isExternal: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: plan.icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(MVGNetworkPlan.PlanCategory.netzplaene.color)
                .cornerRadius(8)
            
            Text(plan.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            if isExternal {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Previews

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
