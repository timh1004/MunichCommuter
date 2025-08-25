import SwiftUI

struct PlatformPickerView: View {
    let platforms: [String]
    @Binding var selectedPlatforms: [String]
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if platforms.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: "train.side.front.car")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Keine Gleise verfügbar")
                            .font(.headline)
                        Text("Laden Sie zuerst Abfahrtsdaten")
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
                                            .background(Color.orange)
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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Gleis \(platform)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    
                                    if selectedPlatforms.contains(platform) {
                                        Text("Ausgewählt")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedPlatforms.contains(platform) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.orange)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Gleise auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        isPresented = false
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
                            isPresented = false
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