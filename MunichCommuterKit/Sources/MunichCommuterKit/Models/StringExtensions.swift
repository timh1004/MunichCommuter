import Foundation

extension String {
    /// Normalizes MVV station IDs to use the base station ID.
    /// "de:09162:150:3:3" -> "de:09162:150"
    public var normalizedStationId: String {
        let components = self.components(separatedBy: ":")
        if components.count >= 3 {
            return "\(components[0]):\(components[1]):\(components[2])"
        }
        return self
    }
}
