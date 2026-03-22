import SwiftUI
import MunichCommuterKit

struct DisruptionsView: View {
    @EnvironmentObject private var disruptionService: DisruptionService
    @State private var selectedProducts: Set<DisruptionProductType> = Set(DisruptionProductType.allCases)
    @State private var selectedType: String? = nil // nil = Alle, "INCIDENT", "SCHEDULE_CHANGE"
    /// Entspricht MVG „Nur aktuelle Meldungen anzeigen“: nur Meldungen, die `isRelevantNow` erfüllen.
    @AppStorage("disruptionsShowOnlyCurrentMessages") private var showOnlyCurrentMessages = true

    private var filteredMessages: [DisruptionMessage] {
        disruptionService.messages.filter { message in
            if showOnlyCurrentMessages, !message.isRelevantNow(at: Date()) {
                return false
            }
            // Type filter (API uses SCHEDULE_CHANGE; keep SCHEDULE_CHANGES for compatibility)
            if let type = selectedType {
                if type == "SCHEDULE_CHANGE" {
                    let isSchedule = message.type == "SCHEDULE_CHANGE" || message.type == "SCHEDULE_CHANGES"
                    if !isSchedule { return false }
                } else if message.type != type {
                    return false
                }
            }
            // Product filter
            if selectedProducts.count < DisruptionProductType.allCases.count {
                let messageProducts = message.affectedProducts
                if messageProducts.isEmpty { return true }
                return !messageProducts.isDisjoint(with: selectedProducts)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Product type filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DisruptionProductType.allCases) { product in
                        ProductFilterChip(
                            product: product,
                            isSelected: selectedProducts.contains(product)
                        ) {
                            handleProductFilterSelection(product)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Toggle("Nur aktuelle Meldungen anzeigen", isOn: $showOnlyCurrentMessages)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // Type segmented picker
            Picker("Typ", selection: $selectedType) {
                Text("Alle").tag(nil as String?)
                Text("Störungen").tag("INCIDENT" as String?)
                Text("Änderungen").tag("SCHEDULE_CHANGE" as String?)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Content
            if disruptionService.isLoading && disruptionService.messages.isEmpty {
                Spacer()
                ProgressView("Lade Störungen…")
                Spacer()
            } else if let error = disruptionService.errorMessage, disruptionService.messages.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray.opacity(0.5))
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else if filteredMessages.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 50))
                        .foregroundStyle(.green.opacity(0.7))
                    Text("Keine Störungen")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text(emptyListHint)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredMessages) { message in
                        NavigationLink(destination: DisruptionDetailView(message: message)) {
                            DisruptionRowView(message: message)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Störungen")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await disruptionService.loadMessagesAsync()
        }
        .onAppear {
            disruptionService.loadMessagesIfStale()
        }
    }

    private var emptyListHint: String {
        if showOnlyCurrentMessages, !disruptionService.messages.isEmpty {
            return "Keine Meldung passt zu den Filtern. Ohne Häkchen bei „Nur aktuelle Meldungen“ siehst du auch geplante und später beginnende Hinweise (wie auf mvg.de)."
        }
        return "Aktuell liegen keine Meldungen für die gewählten Filter vor."
    }

    /// Gleiche Logik wie Verkehrsmittel-Filter bei Abfahrten (`DepartureDetailView.handleTransportTypeSelection`).
    private func handleProductFilterSelection(_ product: DisruptionProductType) {
        let allSelected = selectedProducts.count == DisruptionProductType.allCases.count
        let isCurrentlySelected = selectedProducts.contains(product)

        if allSelected && isCurrentlySelected {
            selectedProducts = [product]
        } else if isCurrentlySelected {
            if selectedProducts.count == 1 {
                selectedProducts = Set(DisruptionProductType.allCases)
            } else {
                selectedProducts.remove(product)
                if selectedProducts.isEmpty {
                    selectedProducts = [product]
                }
            }
        } else {
            selectedProducts.insert(product)
        }
    }
}

// MARK: - Product Filter Chip

private struct ProductFilterChip: View {
    let product: DisruptionProductType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: product.icon)
                    .font(.caption2)
                Text(product.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? product.color.opacity(0.15) : Color(.systemGray6))
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(product.color, lineWidth: 1)
                }
            }
            .foregroundColor(isSelected ? product.color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        DisruptionsView()
            .environmentObject(DisruptionService())
    }
}
