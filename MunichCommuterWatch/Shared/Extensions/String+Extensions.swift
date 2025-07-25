//
//  String+Extensions.swift
//  MunichCommuterWatch
//
//  Created by AI Assistant
//

import Foundation

extension String {
    /// Normalize station ID for comparison (handle MVG API variations)
    var normalizedStationId: String {
        // Remove common prefixes and suffixes that might vary
        var normalized = self
        
        // Remove "de:" prefix if present
        if normalized.hasPrefix("de:") {
            normalized = String(normalized.dropFirst(3))
        }
        
        // Remove any trailing modifiers
        if let colonIndex = normalized.lastIndex(of: ":") {
            normalized = String(normalized[..<colonIndex])
        }
        
        return normalized
    }
    
    /// Check if string contains search term (case insensitive, diacritic insensitive)
    func localizedCaseInsensitiveContains(_ searchTerm: String) -> Bool {
        return self.range(of: searchTerm, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
    
    /// Truncate string to maximum length with ellipsis
    func truncated(to maxLength: Int) -> String {
        guard self.count > maxLength else { return self }
        return String(self.prefix(maxLength - 1)) + "…"
    }
    
    /// Clean station name for display (remove redundant parts)
    var cleanedStationName: String {
        var cleaned = self
        
        // Remove common suffixes
        let suffixesToRemove = [
            ", München",
            " (München)",
            ", Munich",
            " (Munich)"
        ]
        
        for suffix in suffixesToRemove {
            if cleaned.hasSuffix(suffix) {
                cleaned = String(cleaned.dropLast(suffix.count))
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Optional where Wrapped == String {
    /// Safe unwrapping with fallback
    func orEmpty() -> String {
        return self ?? ""
    }
    
    /// Check if string is nil or empty
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}