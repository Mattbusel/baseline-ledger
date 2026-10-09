import SwiftUI
import WidgetKit

@main
struct BaselineLedgerApp: App {
    @State private var ledger: Ledger
    @State private var router = Router()
    @State private var pro: Pro
    @State private var extras: Extras

    init() {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.contains("-shot") || UserDefaults.standard.bool(forKey: "demoMode")
        _ledger = State(initialValue: Ledger(demo: demo))
        // Screenshots and the review recording show Pro; the paywall and locked shots show it locked.
        let shot = args.firstIndex(of: "-shot").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        let lockedShot = shot.map { $0.hasPrefix("paywall") || $0.hasPrefix("locked") } ?? false
        let staged = shot != nil || args.contains("-demoAutoplay")
        _pro = State(initialValue: staged ? Pro(forced: !lockedShot) : Pro())
        _extras = State(initialValue: Extras(demo: staged, locked: lockedShot || shot == "shop"))
        if staged { Court.current = Court.byID("gold") }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(ledger)
                .environment(router)
                .environment(pro)
                .environment(extras)
                .preferredColorScheme(.dark)
                .tint(Gold.leaf)
                .onAppear {
                    router.applyShotArgs(ledger, pro)
                    Autopilot.shared.run(router)
                    ledger.didSave = { [ledger, pro] in
                        ledger.glance(unlocked: pro.unlocked, weeklyTarget: UserDefaults.standard.object(forKey: "weeklyTarget") as? Int ?? 300).save()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    ledger.didSave?()
                }
                .onChange(of: pro.unlocked) { _, _ in ledger.didSave?() }
        }
    }
}

enum Tab: String, CaseIterable { case home = "Home", journal = "Journal", matches = "Matches", stats = "Stats", gear = "Gear" }

@Observable
final class Router {
    var tab: Tab = .home
    var live: PracticeSession?
    var finishing: PracticeSession?
    var editingMatch: Match?
    var viewing: PracticeSession?
    /// A match being scored point by point.
    var scoring: Match?
    var poster: Match?
    var opponents = false
    var opponent: String?
    var scout: ScoutReport?
    var shop = false
    var showcase = false
    /// Bumped when the court finish changes, so every view redraws in the new colours.
    var courtTick = 0

    @MainActor
    func applyShotArgs(_ l: Ledger, _ pro: Pro) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else { return }
        switch a[i + 1] {
        case "live":
            var s = l.sessions[0]; s.id = UUID(); s.minutes = 38
            s.blocks = Array(s.blocks.prefix(2))
            live = s
        case "finish": finishing = l.sessions[0]
        case "matches": tab = .matches
        case "match": tab = .matches; editingMatch = l.matches[0]
        case "stats": tab = .stats
        case "gear": tab = .gear
        case "journal": tab = .journal
        case "locked": tab = .stats
        case "paywall": tab = .stats; pro.paywall = .stats
        case "score":
            // Mid-match, so the board, the break point flag and the momentum all show.
            if var m = l.matches.first(where: { $0.isLive }) { m.id = UUID(); m.points = Array(m.points.prefix(m.points.count - 9)); scoring = m }
        case "setup": scoring = Match()
        case "opponents": tab = .matches; opponents = true
        case "opponent": tab = .matches; opponent = l.opponents.first?.name
        case "scout": tab = .matches; if let o = l.opponents.first { scout = Scout.make(l, opponent: o) }
        case "poster": tab = .matches; poster = l.matches.first { $0.isLive } ?? l.matches.first
        case "shop": shop = true
        case "widgets": showcase = true
        case "clutch": tab = .stats
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        @Bindable var router = router
        @Bindable var pro = pro
        ZStack(alignment: .bottom) {
            LacquerBackground()
            Group {
                switch router.tab {
                case .home: HomeView()
                case .journal: JournalView()
                case .matches: MatchesView()
                case .stats: StatsView()
                case .gear: GearView()
                }
            }
            .transition(.opacity)
            GoldTabBar(selection: $router.tab) { t in
                switch t {
                case .home: return "sun.horizon"
                case .journal: return "book.closed"
                case .matches: return "trophy"
                case .stats: return "chart.xyaxis.line"
                case .gear: return "tennis.racket"
                }
            }
            .padding(.bottom, 2)
        }
        .id(router.courtTick)
        .overlay { if router.showcase { WidgetShowcase() } }
        .fullScreenCover(item: $router.scoring) { m in LiveMatchView(match: m) }
        .sheet(item: $router.poster) { m in PosterSheet(match: m).presentationBackground(Gold.ink) }
        .sheet(isPresented: $router.opponents) { OpponentsView().presentationBackground(Gold.ink) }
        .sheet(item: Binding(get: { router.opponent.map(NameID.init) }, set: { router.opponent = $0?.id })) { n in OpponentDetail(name: n.id).presentationBackground(Gold.ink) }
        .sheet(item: $router.scout) { r in ScoutSheet(report: r).presentationBackground(Gold.ink) }
        .sheet(isPresented: $router.shop) { ShopSheet { router.courtTick += 1 }.presentationBackground(Gold.ink) }
        .fullScreenCover(item: $router.live) { s in LiveSessionView(session: s) }
        .fullScreenCover(item: $router.finishing) { s in FinishSessionView(session: s) }
        .fullScreenCover(item: $router.editingMatch) { m in MatchEditorView(match: m) }
        .sheet(item: $router.viewing) { s in SessionDetailView(session: s).presentationBackground(Gold.ink) }
        .sheet(item: $pro.paywall) { r in PaywallView(reason: r).presentationBackground(Gold.ink) }
    }
}

struct NameID: Identifiable { let id: String }

/// Every tab is a scroll view with the same margins and room for the floating tab bar.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) { content }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 110)
        }
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(eyebrow)
            Text(title).font(.display(36, .regular)).foregroundStyle(Gold.ivory)
        }
        .padding(.horizontal, 4)
        .padding(.top, 12)
    }
}
