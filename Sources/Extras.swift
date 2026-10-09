import StoreKit
import SwiftUI
import UIKit
import WidgetKit

/// The 99-cent corner, kept apart from Pro so Pro's grandfathering stays exactly as it was.
/// Scouting Reports and Match Posters are consumables people buy again; court finishes are one-time.
@MainActor
@Observable
final class Extras {
    static let scoutsID = "com.mattbusel.baselineledger.scouts"
    static let postersID = "com.mattbusel.baselineledger.posters"
    static func courtID(_ id: String) -> String { "com.mattbusel.baselineledger.court." + id }
    static var allIDs: [String] { [scoutsID, postersID] + Court.all.filter { $0.id != "gold" }.map { courtID($0.id) } }

    private(set) var owned: Set<String> = []
    private(set) var products: [String: Product] = [:]
    var busy: String?
    var message: String?
    private var updates: Task<Void, Never>?
    private let demo: Bool
    private let d = UserDefaults.standard

    /// Banked consumables.
    var scouts: Int { didSet { d.set(scouts, forKey: "extras.scouts") } }
    var posters: Int { didSet { d.set(posters, forKey: "extras.posters") } }

    init(demo: Bool, locked: Bool = false) {
        self.demo = demo
        scouts = d.integer(forKey: "extras.scouts")
        posters = d.integer(forKey: "extras.posters")
        if demo {
            owned = locked ? [] : [Extras.courtID("clay")]
            return
        }
        owned = Set(d.stringArray(forKey: "extras.owned") ?? [])
        updates = Task { [weak self] in
            for await r in Transaction.updates { await self?.handle(r) }
        }
        Task {
            for await r in Transaction.unfinished { await handle(r) }
            await refresh()
        }
    }

    func price(_ id: String) -> String { products[id]?.displayPrice ?? (demo ? "$0.99" : "…") }
    func ownsCourt(_ id: String) -> Bool { id == "gold" || owned.contains(Extras.courtID(id)) }

    // MARK: free allowances

    static var week: String {
        let c = Calendar(identifier: .iso8601)
        let w = c.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return "\(w.yearForWeekOfYear ?? 0)-\(w.weekOfYear ?? 0)"
    }
    /// One scouting report a week is free for everyone.
    var freeScoutLeft: Bool { demo || d.string(forKey: "extras.freeScoutWeek") != Extras.week }
    var firstPosterFree: Bool { !d.bool(forKey: "extras.freePosterUsed") }

    func loadProducts() async {
        guard !demo, products.count < Extras.allIDs.count else { return }
        if let ps = try? await Product.products(for: Extras.allIDs) { for p in ps { products[p.id] = p } }
    }

    func refresh() async {
        guard !demo else { return }
        var has: Set<String> = []
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r, t.revocationDate == nil, t.productType == .nonConsumable, t.productID != Pro.productID { has.insert(t.productID) }
        }
        owned = has
        d.set(Array(has), forKey: "extras.owned")
        // A refunded finish falls back to gold leaf.
        if !ownsCourt(Court.current.id) { Court.apply("gold"); WidgetCenter.shared.reloadAllTimelines() }
        await loadProducts()
    }

    private func handle(_ r: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = r, Extras.allIDs.contains(t.productID) else { return }
        credit(t)
        await t.finish()
        await refresh()
    }

    /// Bank a consumable once per transaction, however many times StoreKit reports it.
    private func credit(_ t: StoreKit.Transaction) {
        guard t.productType == .consumable, t.revocationDate == nil else { return }
        var seen = Set(d.stringArray(forKey: "extras.credited") ?? [])
        guard !seen.contains(String(t.id)) else { return }
        seen.insert(String(t.id)); d.set(Array(seen), forKey: "extras.credited")
        if t.productID == Extras.scoutsID { scouts += 3 }
        if t.productID == Extras.postersID { posters += 3 }
    }

    @discardableResult
    func buy(_ id: String) async -> Bool {
        message = nil
        if demo {
            if id == Extras.scoutsID { scouts += 3 } else if id == Extras.postersID { posters += 3 } else { owned.insert(id) }
            return true
        }
        await loadProducts()
        guard let p = products[id] else { message = "The App Store did not answer. Check your connection and try again."; return false }
        busy = id; defer { busy = nil }
        do {
            switch try await p.purchase() {
            case .success(let r):
                guard case .verified(let t) = r else { message = "Apple could not confirm that purchase. Try Restore in a minute."; return false }
                credit(t)
                await t.finish()
                await refresh()
                Haptic.done()
                return true
            case .pending: message = "Waiting for approval. It arrives by itself once approved."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "The purchase did not go through: \(error.localizedDescription)" }
        return false
    }

    func restore() async {
        guard !demo else { return }
        busy = "restore"; defer { busy = nil }
        try? await AppStore.sync()
        await refresh()
    }

    /// Spend this week's free report, or a banked one. False if there is nothing to spend.
    func spendScout() -> Bool {
        if demo { return true }
        if freeScoutLeft { d.set(Extras.week, forKey: "extras.freeScoutWeek"); return true }
        guard scouts > 0 else { return false }
        scouts -= 1
        return true
    }

    /// Spend a poster credit (or the free first one). False if there is nothing to spend.
    func spendPoster() -> Bool {
        if demo { return true }
        if firstPosterFree { d.set(true, forKey: "extras.freePosterUsed"); return true }
        guard posters > 0 else { return false }
        posters -= 1
        return true
    }
}

// MARK: - Shop

struct ShopSheet: View {
    @Environment(Extras.self) private var extras
    @Environment(\.dismiss) private var dismiss
    @State private var current = Court.current.id
    var onCourt: () -> Void = {}

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    SheetHeader(eyebrow: "Extras", title: "Small things,\n99 cents each.") { dismiss() }.padding(.horizontal, -20)

                    VStack(spacing: 0) {
                        row(icon: "binoculars.fill", title: "Scouting Reports, 3 for 99¢",
                            sub: "Before you play someone again: your head-to-head, how your serve and nerve hold up against them, what has worked, and a three-point plan. One a week is free" + (extras.freeScoutLeft ? " (this week's is ready)." : "; you've used this week's.") + " Banked: \(extras.scouts).",
                            id: Extras.scoutsID)
                        Rectangle().fill(Gold.leaf.opacity(0.1)).frame(height: 0.8).padding(.horizontal, 16)
                        row(icon: "photo.artframe", title: "Match Posters, 3 for 99¢",
                            sub: "A gold-leaf scorecard of a match, with the numbers that won it, to share or frame. " + (extras.firstPosterFree ? "Your first one is free." : "Left: \(extras.posters)."),
                            id: Extras.postersID)
                    }
                    .card(padding: 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Court finishes")
                        Text("Refinish the whole ledger, the widgets and the app icon in the colours of a court. Yours without Pro.").font(.body(13)).foregroundStyle(Gold.muted)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Court.all) { c in courtCard(c) }
                    }

                    if let m = extras.message { Text(m).font(.body(13, .semibold)).foregroundStyle(Gold.pale).frame(maxWidth: .infinity) }
                    GhostButton(extras.busy == "restore" ? "Restoring" : "Restore purchases", icon: "arrow.clockwise") { Task { await extras.restore() } }
                    Text("Finishes restore on all your devices. Reports and posters are used up as you use them.")
                        .font(.body(11.5)).foregroundStyle(Gold.faint).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
        .task { await extras.loadProducts() }
    }

    private func row(icon: String, title: String, sub: String, id: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.body(16, .semibold)).foil()
                .frame(width: 40, height: 40).background(Circle().fill(Gold.lacquerHi))
                .overlay(Circle().strokeBorder(Gold.hairline, lineWidth: 0.8))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.display(17, .medium)).foregroundStyle(Gold.ivory)
                Text(sub).font(.body(12.5)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Button { Task { await extras.buy(id) } } label: {
                Group { if extras.busy == id { ProgressView().tint(Gold.ink) } else { Text(extras.price(id)).font(.body(13, .bold)) } }
                    .foregroundStyle(Gold.ink).padding(.horizontal, 12).frame(height: 32).background(Capsule().fill(Gold.foil))
            }
            .buttonStyle(PressStyle()).disabled(extras.busy != nil)
        }
        .padding(16)
    }

    private func courtCard(_ c: Court) -> some View {
        let owned = extras.ownsCourt(c.id), on = current == c.id
        return Button {
            if owned { use(c) } else { Task { if await extras.buy(Extras.courtID(c.id)) { use(c) } } }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Gold.ink)
                    CourtLines().stroke(c.pale.opacity(0.35), lineWidth: 1).padding(10)
                    Circle().fill(LinearGradient(colors: c.band, startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 40, height: 40)
                        .overlay(Image(systemName: c.symbol).font(.system(size: 15)).foregroundStyle(Gold.ink.opacity(0.75)))
                        .shadow(color: c.leaf.opacity(0.5), radius: 12)
                }.frame(height: 76)
                HStack {
                    Text(c.name).font(.display(16, .medium)).foregroundStyle(Gold.ivory).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer()
                    if on { Image(systemName: "checkmark.seal.fill").foregroundStyle(c.leaf) }
                    else if owned { Text("Use").font(.body(12, .bold)).foregroundStyle(c.leaf) }
                    else { Text(extras.price(Extras.courtID(c.id))).font(.body(11.5, .bold)).foregroundStyle(Gold.ink).padding(.horizontal, 8).frame(height: 22).background(Capsule().fill(LinearGradient(colors: c.band, startPoint: .leading, endPoint: .trailing))) }
                }
                Text(c.blurb).font(.body(11)).foregroundStyle(Gold.muted).lineLimit(2, reservesSpace: true)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Gold.lacquer))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(on ? c.leaf : Gold.leaf.opacity(0.12), lineWidth: on ? 1.6 : 0.8))
        }
        .buttonStyle(PressStyle()).disabled(extras.busy != nil)
    }

    private func use(_ c: Court) {
        Court.apply(c.id)
        current = c.id
        if UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != c.icon,
           !ProcessInfo.processInfo.arguments.contains("-shot") {
            UIApplication.shared.setAlternateIconName(c.icon)
        }
        WidgetCenter.shared.reloadAllTimelines()
        Haptic.thud()
        onCourt()
    }
}

/// A singles court from above: baselines, sidelines, service boxes.
struct CourtLines: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addRect(r)
        let inset = r.width * 0.12
        p.move(to: CGPoint(x: r.minX + inset, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + inset, y: r.maxY))
        p.move(to: CGPoint(x: r.maxX - inset, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX - inset, y: r.maxY))
        p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        let sx = r.width * 0.27
        p.move(to: CGPoint(x: r.midX - sx, y: r.minY)); p.addLine(to: CGPoint(x: r.midX - sx, y: r.maxY))
        p.move(to: CGPoint(x: r.midX + sx, y: r.minY)); p.addLine(to: CGPoint(x: r.midX + sx, y: r.maxY))
        p.move(to: CGPoint(x: r.midX - sx, y: r.midY)); p.addLine(to: CGPoint(x: r.midX + sx, y: r.midY))
        return p
    }
}

// MARK: - Match poster

struct PosterSheet: View {
    @Environment(Extras.self) private var extras
    @Environment(\.dismiss) private var dismiss
    let match: Match
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHeader(eyebrow: "Match poster", title: match.opponent.isEmpty ? "Your match" : "vs \(match.opponent)") { dismiss() }.padding(.horizontal, -20)
                    MatchPoster(match: match)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
                    if let image {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview(match.scoreline, image: Image(uiImage: image))) {
                            HStack(spacing: 8) { Image(systemName: "square.and.arrow.up"); Text("Share or save").font(.body(16, .semibold)) }
                                .foregroundStyle(Gold.ink).frame(maxWidth: .infinity).frame(height: 56).background(Capsule().fill(Gold.foil))
                        }
                        Text("Made. Save it to Photos from the share sheet.").font(.body(12)).foregroundStyle(Gold.muted).frame(maxWidth: .infinity)
                    } else if extras.firstPosterFree || extras.posters > 0 {
                        FoilButton(extras.firstPosterFree ? "Make it · your first is free" : "Make it · \(extras.posters) left", icon: "photo.artframe") { make() }
                    } else {
                        FoilButton(extras.busy == Extras.postersID ? "One moment" : "3 posters · \(extras.price(Extras.postersID))", icon: "plus") {
                            Task { if await extras.buy(Extras.postersID) { make() } }
                        }
                        Text("Posters are used up as you make them. Court finishes in Extras change their colour too.").font(.body(12)).foregroundStyle(Gold.muted).frame(maxWidth: .infinity)
                    }
                    if let m = extras.message { Text(m).font(.body(13, .semibold)).foregroundStyle(Gold.pale).frame(maxWidth: .infinity) }
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
    }

    @MainActor private func make() {
        guard extras.spendPoster() else { return }
        let r = ImageRenderer(content: MatchPoster(match: match).frame(width: 360))
        r.scale = 3
        image = r.uiImage
        Haptic.done()
    }
}

struct MatchPoster: View {
    let match: Match
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()).uppercased()).font(.body(9.5, .semibold)).tracking(1.6).foregroundStyle(Gold.muted)
                    Text(match.opponent.isEmpty ? "A match" : "vs \(match.opponent)").font(.display(26, .medium)).foregroundStyle(Gold.ivory).lineLimit(2)
                    Text([match.event, match.surface.rawValue, match.opponentLevel].filter { !$0.isEmpty }.joined(separator: " · ")).font(.body(11)).foregroundStyle(Gold.muted)
                }
                Spacer()
                ZStack {
                    Circle().fill(match.won ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi))
                    Circle().strokeBorder(Gold.ink.opacity(0.25), lineWidth: 2).padding(5)
                    Text(match.won ? "W" : "L").font(.display(34, .bold)).foregroundStyle(match.won ? Gold.ink : Gold.ivory)
                }.frame(width: 76, height: 76)
            }
            HStack(spacing: 10) {
                ForEach(match.sets) { s in
                    VStack(spacing: 0) {
                        Text("\(s.me)").font(.figure(30)).foregroundStyle(s.won ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.ivory.opacity(0.5)))
                        Text("\(s.them)").font(.figure(30)).foregroundStyle(s.won ? AnyShapeStyle(Gold.ivory.opacity(0.5)) : AnyShapeStyle(Gold.ivory))
                    }
                    .frame(maxWidth: .infinity).frame(height: 84)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Gold.ink.opacity(0.55)))
                    .overlay(alignment: .topTrailing) { if let tb = s.tiebreak { Text("\(tb)").font(.body(10, .bold)).foregroundStyle(Gold.pale).padding(6) } }
                }
            }
            if match.isLive {
                MomentumChart(values: ScoreState.replay(match.points, match.scoring ?? LiveFormat()).momentum).frame(height: 70)
            }
            HStack(spacing: 0) {
                stat("Aces", "\(match.aces)")
                stat("1st serve", match.firstServesTotal > 0 ? "\(Int(match.firstServePct.rounded()))%" : "–")
                stat("Break pts", "\(match.breakPointsWon)/\(match.breakPointChances)")
                stat("W / UE", "\(match.winners)/\(match.unforcedErrors)")
            }
            HStack {
                Rectangle().fill(Gold.foil).frame(width: 26, height: 1)
                Text("BASELINE LEDGER").font(.body(9, .bold)).tracking(2.4).foregroundStyle(Gold.muted)
                Rectangle().fill(Gold.foil).frame(height: 1)
            }
        }
        .padding(22)
        .background(LacquerBackground())
    }
    private func stat(_ l: String, _ v: String) -> some View {
        VStack(spacing: 3) { Text(v).font(.figure(17)).foregroundStyle(Gold.ivory); Text(l.uppercased()).font(.body(8.5, .bold)).tracking(1).foregroundStyle(Gold.muted) }.frame(maxWidth: .infinity)
    }
}
