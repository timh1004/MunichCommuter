import SwiftUI
import MunichCommuterKit

struct PlatformPickerView: View {
    let platforms: [String]
    @Binding var selectedPlatforms: [String]
    @Binding var isPresented: Bool
    var title: String = "Gleise auswählen"
    var emptyText: String = "Keine Gleise verfügbar"
    var emptySubtext: String = "Laden Sie zuerst Abfahrtsdaten"
    var accentColor: Color = .orange
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                if platforms.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: "train.side.front.car")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text(emptyText)
                            .font(.headline)
                        Text(emptySubtext)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Gleis suchen...", text: $searchText)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Selected platforms summary
                    if !selectedPlatforms.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ausgewählte Gleise (\(selectedPlatforms.count))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(selectedPlatforms, id: \.self) { platform in
                                            HStack(spacing: 4) {
                                                Text("Gleis \(platform)")
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                Button(action: {
                                                    selectedPlatforms.removeAll { $0 == platform }
                                                }) {
                                                    Image(systemName: "xmark")
                                                        .font(.caption2)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(accentColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                    }
                    
                    // Platforms List
                    List(filteredPlatforms, id: \.self) { platform in
                        Button(action: {
                            togglePlatformSelection(platform)
                        }) {
                            HStack {
                                Text("Gleis \(platform)")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)

                                Spacer()
                                
                                if selectedPlatforms.contains(platform) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(accentColor)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !selectedPlatforms.isEmpty {
                            Button("Alle löschen") {
                                selectedPlatforms.removeAll()
                            }
                            .foregroundColor(.red)
                        }
                        
                        Button("Fertig") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private var filteredPlatforms: [String] {
        if searchText.isEmpty {
            return PlatformHelper.sortPlatforms(platforms)
        } else {
            let filtered = platforms.filter { $0.localizedCaseInsensitiveContains(searchText) }
            return PlatformHelper.sortPlatforms(filtered)
        }
    }
    
    private func togglePlatformSelection(_ platform: String) {
        if selectedPlatforms.contains(platform) {
            selectedPlatforms.removeAll { $0 == platform }
        } else {
            selectedPlatforms.append(platform)
        }
    }
} 