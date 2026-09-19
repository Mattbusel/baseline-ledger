import SwiftUI

@main
struct BaselineLedgerApp: App {
    @State private var ledger: Ledger
    @State private var router = Router()

    init() {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.contains("-shot") || UserDefaults.standard.bool(forKey: "demoMode")
        _ledger = State(initialValue: Ledger(demo: demo))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(ledger)
                .environment(router)
                .preferredColorScheme(.dark)
                .tint(Gold.leaf)
                .onAppear { router.applyShotArgs(ledger); Autopilot.shared.run(router) }
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

    func applyShotArgs(_ l: Ledger) {
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
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
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
        .fullScreenCover(item: $router.live) { s in LiveSessionView(session: s) }
        .fullScreenCover(item: $router.finishing) { s in FinishSessionView(session: s) }
        .fullScreenCover(item: $router.editingMatch) { m in MatchEditorView(match: m) }
        .sheet(item: $router.viewing) { s in SessionDetailView(session: s).presentationBackground(Gold.ink) }
    }
}

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
