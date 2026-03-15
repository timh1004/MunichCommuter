import SwiftUI
import MunichCommuterKit

struct DestinationPickerView: View {
    let destinations: [String]
    @Binding var selectedDestinations: [String]
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                if destinations.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: "location.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Keine Ziele verfügbar")
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
                        TextField("Ziel suchen...", text: $searchText)
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
                    
                    // Selected destinations summary
                    if !selectedDestinations.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ausgewählte Ziele (\(selectedDestinations.count))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(selectedDestinations, id: \.self) { destination in
                                            HStack(spacing: 4) {
                                                Text(destination)
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                Button(action: {
                                                    selectedDestinations.removeAll { $0 == destination }
                                                }) {
                                                    Image(systemName: "xmark")
                                                        .font(.caption2)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue)
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
                    
                    // Destinations List
                    List(filteredDestinations, id: \.self) { destination in
                        Button(action: {
                            toggleDestinationSelection(destination)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(destination)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    
                                    if selectedDestinations.contains(destination) {
                                        Text("Ausgewählt")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedDestinations.contains(destination) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
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
            .navigationTitle("Ziele auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !selectedDestinations.isEmpty {
                            Button("Alle löschen") {
                                selectedDestinations.removeAll()
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
    
    private var filteredDestinations: [String] {
        if searchText.isEmpty {
            return destinations
        } else {
            return destinations.filter { 
                $0.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
    
    private func toggleDestinationSelection(_ destination: String) {
        if selectedDestinations.contains(destination) {
            selectedDestinations.removeAll { $0 == destination }
        } else {
            selectedDestinations.append(destination)
        }
    }
} 