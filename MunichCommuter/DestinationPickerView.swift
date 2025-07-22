import SwiftUI

struct DestinationPickerView: View {
    let destinations: [String]
    @Binding var selectedDestination: String
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
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
                    
                    // Destinations List
                    List(filteredDestinations, id: \.self) { destination in
                        Button(action: {
                            selectedDestination = destination
                            isPresented = false
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(destination)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    
                                    if destination == selectedDestination {
                                        Text("Aktuell ausgewählt")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Spacer()
                                
                                if destination == selectedDestination {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Ziel auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        isPresented = false
                    }
                }
                
                if !selectedDestination.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Löschen") {
                            selectedDestination = ""
                            isPresented = false
                        }
                        .foregroundColor(.red)
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
} 