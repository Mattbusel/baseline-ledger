import SwiftUI

/// Black lacquer and gold leaf. Every colour and type choice in the app comes from here.
enum Gold {
    static let ink = Color(red: 0.043, green: 0.039, blue: 0.031)        // #0B0A08
    static let lacquer = Color(red: 0.078, green: 0.070, blue: 0.055)    // cards
    static let lacquerHi = Color(red: 0.115, green: 0.102, blue: 0.078)
    static let ivory = Color(red: 0.953, green: 0.922, blue: 0.847)
    static let muted = Color(red: 0.953, green: 0.922, blue: 0.847).opacity(0.52)
    static let faint = Color(red: 0.953, green: 0.922, blue: 0.847).opacity(0.28)
    static let leaf = Color(red: 0.831, green: 0.686, blue: 0.216)       // #D4AF37
    static let pale = Color(red: 0.969, green: 0.906, blue: 0.690)
    static let deep = Color(red: 0.612, green: 0.478, blue: 0.133)
    static let bronze = Color(red: 0.42, green: 0.31, blue: 0.10)
    static let good = Color(red: 0.62, green: 0.80, blue: 0.52)
    static let bad = Color(red: 0.90, green: 0.46, blue: 0.38)

    /// Brushed foil: several light bands, so it reads as metal rather than yellow.
    static let foil = LinearGradient(stops: [
        .init(color: Color(red: 0.62, green: 0.47, blue: 0.14), location: 0),
        .init(color: Color(red: 0.97, green: 0.90, blue: 0.64), location: 0.28),
        .init(color: Color(red: 0.80, green: 0.64, blue: 0.22), location: 0.5),
        .init(color: Color(red: 1.0, green: 0.94, blue: 0.74), location: 0.72),
        .init(color: Color(red: 0.66, green: 0.50, blue: 0.16), location: 1),
    ], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let hairline = LinearGradient(colors: [
        Color(red: 0.97, green: 0.88, blue: 0.58).opacity(0.55),
        Color(red: 0.83, green: 0.69, blue: 0.22).opacity(0.12),
        Color(red: 0.97, green: 0.88, blue: 0.58).opacity(0.35),
    ], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let chartScale: [Color] = [leaf, pale, deep, Color(red: 0.93, green: 0.78, blue: 0.45), bronze, Color(red: 0.75, green: 0.72, blue: 0.62)]
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
