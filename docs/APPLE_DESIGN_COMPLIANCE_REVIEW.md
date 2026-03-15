# Apple Design Compliance Review - MunichCommuter

## Summary

Review of MunichCommuter iOS & watchOS app against Apple's Human Interface Guidelines (HIG) and modern SwiftUI best practices. Issues are categorized by severity.

---

## Critical Issues

### 1. `NavigationView` is deprecated (iOS 16+)
**Files:** `MainTabView.swift`, `StationPlansSheet.swift`, `PlatformPickerView.swift`, `DestinationPickerView.swift`, `PDFViewerView.swift` (preview)
**HIG:** Use `NavigationStack` for stack-based navigation.
**Impact:** Will produce deprecation warnings; may cause unexpected behavior with future iOS releases.
**Fix:** Replace `NavigationView { ... }` with `NavigationStack { ... }` throughout.
**Status:** Fixed in this PR.

### 2. `.accentColor()` is deprecated
**File:** `MainTabView.swift:28`
**HIG:** Use `.tint()` modifier instead.
**Status:** Fixed in this PR.

### 3. Deprecated list style initializer syntax
**Files:** `FavoritesView.swift`, `StationsView.swift`, `DepartureDetailView.swift`, `PlansView.swift`
**Example:** `PlainListStyle()` → `.plain`, `InsetGroupedListStyle()` → `.insetGrouped`
**Status:** Fixed in this PR.

---

## High Priority Issues

### 4. Missing Dynamic Type support
**Files:** Most view files
**Issue:** Hard-coded font sizes via `.font(.system(size: X))` throughout the app instead of using Apple's built-in text styles (`.body`, `.headline`, `.caption`, etc.).
**HIG:** Apps must support Dynamic Type so users with accessibility needs can adjust text size. Hard-coded sizes ignore the user's preferred content size.
**Examples:**
- `FilteredFavoriteRowView`: `.font(.system(size: 16, weight: .medium))` → should be `.font(.body)` or similar
- `DepartureRowView`: `.font(.system(size: 18, weight: .semibold, design: .monospaced))` → consider relative sizes
- `LocationRowView`: `.font(.system(size: 14))` → `.font(.subheadline)`
**Recommendation:** Audit all `.system(size:)` calls and replace with semantic text styles where possible. Use `@ScaledMetric` for custom sizes that must scale.

### 5. Missing accessibility labels
**Files:** `DepartureRowStyling.swift` (TransportBadge, RealtimeBadge), `DepartureDetailView.swift`, `FavoritesView.swift`
**Issue:** Key interactive/informational elements lack `.accessibilityLabel()`:
- `TransportBadge` – VoiceOver reads nothing meaningful for the colored line badge
- `RealtimeBadge` – "Live" dot has no accessibility context
- Sort menu button (arrow.up.arrow.down icon) has no label
- Filter indicator (red dot overlay) has no accessibility indication
**HIG:** All meaningful UI elements must be accessible via VoiceOver.
**Status:** Partially fixed in this PR (TransportBadge, RealtimeBadge, key toolbar buttons).

### 6. Custom search bar instead of `.searchable()`
**File:** `StationsView.swift:73-116`
**Issue:** A fully custom search bar is built from scratch instead of using the native `.searchable()` modifier.
**HIG:** The `.searchable()` modifier provides the standard iOS search experience with proper animations, placement, and accessibility.
**Recommendation:** Migrate to `.searchable(text: $searchText)` on the `NavigationStack`.

---

## Medium Priority Issues

### 7. `@StateObject` used with singletons
**Files:** `FavoritesView.swift`, `StationsView.swift`, `DepartureDetailView.swift`, `MainTabView.swift`
**Issue:** `@StateObject private var locationManager = LocationManager.shared` and similar patterns. `@StateObject` is designed to own and manage the lifecycle of an object. Using it with `.shared` singletons is semantically incorrect.
**Fix:** Use `@ObservedObject` for shared instances, or inject via `@EnvironmentObject`.

### 8. Polling pattern for async loading
**Files:** `FavoritesView.swift:263`, `WatchFavoritesView.swift:139`
**Issue:** `while service.isDeparturesLoading { try? await Task.sleep(...) }` is an anti-pattern.
**Fix:** Use proper async/await or Combine publishers to observe completion.

### 9. Print statements in production code
**Files:** `DepartureDetailView.swift` (lines 573, 583, 594), `PDFViewerView.swift` (lines 129, 205-253)
**Issue:** Multiple `print()` calls that should use `os.Logger` or be removed for production.
**HIG/Best Practice:** Use the unified logging system (`os.Logger`) for debugging output.

### 10. Hard-coded colors
**Files:** Throughout
**Issue:** Direct use of `Color.blue`, `Color.orange`, `Color.gray` instead of semantic colors or asset catalog colors.
**Impact:** While these adapt to Dark Mode via SwiftUI, using custom colors from an asset catalog gives better control and consistency.
**Recommendation:** Define a color palette in the asset catalog for brand colors (e.g., the MVG blue, S-Bahn/U-Bahn line colors).

---

## Low Priority / Cosmetic Issues

### 11. Missing app icon in main target Assets
**File:** `MunichCommuter/Assets.xcassets/`
**Issue:** No `AppIcon.appiconset` found in the main target's asset catalog (only `AccentColor`). The icon appears to be configured via `MunichCommuterIcon.icon`.
**Note:** This may be using the new Xcode 15+ automatic icon generation. Verify it renders correctly across all required sizes.

### 12. Inconsistent empty state patterns
**Files:** `FavoritesView.swift`, `StationsView.swift`, `DepartureDetailView.swift`
**Issue:** Empty states use different layouts and spacing patterns. Some use emoji (e.g., `"🔍"`, `"⭐"`, `"📍"`) while others use SF Symbols consistently.
**HIG:** Empty states should be consistent across the app and avoid emoji in favor of SF Symbols.

### 13. Non-standard sheet dismissal pattern
**Files:** `PlatformPickerView.swift`, `DestinationPickerView.swift`
**Issue:** Sheets use a `@Binding var isPresented: Bool` pattern with manual "Fertig"/"Abbrechen" buttons instead of using `@Environment(\.dismiss)`.
**Recommendation:** Use `@Environment(\.dismiss)` for cleaner sheet dismissal.

---

## Compliance Summary

| Category | Status | Notes |
|---|---|---|
| Navigation (NavigationStack) | Fixed | Migrated from NavigationView |
| Deprecated APIs | Fixed | .accentColor(), list styles |
| Dynamic Type | Needs Work | Hard-coded font sizes throughout |
| Accessibility (VoiceOver) | Partially Fixed | Key labels added; full audit needed |
| Dark Mode | OK | Uses system colors correctly |
| Safe Area | OK | Proper safe area handling |
| Tab Bar | OK | Standard TabView with SF Symbols |
| Pull-to-Refresh | OK | Uses `.refreshable()` |
| Sheets/Modals | OK | Uses `.sheet()` correctly |
| Maps | OK | MKMapView integration is proper |
| watchOS | OK | Native watchOS patterns used |
