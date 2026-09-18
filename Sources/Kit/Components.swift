import SwiftUI
import UIKit

enum Haptic {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func thud() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func done() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

struct Eyebrow: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text.uppercased())
            .font(.body(11, .semibold)).tracking(2.2)
            .foregroundStyle(Gold.leaf.opacity(0.85))
    }
}

struct SectionTitle: View {
    let title: String
    var trailing: String?
    var action: (() -> Void)?
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.display(22, .medium)).foregroundStyle(Gold.ivory)
            Spacer()
            if let trailing, let action {
                Button(action: action) {
                    Text(trailing).font(.body(13, .semibold)).foil()
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

/// The foil pill. Primary actions only.
struct FoilButton: View {
    let title: String
    var icon: String?
    let action: () -> Void
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) { self.title = title; self.icon = icon; self.action = action }
    var body: some View {
        Button { Haptic.thud(); action() } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.body(15, .bold)) }
                Text(title).font(.body(16, .semibold)).tracking(0.3)
            }
            .foregroundStyle(Gold.ink)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(Capsule().fill(Gold.foil))
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.8).blendMode(.overlay))
            .shadow(color: Gold.leaf.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(PressStyle())
    }
}

struct GhostButton: View {
    let title: String
    var icon: String?
    let action: () -> Void
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) { self.title = title; self.icon = icon; self.action = action }
    var body: some View {
        Button { Haptic.tap(); action() } label: {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(.body(14, .semibold)) }
                Text(title).font(.body(15, .semibold))
            }
            .foil()
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Capsule().fill(Gold.leaf.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Gold.hairline, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Big tap target for tallying at the range: label, running count, a pop on every tap.
struct TallyButton: View {
    let label: String
    var sub: String?
    let count: Int
    var tone: Color = Gold.leaf
    var tall: CGFloat = 86
    let action: () -> Void
    @State private var pop = false

    var body: some View {
        Button {
            Haptic.tap(); action()
            pop = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pop = false }
        } label: {
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.figure(30, .regular))
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(count > 0 ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.faint))
                    .contentTransition(.numericText())
                    .scaleEffect(pop ? 1.25 : 1)
                Text(label).font(.body(13, .semibold)).foregroundStyle(Gold.ivory.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.7)
                if let sub { Text(sub).font(.body(10.5, .medium)).foregroundStyle(Gold.muted) }
            }
            .frame(maxWidth: .infinity).frame(height: tall)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [tone.opacity(count > 0 ? 0.16 : 0.06), Gold.lacquer], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tone.opacity(count > 0 ? 0.55 : 0.18), lineWidth: 1))
        }
        .buttonStyle(PressStyle())
        .animation(.snappy, value: count)
    }
}

/// Single-select chips in a horizontal scroll.
struct ChipRow<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { o in
                    let on = o == selection
                    Button { Haptic.tap(); withAnimation(.snappy) { selection = o } } label: {
                        Text(label(o))
                            .font(.body(14, on ? .semibold : .medium))
                            .foregroundStyle(on ? AnyShapeStyle(Gold.ink) : AnyShapeStyle(Gold.ivory.opacity(0.8)))
                            .padding(.horizontal, 15).frame(height: 38)
                            .background(Capsule().fill(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi)))
                            .overlay(Capsule().strokeBorder(on ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Gold.hairline), lineWidth: 0.8))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

/// 1 to 5, drawn as small gold diamonds.
struct DiamondRating: View {
    @Binding var value: Int
    var size: CGFloat = 26
    var body: some View {
        HStack(spacing: size * 0.35) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= value ? "suit.diamond.fill" : "suit.diamond")
                    .font(.system(size: size))
                    .foregroundStyle(i <= value ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.faint))
                    .scaleEffect(i == value ? 1.1 : 1)
                    .onTapGesture { Haptic.tap(); withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { value = i } }
            }
        }
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var unit: String?
    var delta: String?
    var deltaGood: Bool = true
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.body(10.5, .semibold)).tracking(1.6).foregroundStyle(Gold.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.figure(30, .regular)).foil()
                if let unit { Text(unit).font(.body(12, .medium)).foregroundStyle(Gold.muted) }
            }
            if let delta {
                Text(delta).font(.body(11.5, .semibold)).foregroundStyle(deltaGood ? Gold.good : Gold.bad)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16, radius: 20)
    }
}

/// A labelled text field on lacquer.
struct LedgerField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var multiline = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(label)
            Group {
                if multiline {
                    TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Gold.faint), axis: .vertical)
                        .lineLimit(3...10)
                } else {
                    TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Gold.faint))
                }
            }
            .font(.display(17))
            .foregroundStyle(Gold.ivory)
            .tint(Gold.leaf)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16, radius: 18)
    }
}

/// A compact − value + control.
struct LedgerStepper: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999
    var step = 1
    var body: some View {
        HStack {
            Text(label).font(.body(15, .medium)).foregroundStyle(Gold.ivory.opacity(0.9))
            Spacer()
            HStack(spacing: 0) {
                button("minus") { value = max(range.lowerBound, value - step) }
                Text("\(value)").font(.figure(19)).foil().frame(minWidth: 46).contentTransition(.numericText())
                button("plus") { value = min(range.upperBound, value + step) }
            }
            .background(Capsule().fill(Gold.ink.opacity(0.6)))
            .overlay(Capsule().strokeBorder(Gold.hairline, lineWidth: 0.8))
        }
        .animation(.snappy, value: value)
    }
    private func button(_ icon: String, _ act: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); act() } label: {
            Image(systemName: icon).font(.body(13, .bold)).foregroundStyle(Gold.leaf).frame(width: 40, height: 36)
        }
    }
}

/// Custom tab bar: a floating lacquer capsule with foil for the active tab.
struct GoldTabBar<Tab: Hashable & CaseIterable & RawRepresentable>: View where Tab.RawValue == String, Tab.AllCases: RandomAccessCollection {
    @Binding var selection: Tab
    let icon: (Tab) -> String
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Tab.allCases), id: \.self) { tab in
                let on = tab == selection
                Button {
                    Haptic.tap()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon(tab)).font(.system(size: 18, weight: on ? .semibold : .regular))
                        Text(tab.rawValue).font(.body(10, .semibold)).tracking(0.4)
                    }
                    .foregroundStyle(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.ivory.opacity(0.42)))
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background {
                        if on {
                            Capsule().fill(Gold.leaf.opacity(0.1))
                                .overlay(Capsule().strokeBorder(Gold.hairline, lineWidth: 0.6))
                                .matchedGeometryEffect(id: "tab", in: ns)
                                .padding(.horizontal, 4).padding(.vertical, 5)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .background(
            Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                .overlay(Capsule().fill(Gold.ink.opacity(0.72)))
                .shadow(color: .black.opacity(0.6), radius: 24, y: 10)
        )
        .overlay(Capsule().strokeBorder(Gold.hairline, lineWidth: 0.8))
        .padding(.horizontal, 16)
    }
}

/// Header for full-screen sheets.
struct SheetHeader: View {
    let eyebrow: String
    let title: String
    var close: () -> Void
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(eyebrow)
                Text(title).font(.display(30, .medium)).foregroundStyle(Gold.ivory)
            }
            Spacer()
            Button { Haptic.tap(); close() } label: {
                Image(systemName: "xmark").font(.body(13, .bold)).foregroundStyle(Gold.ivory.opacity(0.7))
                    .frame(width: 36, height: 36).background(Circle().fill(Gold.lacquerHi))
                    .overlay(Circle().strokeBorder(Gold.hairline, lineWidth: 0.6))
            }
        }
        .padding(.horizontal, 20)
    }
}

/// A thin progress ring in foil.
struct FoilRing: View {
    let progress: Double
    var width: CGFloat = 8
    var body: some View {
        ZStack {
            Circle().stroke(Gold.leaf.opacity(0.1), lineWidth: width)
            Circle().trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(AngularGradient(colors: [Gold.deep, Gold.pale, Gold.leaf, Gold.pale], center: .center),
                        style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Split bar: how a total divides among parts, e.g. misses left vs right.
struct SplitBar: View {
    let parts: [(String, Int)]
    var body: some View {
        let total = max(1, parts.map(\.1).reduce(0, +))
        VStack(spacing: 8) {
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { i, p in
                        Rectangle()
                            .fill(Gold.chartScale[i % Gold.chartScale.count].opacity(p.1 == 0 ? 0.15 : 1))
                            .frame(width: max(2, g.size.width * CGFloat(p.1) / CGFloat(total)))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 10)
            HStack {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, p in
                    HStack(spacing: 5) {
                        Circle().fill(Gold.chartScale[i % Gold.chartScale.count]).frame(width: 7, height: 7)
                        Text("\(p.0) \(Int((Double(p.1) / Double(total) * 100).rounded()))%")
                            .font(.body(11.5, .medium)).foregroundStyle(Gold.muted)
                    }
                    if i < parts.count - 1 { Spacer(minLength: 4) }
                }
            }
        }
    }
}

extension Date {
    var ledgerDay: String { formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }
    var shortDay: String { formatted(.dateTime.month(.abbreviated).day()) }
}

func pct(_ n: Int, _ d: Int) -> String { d == 0 ? "–" : "\(Int((Double(n) / Double(d) * 100).rounded()))" }
func pctValue(_ n: Int, _ d: Int) -> Double { d == 0 ? 0 : Double(n) / Double(d) * 100 }
