import AppIntents
import MunichCommuterKit

// MARK: - FavoriteEntity

struct FavoriteEntity: AppEntity, Sendable {
    let id: UUID
    let displayName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Haltestelle"
    static var defaultQuery = FavoriteEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }
}

// MARK: - FavoriteEntityQuery

struct FavoriteEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [FavoriteEntity] {
        loadFavoritesFromCloudStore()
            .filter { identifiers.contains($0.id) }
            .map { FavoriteEntity(id: $0.id, displayName: $0.displayName) }
    }

    func suggestedEntities() async throws -> [FavoriteEntity] {
        loadFavoritesFromCloudStore()
            .map { FavoriteEntity(id: $0.id, displayName: $0.displayName) }
    }
}

// MARK: - SelectFavoriteIntent

struct SelectFavoriteIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Haltestelle auswählen"
    static var description = IntentDescription("Wähle eine Haltestelle aus deinen Favoriten.")

    @Parameter(title: "Nächste Haltestelle", default: true)
    var useNearest: Bool

    @Parameter(title: "Haltestelle")
    var favorite: FavoriteEntity?

    static var parameterSummary: some ParameterSummary {
        When(\.$useNearest, .equalTo, true) {
            Summary("Nächste Haltestelle") {
                \.$useNearest
            }
        } otherwise: {
            Summary("Abfahrten von \(\.$favorite)") {
                \.$useNearest
            }
        }
    }
}
