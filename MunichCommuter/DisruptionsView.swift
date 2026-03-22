import SwiftUI
import MunichCommuterKit

struct DisruptionsView: View {
    @EnvironmentObject private var disruptionService: DisruptionService
    @State private var selectedProducts: Set<DisruptionProductType> = Set(DisruptionProductType.allCases)
    @State private var selectedType: String? = nil // nil = Alle, "INCIDENT", "SCHEDULE_CHANGES"

    private var filteredMessages: [DisruptionMessage] {
        disruptionService.messages.filter { message in
            // Type filter
            if let type = selectedType, message.type != type {
                return false
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
                            if selectedProducts.contains(product) {
                                selectedProducts.remove(product)
                                if selectedProducts.isEmpty {
                                    selectedProducts = Set(DisruptionProductType.allCases)
                                }
                            } else {
                                selectedProducts.insert(product)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // Type segmented picker
            Picker("Typ", selection: $selectedType) {
                Text("Alle").tag(nil as String?)
                Text("Störungen").tag("INCIDENT" as String?)
                Text("Änderungen").tag("SCHEDULE_CHANGES" as String?)
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
                    Text("Aktuell liegen keine Meldungen für die gewählten Filter vor.")
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
            if disruptionService.messages.isEmpty || disruptionService.lastFetchAt?.isOlder(thanMinutes: 5) == true {
                disruptionService.loadMessages()
            }
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
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? product.color : Color.clear, lineWidth: 1.5)
            )
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
