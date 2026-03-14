# München Commuter Watch App

Eine vollständige Apple Watch App für öffentliche Verkehrsmittel in München, basierend auf der MVV API.

## 🚀 Features

### Kern-Funktionalitäten
- **📍 Favoriten-Management**: Anzeige und Verwaltung gespeicherter Haltestellen
- **🚃 Live-Abfahrten**: Echtzeit-Abfahrtszeiten von MVV API
- **📱 iPhone-Synchronisation**: Favoriten werden automatisch zwischen iPhone und Watch synchronisiert
- **🗺️ Standort-Services**: GPS-basierte Entfernungsberechnung und nahegelegene Stationen
- **💾 Offline-Caching**: Lokale Datenpersistierung für bessere Performance

### Watch-spezifische Features
- **🔄 Digital Crown Navigation**: Smooth Scrolling durch Listen
- **📳 Haptic Feedback**: Bestätigungen und Alerts
- **🔄 Pull-to-Refresh**: Aktualisierung der Abfahrtsdaten
- **⚡ Background Refresh**: Automatische Datenaktualisierung im Hintergrund
- **🔋 Batterieoptimierung**: Intelligente Location Updates und Caching

## 📱 App-Struktur

```
MunichCommuterWatch/
├── MunichCommuterWatch.xcodeproj
├── MunichCommuterWatch WatchKit App/           # Watch App Container
│   └── Info.plist
├── MunichCommuterWatch WatchKit Extension/     # Haupt-App-Logik
│   ├── MunichCommuterWatchApp.swift           # App Entry Point
│   ├── ContentView.swift                       # Tab Navigation
│   ├── ExtensionDelegate.swift                 # Background Tasks
│   ├── Views/                                  # UI Views
│   │   ├── FavoritesWatchView.swift
│   │   ├── DepartureDetailWatchView.swift
│   │   ├── StationSearchWatchView.swift
│   │   └── SettingsWatchView.swift
│   ├── Components/                             # UI Komponenten
│   │   ├── CompactDepartureRow.swift
│   │   └── WatchLoadingStates.swift
│   ├── Services/                               # API Services
│   │   └── WatchMVVService.swift
│   └── Managers/                               # Data Managers
│       ├── WatchLocationManager.swift
│       └── WatchFavoritesManager.swift
└── Shared/                                     # Shared Code
    ├── Models/                                 # Data Models
    │   ├── WatchTransportType.swift
    │   ├── WatchModels.swift
    │   ├── WatchDeparture.swift
    │   └── WatchLocationModels.swift
    └── Extensions/
        └── String+Extensions.swift
```

## 🎨 UI-Komponenten

### Haupt-Views
- **FavoritesWatchView**: Kompakte Favoriten-Liste mit Live-Abfahrten für die ersten 3 Favoriten
- **DepartureDetailWatchView**: Vollständige Abfahrtsliste für eine Station mit Filtern
- **StationSearchWatchView**: Vereinfachte Stationssuche mit Nearby-Funktion
- **SettingsWatchView**: App-Einstellungen und Synchronisation

### UI-Komponenten
- **CompactDepartureRow**: Mini-Abfahrtsanzeige für Favoriten
- **TransportBadgeWatch**: Kleine Transport-Icons mit Liniennummern
- **LoadingIndicatorWatch**: Watch-optimierte Loading States
- **EmptyStateWatch**: Leere Zustände für verschiedene Screens

## 🔧 Services & Manager

### WatchMVVService
- MVV API Integration für Live-Daten
- Intelligentes Caching (5 Minuten)
- Separate API-Modelle für Watch
- Fehlerbehandlung und Retry-Logic

### WatchLocationManager
- GPS und Entfernungsberechnung
- Batterieoptimierte Location Updates
- Throttled Updates (30 Sekunden Minimum)
- Genauigkeits-/Batterie-Modi

### WatchFavoritesManager
- Favoriten-Persistierung (UserDefaults + App Group)
- iPhone-Watch Synchronisation via WatchConnectivity
- Sorting (Alphabetisch/Entfernung)
- Background-Sync

## 📊 Datenmodelle

### WatchLocation
```swift
struct WatchLocation: Codable, Identifiable, Equatable {
    let id: String
    let name: String?
    let disassembledName: String?
    let coord: [Double]?
    let parent: WatchLocationParent?
    let distance: Int?
}
```

### WatchDeparture
```swift
struct WatchDeparture: Codable, Identifiable {
    let lineName: String?
    let lineNumber: String?
    let destination: String?
    let departureTime: String?
    let estimatedTime: String?
    let platform: String?
    let transportType: WatchTransportType?
    let delay: Int?
    let isRealtime: Bool
}
```

### WatchFavorite
```swift
struct WatchFavorite: Codable, Identifiable {
    let id: UUID
    let location: WatchLocation
    let destinationFilters: [String]?
    let platformFilters: [String]?
    let transportTypeFilters: [String]?
    let dateCreated: Date
}
```

## ⚙️ Konfiguration

### Build Settings
- **Deployment Target**: watchOS 9.0+
- **Bundle ID**: `com.yourcompany.munichcommuter.watchkitapp.watchkitextension`
- **Companion App**: `com.yourcompany.munichcommuter`

### Capabilities
- **Location Services**: Für nahegelegene Stationen
- **Background App Refresh**: Für Live-Datenupdates
- **App Groups**: `group.com.yourcompany.munichcommuter`
- **Watch Connectivity**: iPhone-Watch Synchronisation

### Permissions
- **NSLocationWhenInUseUsageDescription**: "Diese App benötigt Ihren Standort, um nahegelegene Haltestellen zu finden und Entfernungen zu berechnen."

## 🔄 Background Tasks

### Background Refresh
- Automatische Aktualisierung alle 15 Minuten
- Update der Top-3 Favoriten
- Batterieoptimierter Modus (30 Minuten)

### Watch Connectivity
- Automatische Favoriten-Synchronisation
- Bidirektionale Datenübertragung
- Offline-Fallback

## 📱 Performance-Optimierungen

### Caching-Strategie
- **Departures**: 5 Minuten Cache
- **Locations**: Session-basiert
- **Favorites**: Persistent (UserDefaults + App Group)

### Battery Optimization
- Throttled Location Updates (30s minimum)
- Reduced Location Accuracy Modus
- Background Task Scheduling
- Lazy Loading von UI-Komponenten

### Network Optimization
- Minimale API-Aufrufe
- Request Deduplication
- Timeout und Retry-Logic
- Offline-Error-Handling

## 🎯 Accessibility

- **VoiceOver Support**: Alle UI-Elemente vollständig zugänglich
- **Large Type Support**: Skalierbare Schriftgrößen
- **Haptic Feedback**: Für wichtige Aktionen
- **High Contrast**: Unterstützung für bessere Sichtbarkeit

## 🧪 Testing

### Unit Tests
- Service-Layer Tests
- Data Model Tests
- Manager Logic Tests

### UI Tests
- Navigation Flow Tests
- Critical User Journey Tests
- Accessibility Tests

### Performance Tests
- API Response Time Tests
- Battery Impact Tests
- Memory Usage Tests

## 🚀 Installation & Setup

1. **Projekt öffnen**:
   ```bash
   open MunichCommuterWatch.xcodeproj
   ```

2. **Development Team setzen**:
   - In Xcode: Project Settings > Signing & Capabilities
   - Development Team für beide Targets setzen

3. **Bundle IDs anpassen**:
   - Watch App: `com.yourcompany.munichcommuter.watchkitapp`
   - Watch Extension: `com.yourcompany.munichcommuter.watchkitapp.watchkitextension`

4. **App Group konfigurieren**:
   - Capabilities > App Groups
   - Group ID: `group.com.yourcompany.munichcommuter`

5. **Build & Run**:
   - Target: Watch App auswählen
   - Simulator oder verbundene Apple Watch

## 🔧 Entwicklung

### Requirement
- Xcode 15.0+
- watchOS 9.0+ Deployment Target
- iOS 16.0+ (für iPhone Companion App)

### API Dependencies
- MVG API: `https://www.mvg.de/api/fib/v2`
- Keine externen Abhängigkeiten/Frameworks

### Code Style
- SwiftUI + Combine
- MVVM Architecture
- Async/Await für Network Calls
- ObservableObject für State Management

## 📋 TODO / Roadmap

### Nächste Features
- [ ] Complications für Watch Face
- [ ] Favoriten-Widgets
- [ ] Push Notifications für Störungen
- [ ] Offline-Karten-Integration
- [ ] Erweiterte Filter-Optionen

### Verbesserungen
- [ ] Animationen optimieren
- [ ] Weitere Accessibility-Features
- [ ] Lokalisierung (EN/DE)
- [ ] Performance-Monitoring
- [ ] Crash-Reporting

## 🐛 Bekannte Issues

- Watch Connectivity kann bei schwacher Bluetooth-Verbindung versagen
- Background Refresh ist system-abhängig und nicht garantiert
- Location Permission muss explizit gewährt werden

## 📄 Lizenz

© 2024 München Commuter. Alle Rechte vorbehalten.

Daten bereitgestellt von MVG (Münchner Verkehrs- und Tarifverbund).

---

**Hinweis**: Diese App ist nicht offiziell von der MVG unterstützt oder entwickelt. Sie nutzt öffentlich verfügbare APIs für Fahrgastinformationen.