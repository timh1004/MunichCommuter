import Foundation

struct PlatformHelper {
    // Returns best available platform name with priority: platformName -> plannedPlatformName -> platform
    static func effectivePlatform(from platformProps: PlatformProperties?) -> String? {
        return platformProps?.platformName
            ?? platformProps?.plannedPlatformName
            ?? platformProps?.platform
    }
    
    // Sorts platform strings numerically when possible, otherwise alphabetically
    static func sortPlatforms(_ platforms: [String]) -> [String] {
        return platforms.sorted { p1, p2 in
            if let n1 = Int(p1), let n2 = Int(p2) {
                return n1 < n2
            }
            return p1.localizedCaseInsensitiveCompare(p2) == .orderedAscending
        }
    }
}


