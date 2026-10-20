import StoreKit
import SwiftUI
import TipKit
import WidgetKit

@main
struct BaselineLedgerApp: App {
    @State private var ledger: Ledger
    @State private var router = Router.shared
    @State private var pro: Pro
    @State private var plus: Plus
    @State private var extras: Extras
    @Environment(\.scenePhase) private var phase

    init() {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.contains("-shot") || args.contains("-demoPreview") || UserDefaults.standard.bool(forKey: "demoMode")
        _ledger = State(initialValue: Ledger(demo: demo))
        // Screenshots and the review recording show everything unlocked; the paywall and locked shots show it locked.
        let shot = args.firstIndex(of: "-shot").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        let lockedShot = shot.map { $0.hasPrefix("paywall") || $0.hasPrefix("locked") } ?? false
        let staged = shot != nil || args.contains("-demoAutoplay") || args.contains("-demoPreview")
        let pro = staged ? Pro(forced: !lockedShot) : Pro()
        let plus = staged ? Plus(forced: !lockedShot) : Plus()
        let extras = Extras(demo: staged, locked: lockedShot || shot == "shop")
        pro.plusActive = plus.active
        extras.plus = plus.active && shot != "shop"
        _pro = State(initialValue: pro)
        _plus = State(initialValue: plus)
        _extras = State(initialValue: extras)
        if staged { Court.current = Court.byID(shot == "clay" ? "clay" : "gold") }
        if !staged { try? Tips.configure([.displayFrequency(.immediate)]) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(ledger)
                .environment(router)
                .environment(pro)
                .environment(plus)
                .environment(extras)
                .preferredColorScheme(.dark)
                .tint(Gold.leaf)
                .onAppear {
                    router.applyShotArgs(ledger, pro)
                    Autopilot.shared.run(router)
                    Autopilot.shared.runPreview(router, ledger)
                    ledger.didSave = { [ledger, pro] in
                        ledger.glance(unlocked: pro.has, weeklyTarget: UserDefaults.standard.object(forKey: "weeklyTarget") as? Int ?? 300).save()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    ledger.didSave?()
                }
                .onChange(of: pro.has) { _, _ in ledger.didSave?() }
                .onChange(of: plus.active) { _, on in pro.plusActive = on; extras.plus = on; ledger.didSave?() }
                .onChange(of: phase) { _, p in
                    if p == .background && plus.active && !Shots.on { Backup.auto(ledger) }
                    if p == .active { Task { await plus.refresh() } }
                }
                .onOpenURL { router.handle($0) }
        }
    }
}

enum Tab: String, CaseIterable { case home = "Home", journal = "Journal", matches = "Matches", stats = "Stats", gear = "Gear" }

@Observable
final class Router {
    static let shared = Router()

    var tab: Tab = .home
    var live: PracticeSession?
    var finishing: PracticeSession?
    var editingMatch: Match?
    var viewing: PracticeSession?
    /// A match being scored point by point.
    var scoring: Match?
    /// The second-serve flag of a match resumed from its draft.
    var resumeSecondServe = false
    var poster: Match?
    var opponents = false
    var opponent: String?
    var scout: ScoutReport?
    var shop = false
    var showcase = false
    var plan = false
    var challenge = false
    /// A good moment to ask for a rating: a win saved, a challenge finished.
    var happy = 0
    /// Bumped when the court finish changes, so every view redraws in the new colours.
    var courtTick = 0
    /// Plus was asked for by a link before the paywall could be shown.
    var wantsPlus = false

    enum Route: String { case score, hit, challenge, plan, plus, matches, stats }

    /// Deep links (baselineledger://score), Control Center, Siri and In-App Events land here.
    @MainActor
    func open(_ r: Route) {
        switch r {
        case .score:
            if let d = LiveDraft.load() { resume(d) } else { scoring = Match() }
        case .hit: live = PracticeSession()
        case .challenge: tab = .home; challenge = true
        case .plan: tab = .home; plan = true
        case .plus: tab = .home; wantsPlus = true
        case .matches: tab = .matches
        case .stats: tab = .stats
        }
    }

    @MainActor
    func handle(_ url: URL) {
        guard url.scheme == "baselineledger", let r = Route(rawValue: url.host ?? "") else { return }
        open(r)
    }

    /// Back into a match that was being scored when the app closed.
    @MainActor
    func resume(_ d: LiveDraft) {
        var m = (try? JSONDecoder().decode(Match.self, from: d.match)) ?? Match()
        m.id = d.matchID
        m.points = d.points
        m.scoring = d.format
        resumeSecondServe = d.secondServe
        scoring = m
    }

    @MainActor
    func happyMoment() { happy += 1 }

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
        case "stats", "pressure", "clutch": tab = .stats
        case "gear": tab = .gear
        case "journal": tab = .journal
        case "locked": tab = .stats
        case "paywall": tab = .stats; pro.paywall = .plus
        case "score":
            // Mid-match, so the board, the break point flag and the momentum all show.
            if var m = l.matches.first(where: { $0.isLive }) { m.id = UUID(); m.points = Array(m.points.prefix(m.points.count - 9)); scoring = m }
        case "setup": scoring = Match()
        case "opponents": tab = .matches; opponents = true
        case "opponent": tab = .matches; opponent = l.opponents.first?.name
        case "scout": tab = .matches; if let o = l.opponents.first { scout = Scout.make(l, opponent: o) }
        case "poster": tab = .matches; poster = l.matches.first { $0.isLive } ?? l.matches.first
        case "shop": shop = true
        case "widgets", "lockscreen": showcase = true
        case "plan": plan = true
        case "challenge": challenge = true
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    @Environment(\.requestReview) private var requestReview

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
        .fullScreenCover(item: $router.scoring, onDismiss: { router.resumeSecondServe = false }) { m in LiveMatchView(match: m, secondServe: router.resumeSecondServe) }
        .sheet(isPresented: $router.plan) { PlanSheet().presentationBackground(Gold.ink) }
        .sheet(isPresented: $router.challenge) { ChallengeSheet().presentationBackground(Gold.ink) }
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
        .onChange(of: router.happy) { _, _ in askForReview() }
        .onChange(of: router.wantsPlus) { _, on in if on { router.wantsPlus = false; pro.paywall = .plus } }
    }

    /// At most once per version, after something good, never on launch.
    private func askForReview() {
        guard !Shots.on, !Autopilot.on, ledger.matches.count + ledger.sessions.count >= 4 else { return }
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard UserDefaults.standard.string(forKey: "review.asked") != v else { return }
        UserDefaults.standard.set(v, forKey: "review.asked")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { requestReview() }
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
