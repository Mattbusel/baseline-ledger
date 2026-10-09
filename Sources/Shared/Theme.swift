import SwiftUI

/// Black lacquer and gold leaf, or whichever court finish is chosen. Every colour and type choice in the app comes from here.
enum Gold {
    static let ink = Color(red: 0.043, green: 0.039, blue: 0.031)        // #0B0A08
    static let lacquer = Color(red: 0.078, green: 0.070, blue: 0.055)    // cards
    static let lacquerHi = Color(red: 0.115, green: 0.102, blue: 0.078)
    static let ivory = Color(red: 0.953, green: 0.922, blue: 0.847)
    static let muted = Color(red: 0.953, green: 0.922, blue: 0.847).opacity(0.52)
    static let faint = Color(red: 0.953, green: 0.922, blue: 0.847).opacity(0.28)
    static var leaf: Color { Court.current.leaf }
    static var pale: Color { Court.current.pale }
    static var deep: Color { Court.current.deep }
    static var bronze: Color { Court.current.bronze }
    static let good = Color(red: 0.62, green: 0.80, blue: 0.52)
    static let bad = Color(red: 0.90, green: 0.46, blue: 0.38)

    /// Brushed foil: several light bands, so it reads as metal rather than a flat colour.
    static var foil: LinearGradient {
        let b = Court.current.band
        return LinearGradient(stops: [
            .init(color: b[0], location: 0), .init(color: b[1], location: 0.28), .init(color: b[2], location: 0.5),
            .init(color: b[3], location: 0.72), .init(color: b[4], location: 1),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var hairline: LinearGradient {
        LinearGradient(colors: [pale.opacity(0.55), leaf.opacity(0.12), pale.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var chartScale: [Color] { [leaf, pale, deep, leaf.opacity(0.7), bronze, Color(red: 0.75, green: 0.72, blue: 0.62)] }
}

/// The surface the ledger is finished in. Gold leaf is free; the four courts are 99-cent finishes,
/// each recolouring the app and the widgets and switching to a matching app icon.
struct Court: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let symbol: String
    let leaf: Color, pale: Color, deep: Color, bronze: Color
    /// Five light bands for the foil, dark to bright and back.
    let band: [Color]
    var icon: String? { id == "gold" ? nil : "AppIcon-" + name.replacingOccurrences(of: " ", with: "") }

    static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    static let all: [Court] = [
        Court(id: "gold", name: "Gold Leaf", blurb: "The original. Free.", symbol: "trophy.fill",
              leaf: rgb(0xD4AF37), pale: rgb(0xF7E7B0), deep: rgb(0x9C7A22), bronze: rgb(0x6B4F1A),
              band: [rgb(0x9E7824), rgb(0xF7E6A3), rgb(0xCCA338), rgb(0xFFF0BD), rgb(0xA88029)]),
        Court(id: "clay", name: "Red Clay", blurb: "Crushed brick, long rallies, sliding into the backhand.", symbol: "square.stack.3d.down.forward.fill",
              leaf: rgb(0xD9774A), pale: rgb(0xF6C3A6), deep: rgb(0xA04A26), bronze: rgb(0x5E2814),
              band: [rgb(0x96401E), rgb(0xF8CDB2), rgb(0xD06C3E), rgb(0xFFDCC6), rgb(0xA04A26)]),
        Court(id: "lawn", name: "Lawn", blurb: "Freshly cut grass and a white dress code.", symbol: "leaf.fill",
              leaf: rgb(0x7FBF5A), pale: rgb(0xD6F0C2), deep: rgb(0x46802C), bronze: rgb(0x264818),
              band: [rgb(0x3E7426), rgb(0xD9F2C6), rgb(0x74B44F), rgb(0xEAFADF), rgb(0x46802C)]),
        Court(id: "hard", name: "Hard Court", blurb: "Blue acrylic under the lights.", symbol: "square.fill",
              leaf: rgb(0x5A9BE0), pale: rgb(0xC6E0FA), deep: rgb(0x2B66A6), bronze: rgb(0x143A66),
              band: [rgb(0x255C96), rgb(0xCDE4FB), rgb(0x4F90D6), rgb(0xE4F1FF), rgb(0x2B66A6)]),
        Court(id: "night", name: "Night Session", blurb: "Optic yellow on black, the stadium after dark.", symbol: "moon.stars.fill",
              leaf: rgb(0xD6EE45), pale: rgb(0xF2FBC2), deep: rgb(0x98AC1C), bronze: rgb(0x55600E),
              band: [rgb(0x8A9C18), rgb(0xF4FCC8), rgb(0xCDE43C), rgb(0xFBFFE2), rgb(0x98AC1C)]),
    ]
    /// Read once and kept: the foil is asked for on every frame.
    static var current: Court = byID(Shared.court)
    static func byID(_ id: String) -> Court { all.first { $0.id == id } ?? all[0] }
    static func reload() { current = byID(Shared.court) }
    static func apply(_ id: String) { Shared.court = id; current = byID(id) }
}

/// What the app and its widgets share, through the app group.
enum Shared {
    static let group = "group.com.mattbusel.baselineledger"
    static let defaults = UserDefaults(suiteName: group) ?? .standard
    static var court: String {
        get { defaults.string(forKey: "court") ?? "gold" }
        set { defaults.set(newValue, forKey: "court") }
    }
}

extension Font {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .serif) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .default) }
    static func figure(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .serif).monospacedDigit() }
}

/// The page background: lacquer with a faint warm bloom from the top, and grain.
struct LacquerBackground: View {
    var body: some View {
        ZStack {
            Gold.ink
            RadialGradient(colors: [Gold.leaf.opacity(0.16), .clear], center: .init(x: 0.5, y: -0.05), startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Gold.deep.opacity(0.10), .clear], center: .init(x: 1.1, y: 0.9), startRadius: 10, endRadius: 420)
            Canvas { ctx, size in
                // Deterministic grain so it never crawls between frames.
                var seed: UInt64 = 0x9E3779B97F4A7C15
                for _ in 0..<900 {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let x = CGFloat(seed >> 33 % 10000) / 10000 * size.width
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let y = CGFloat(seed >> 33 % 10000) / 10000 * size.height
                    ctx.fill(Path(CGRect(x: x.truncatingRemainder(dividingBy: size.width), y: y.truncatingRemainder(dividingBy: size.height), width: 1, height: 1)),
                             with: .color(Gold.pale.opacity(0.05)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    func foil() -> some View { foregroundStyle(Gold.foil) }

    /// A lacquered card with a gold hairline.
    func card(padding: CGFloat = 18, radius: CGFloat = 24) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Gold.lacquerHi, Gold.lacquer], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Gold.hairline, lineWidth: 0.8))
    }
}
