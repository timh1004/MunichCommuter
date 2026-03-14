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
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        let netzplaene = MVGPlansData.networkPlans.filter { $0.category == .netzplaene }
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(netzplaene) { plan in
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
        .padding(.horizontal, 4)
    }
}

// MARK: - Plan Card Label (compact card for grid)

struct PlanCardLabel: View {
    let plan: MVGNetworkPlan
    var showChevron: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: plan.icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(plan.category.color)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(plan.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(showChevron ? 12 : 0)
        .background(showChevron ? Color(.secondarySystemGroupedBackground) : Color.clear)
        .cornerRadius(showChevron ? 12 : 0)
    }
}

// MARK: - "More Plans" Card

struct MorePlansCard: View {
    var showChevron: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color(.systemGray3))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Alle Pläne")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Übersicht auf MVG.de")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(showChevron ? 12 : 0)
        .background(showChevron ? Color(.secondarySystemGroupedBackground) : Color.clear)
        .cornerRadius(showChevron ? 12 : 0)
    }
}

// MARK: - Station Plans Sheet (for DepartureDetailView)

struct StationPlansSheet: View {
    let stationName: String
    let locationId: String?
    let plans: [MVGStationPlan]
    @State private var zdmAbbreviation: String?
    @State private var aushangEntries: [MVGPlansData.AushangEntry] = []
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    
    private var contextMapEntry: MVGPlansData.AushangEntry? {
        aushangEntries.first { $0.scheduleKind == "CONTEXT_MAP" }
    }
    
    private var stationOverviewEntry: MVGPlansData.AushangEntry? {
        aushangEntries.first { $0.scheduleKind == "STATION_OVERVIEW_MAP" }
    }
    
    private var linePlans: [MVGPlansData.AushangEntry] {
        aushangEntries.filter { ["SUBWAY", "TRAM", "BUS", "NIGHT_LINE"].contains($0.scheduleKind) }
    }
    
    var body: some View {
        NavigationView {
            List {
                if !aushangEntries.isEmpty {
                    Section(header: Text("Umgebungsplan & Übersicht")) {
                        if let entry = contextMapEntry, let url = entry.url {
                            NavigationLink(destination: PDFViewerView(title: entry.displayTitle, url: url)) {
                                AushangEntryRow(entry: entry)
                            }
                        }
                        if let entry = stationOverviewEntry, let url = entry.url {
                            NavigationLink(destination: PDFViewerView(title: entry.displayTitle, url: url)) {
                                AushangEntryRow(entry: entry)
                            }
                        }
                    }
                    
                    if !linePlans.isEmpty {
                        Section(header: Text("Linienfahrpläne")) {
                            ForEach(linePlans) { entry in
                                if let url = entry.url {
                                    NavigationLink(destination: PDFViewerView(title: "\(entry.scheduleName) – \(entry.direction ?? "")", url: url)) {
                                        AushangEntryRow(entry: entry)
                                    }
                                }
                            }
                        }
                    }
                    
                    let externalPlans = plans.filter { $0.url.pathExtension.lowercased() != "pdf" }
                    if !externalPlans.isEmpty {
                        Section(header: Text("Links")) {
                            ForEach(externalPlans) { plan in
                                Button {
                                    openURL(plan.url)
                                } label: {
                                    StationPlanRow(plan: plan, isExternal: true)
                                }
                            }
                        }
                    }
                } else if !plans.isEmpty {
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
            .task {
                guard let id = locationId else { return }
                zdmAbbreviation = await MVGPlansData.fetchStationAbbreviation(locationId: id)
                if let abbr = zdmAbbreviation {
                    aushangEntries = await MVGPlansData.fetchAushangPlans(abbreviation: abbr)
                }
            }
        }
    }
}

// MARK: - Aushang Entry Row (API-Pläne)

struct AushangEntryRow: View {
    let entry: MVGPlansData.AushangEntry
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(MVGNetworkPlan.PlanCategory.netzplaene.color)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                if let subtitle = entry.displaySubtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
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
        locationId: "de:09162:50",
        plans: MVGPlansData.stationPlans(for: "Marienplatz")
    )
}
