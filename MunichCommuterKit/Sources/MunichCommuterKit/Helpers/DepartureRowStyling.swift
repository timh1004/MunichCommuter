import SwiftUI
import Foundation

// MARK: - Line badge (fill + Vordergrund; U7/U8 diagonal U1/U2 bzw. U2/U3)

public struct LineBadgeAppearance: Equatable, Sendable {
    public enum Background: Equatable, Sendable {
        case solid(Color)
        /// Diagonale von unten links nach oben rechts: Farbe „oben links“ (U1/U2), „unten rechts“ (U2/U3).
        case diagonalTopLeftBottomRight(topLeft: Color, bottomTrailing: Color)
    }

    public var background: Background
    public var foreground: Color

    public init(background: Background, foreground: Color) {
        self.background = background
        self.foreground = foreground
    }

    /// Eine einfache Füllfarbe für Widgets/Listen, die keinen Verlauf zeichnen (z. B. erste Diagonalfarbe).
    public var fallbackSolidFillColor: Color {
        switch background {
        case .solid(let color):
            return color
        case .diagonalTopLeftBottomRight(let topLeft, _):
            return topLeft
        }
    }
}

public struct DepartureRowStyling {

    /// Farben aus MVG-Web (`/.resources/mvg-wastl/web/dist/index~*.cache.css`, `:root` `--background-color-*`).
    /// U7/U8: diagonaler Mix aus U1+U2 bzw. U2+U3 (MVG-Linienlogik).
    private enum MVGLinePalette {
        static func rgb(_ hex: UInt32) -> Color {
            Color(
                red: Double((hex >> 16) & 0xFF) / 255,
                green: Double((hex >> 8) & 0xFF) / 255,
                blue: Double(hex & 0xFF) / 255
            )
        }

        static let u1 = rgb(0x52822F)
        static let u2 = rgb(0xC20831)
        static let u3 = rgb(0xEC6726)
        static let u4 = rgb(0x00A984)
        static let u5 = rgb(0xBB7A00)
        static let u6 = rgb(0x0065AD)
        static let uDefault = u6

        static let s1 = rgb(0x1B9FC6)
        static let s2 = rgb(0x69A338)
        static let s3 = rgb(0x973083)
        static let s4 = rgb(0xE23331)
        static let s5 = rgb(0x136680)
        static let s6 = rgb(0x008D5E)
        static let s7 = rgb(0x883B32)
        static let s8 = rgb(0x2D2B29)
        static let s8Foreground = rgb(0xFDCE32)
        static let s20 = rgb(0xF05A73)
        static let sDefault = s1

        static let sev = rgb(0x95368C)
        /// `--wa-red-100` (Tram-Badges auf mvg.de)
        static let tram = rgb(0xD33137)
        /// `.wa-g-iconlist--bus` — immer dieser Grundton für Busse (Nachtlinien separat).
        static let bus = rgb(0x00586A)
        static let regionalBahn = rgb(0x32367F)

        static let nightLineBackground = rgb(0x000000)
        static let nightLineForeground = rgb(0xFFB800)
    }

    // MARK: - Badge appearance (Quelle für alle Linien-Chips)

    public static func lineBadgeAppearance(for departure: StopEvent) -> LineBadgeAppearance {
        let number = (departure.transportation?.number ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let productClass = departure.transportation?.product?.productClass
        let productName = departure.transportation?.product?.name ?? ""

        if isNightTramOrBusLine(number: number, productClass: productClass, productName: productName) {
            return LineBadgeAppearance(
                background: .solid(MVGLinePalette.nightLineBackground),
                foreground: MVGLinePalette.nightLineForeground
            )
        }

        switch productClass {
        case 1:
            return lineBadgeAppearanceSBAHN(lineNumber: number)
        case 2:
            return lineBadgeAppearanceUBAHN(lineNumber: number)
        case 4:
            return LineBadgeAppearance(background: .solid(MVGLinePalette.tram), foreground: .white)
        case 3, 5, 6:
            return LineBadgeAppearance(background: .solid(MVGLinePalette.bus), foreground: .white)
        default:
            let lower = productName.lowercased()
            if lower.contains("tram") {
                return LineBadgeAppearance(background: .solid(MVGLinePalette.tram), foreground: .white)
            }
            if lower.contains("bus") {
                return LineBadgeAppearance(background: .solid(MVGLinePalette.bus), foreground: .white)
            }
            return LineBadgeAppearance(
                background: .solid(Color(red: 0.6, green: 0.6, blue: 0.6)),
                foreground: .white
            )
        }
    }

    /// Störungszeilen: `product` = API `transportType` (z. B. UBAHN, TRAM).
    public static func lineBadgeAppearance(lineNumber: String, apiProduct: String) -> LineBadgeAppearance {
        let number = lineNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let prod = apiProduct.uppercased()

        if isNightTramOrBusLine(number: number, productClass: nil, productName: prod, isDisruptionAPIProduct: true) {
            return LineBadgeAppearance(
                background: .solid(MVGLinePalette.nightLineBackground),
                foreground: MVGLinePalette.nightLineForeground
            )
        }

        switch prod {
        case "UBAHN":
            return lineBadgeAppearanceUBAHN(lineNumber: number)
        case "SBAHN":
            return lineBadgeAppearanceSBAHN(lineNumber: number)
        case "TRAM":
            return LineBadgeAppearance(background: .solid(MVGLinePalette.tram), foreground: .white)
        case "BUS", "REGIONAL_BUS":
            return LineBadgeAppearance(background: .solid(MVGLinePalette.bus), foreground: .white)
        case "BAHN":
            if number.uppercased() == "SEV" {
                return LineBadgeAppearance(background: .solid(MVGLinePalette.sev), foreground: .white)
            }
            return LineBadgeAppearance(background: .solid(MVGLinePalette.regionalBahn), foreground: .white)
        default:
            return LineBadgeAppearance(
                background: .solid(Color(red: 0.6, green: 0.6, blue: 0.6)),
                foreground: .white
            )
        }
    }

    private static func lineBadgeAppearanceSBAHN(lineNumber: String) -> LineBadgeAppearance {
        let bg = sBahnColorForNumber(lineNumber)
        if lineNumber.uppercased() == "S8" {
            return LineBadgeAppearance(background: .solid(bg), foreground: MVGLinePalette.s8Foreground)
        }
        return LineBadgeAppearance(background: .solid(bg), foreground: .white)
    }

    private static func lineBadgeAppearanceUBAHN(lineNumber: String) -> LineBadgeAppearance {
        let key = normalizedUBahnLineKey(lineNumber)
        switch key {
        case "U7":
            return LineBadgeAppearance(
                background: .diagonalTopLeftBottomRight(topLeft: MVGLinePalette.u1, bottomTrailing: MVGLinePalette.u2),
                foreground: .white
            )
        case "U8":
            return LineBadgeAppearance(
                background: .diagonalTopLeftBottomRight(topLeft: MVGLinePalette.u2, bottomTrailing: MVGLinePalette.u3),
                foreground: .white
            )
        default:
            return LineBadgeAppearance(background: .solid(uBahnColorForUBahnKey(key)), foreground: .white)
        }
    }

    /// Nachtlinien: z. B. N27 — nur Tram/Bus, nicht S- oder U-Bahn.
    private static func isNightTramOrBusLine(
        number: String,
        productClass: Int?,
        productName: String,
        isDisruptionAPIProduct: Bool = false
    ) -> Bool {
        let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: "^N\\w", options: [.regularExpression, .caseInsensitive]) != nil else {
            return false
        }

        if isDisruptionAPIProduct {
            return productName == "TRAM" || productName == "BUS" || productName == "REGIONAL_BUS"
        }

        if productClass == 1 || productClass == 2 { return false }

        let lower = productName.lowercased()
        if lower.contains("s-bahn") || lower.contains("sbahn") { return false }
        if lower.contains("u-bahn") || lower.contains("ubahn") { return false }

        if productClass == 4 || productClass == 3 || productClass == 5 || productClass == 6 { return true }
        if lower.contains("tram") || lower.contains("bus") { return true }
        return productClass == nil
    }

    private static func normalizedUBahnLineKey(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t.hasPrefix("U"), t.count >= 2 { return t }
        if t.count == 1, let d = Int(t), (1 ... 8).contains(d) { return "U\(d)" }
        if let d = Int(t), (1 ... 8).contains(d) { return "U\(d)" }
        return t.hasPrefix("U") ? t : "U\(t)"
    }

    private static func uBahnColorForUBahnKey(_ key: String) -> Color {
        switch key {
        case "U1": return MVGLinePalette.u1
        case "U2": return MVGLinePalette.u2
        case "U3": return MVGLinePalette.u3
        case "U4": return MVGLinePalette.u4
        case "U5": return MVGLinePalette.u5
        case "U6": return MVGLinePalette.u6
        default: return MVGLinePalette.uDefault
        }
    }

    // MARK: - Main Line Color Logic
    public static func lineColor(for departure: StopEvent) -> Color {
        lineBadgeAppearance(for: departure).fallbackSolidFillColor
    }

    // MARK: - S-Bahn Specific Colors
    public static func sBahnLineColor(for departure: StopEvent) -> Color {
        guard let lineNumber = departure.transportation?.number else {
            return MVGLinePalette.sDefault
        }

        switch lineNumber {
        case "SEV": return MVGLinePalette.sev
        case "S1": return MVGLinePalette.s1
        case "S2": return MVGLinePalette.s2
        case "S3": return MVGLinePalette.s3
        case "S4": return MVGLinePalette.s4
        case "S5": return MVGLinePalette.s5
        case "S6": return MVGLinePalette.s6
        case "S7": return MVGLinePalette.s7
        case "S8": return MVGLinePalette.s8
        case "S20": return MVGLinePalette.s20
        default: return MVGLinePalette.sDefault
        }
    }

    // MARK: - U-Bahn Specific Colors
    public static func uBahnLineColor(for departure: StopEvent) -> Color {
        guard let lineNumber = departure.transportation?.number else {
            return MVGLinePalette.uDefault
        }

        switch lineNumber {
        case "U1", "1": return MVGLinePalette.u1
        case "U2", "2": return MVGLinePalette.u2
        case "U3", "3": return MVGLinePalette.u3
        case "U4", "4": return MVGLinePalette.u4
        case "U5", "5": return MVGLinePalette.u5
        case "U6", "6": return MVGLinePalette.u6
        case "U7", "7": return MVGLinePalette.u1
        case "U8", "8": return MVGLinePalette.u2
        default: return MVGLinePalette.uDefault
        }
    }

    // MARK: - Time Display Logic
    public static func shouldShowOrange(for departure: StopEvent) -> Bool {
        let timeString = departure.departureTimePlanned ?? departure.departureTimeEstimated ?? ""
        guard let departureDate = Date.parseISO8601(timeString) else {
            return false
        }
        let minutesFromNow = departureDate.minutesFromNow()
        return minutesFromNow <= 1
    }

    // MARK: - Transport Type Name
    public static func transportTypeName(for departure: StopEvent) -> String {
        return departure.transportation?.product?.name ?? "Zug"
    }

    // MARK: - Formatted Departure Time
    public static func formattedDepartureTime(for departure: StopEvent, mode: TimeDisplayMode = .relative, referenceDate: Date = Date()) -> String {
        let (timeDisplay, _) = DepartureTimeFormatter.formatDepartureTime(
            plannedTime: departure.departureTimePlanned,
            estimatedTime: departure.departureTimeEstimated,
            includeDelay: true,
            mode: mode,
            referenceDate: referenceDate
        )
        return timeDisplay
    }

    // MARK: - Delay Display
    public static func delayDisplay(for departure: StopEvent) -> String? {
        let (_, delayDisplay) = DepartureTimeFormatter.formatDepartureTime(
            plannedTime: departure.departureTimePlanned,
            estimatedTime: departure.departureTimeEstimated,
            includeDelay: true,
            mode: .relative
        )
        return delayDisplay
    }

    // MARK: - Realtime Status
    public static func isRealtime(for departure: StopEvent) -> Bool {
        return departure.isRealtimeControlled == true
    }

    // MARK: - Line Color by String (for Disruptions)

    /// Einfache Füllfarbe (ohne Diagonale / S8-Schriftkontrast); für Legacy-Stellen.
    public static func lineColorForNumber(_ lineNumber: String, product: String) -> Color {
        lineBadgeAppearance(lineNumber: lineNumber, apiProduct: product).fallbackSolidFillColor
    }

    private static func sBahnColorForNumber(_ lineNumber: String) -> Color {
        switch lineNumber {
        case "SEV": return MVGLinePalette.sev
        case "S1": return MVGLinePalette.s1
        case "S2": return MVGLinePalette.s2
        case "S3": return MVGLinePalette.s3
        case "S4": return MVGLinePalette.s4
        case "S5": return MVGLinePalette.s5
        case "S6": return MVGLinePalette.s6
        case "S7": return MVGLinePalette.s7
        case "S8": return MVGLinePalette.s8
        case "S20": return MVGLinePalette.s20
        default: return MVGLinePalette.sDefault
        }
    }

    private static func uBahnColorForNumber(_ lineNumber: String) -> Color {
        let key = normalizedUBahnLineKey(lineNumber)
        switch key {
        case "U7": return MVGLinePalette.u1
        case "U8": return MVGLinePalette.u2
        default: return uBahnColorForUBahnKey(key)
        }
    }
}

// MARK: - Linien-Badge-Hintergrund (solid oder diagonal)

public struct LineBadgeBackground: View {
    public let appearance: LineBadgeAppearance
    public let cornerRadius: CGFloat

    public init(appearance: LineBadgeAppearance, cornerRadius: CGFloat) {
        self.appearance = appearance
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            switch appearance.background {
            case .solid(let color):
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color)
                    .frame(width: w, height: h)
            case .diagonalTopLeftBottomRight(let topLeft, let bottomTrailing):
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(bottomTrailing)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.addLine(to: CGPoint(x: w, y: 0))
                        path.closeSubpath()
                    }
                    .fill(topLeft)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .frame(width: w, height: h)
            }
        }
    }
}

// MARK: - Shared Transport Badge Component
public struct TransportBadge: View {
    public let departure: StopEvent
    public let size: BadgeSize

    public enum BadgeSize {
        case normal
        case compact

        public var dimensions: (width: CGFloat, height: CGFloat) {
            switch self {
            case .normal: return (48, 32)
            case .compact: return (32, 20)
            }
        }

        public var fontSize: CGFloat {
            switch self {
            case .normal: return 16
            case .compact: return 10
            }
        }

        public var cornerRadius: CGFloat {
            switch self {
            case .normal: return 8
            case .compact: return 4
            }
        }
    }

    public init(departure: StopEvent, size: BadgeSize) {
        self.departure = departure
        self.size = size
    }

    public var body: some View {
        let appearance = DepartureRowStyling.lineBadgeAppearance(for: departure)
        ZStack {
            LineBadgeBackground(appearance: appearance, cornerRadius: size.cornerRadius)
                .frame(width: size.dimensions.width, height: size.dimensions.height)

            Text(departure.transportation?.number ?? "?")
                .font(.system(size: size.fontSize, weight: .bold))
                .foregroundColor(appearance.foreground)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .accessibilityLabel("\(DepartureRowStyling.transportTypeName(for: departure)) \(departure.transportation?.number ?? "")")
    }
}

// MARK: - Reusable Realtime Badge
public struct RealtimeBadge: View {
    public let isRealtime: Bool

    public init(isRealtime: Bool) {
        self.isRealtime = isRealtime
    }

    public var body: some View {
        Group {
            if isRealtime {
                HStack(spacing: 3) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .accessibilityLabel("Echtzeitdaten verfügbar")
            }
        }
    }
}

// MARK: - Disruption Line Badge Component
public struct DisruptionLineBadge: View {
    public let line: DisruptionLine

    public init(line: DisruptionLine) {
        self.line = line
    }

    public var body: some View {
        let appearance = DepartureRowStyling.lineBadgeAppearance(lineNumber: line.lineNumber, apiProduct: line.product)
        Text(line.lineNumber)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(appearance.foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(LineBadgeBackground(appearance: appearance, cornerRadius: 4))
            .accessibilityLabel("\(line.product) \(line.lineNumber)")
    }
}
