import SwiftUI

/// Drives the real screens through a typical first use, for the App Review
/// recording (-demoAutoplay). It only sends cues; each screen performs the same
/// action its own buttons would, so what is recorded is the shipping code path.
@Observable
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }
    /// The App Store preview video: about 25 seconds through what is new, on the sample ledger.
    static var preview: Bool { ProcessInfo.processInfo.arguments.contains("-demoPreview") }

    private(set) var tick = 0
    private(set) var cue = ""
    private var running = false

    @MainActor private func send(_ c: String, then pause: Double = 0.7) async {
        cue = c; tick += 1
        try? await Task.sleep(for: .seconds(pause))
    }

    @MainActor private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    @MainActor
    func runPreview(_ router: Router, _ l: Ledger) {
        guard Autopilot.preview, !running else { return }
        running = true
        Task { @MainActor in
            await wait(2.0)
            // Score a few points live.
            if var m = l.matches.first(where: { $0.isLive }) {
                m.id = UUID(); m.points = Array(m.points.prefix(m.points.count - 12)); router.scoring = m
            }
            await wait(1.6)
            for c in ["score.won", "score.ace", "score.lost", "score.winner", "score.won", "score.error", "score.won"] { await send(c, then: 0.75) }
            await wait(1.0)
            router.scoring = nil
            await wait(0.8)
            // The Lock Screen: the live score with its buttons, and the widgets.
            withAnimation { router.showcase = true }
            await wait(3.4)
            withAnimation { router.showcase = false }
            await wait(0.6)
            // This week's plan.
            router.plan = true
            await wait(3.4)
            router.plan = false
            await wait(0.8)
            // Pressure points and the stat book.
            withAnimation { router.tab = .stats }
            await wait(3.0)
            // Scout the rematch.
            withAnimation { router.tab = .matches }
            await wait(1.0)
            if let o = l.opponents.first { router.scout = Scout.make(l, opponent: o) }
            await wait(3.0)
            router.scout = nil
            await wait(0.8)
            // The monthly challenge.
            withAnimation { router.tab = .home }
            await wait(1.2)
            router.challenge = true
            await wait(3.0)
            router.challenge = false
            await wait(1.0)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? Data().write(to: docs.appendingPathComponent("demo_done"))
        }
    }

    @MainActor
    func run(_ router: Router) {
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(3)

            // A hitting session.
            router.live = PracticeSession()
            await wait(2)
            for c in ["live.in", "live.in", "live.winner", "live.in", "live.net", "live.in", "live.in", "live.long", "live.winner", "live.in"] {
                await send(c)
            }
            await wait(1)
            await send("live.serve", then: 1.6)
            for c in ["live.zoneT", "live.zoneWide", "live.fault", "live.zoneT", "live.ace", "live.zoneBody"] {
                await send(c)
            }
            await wait(1.2)
            await send("live.finish", then: 2.2)

            // Journal it.
            for c in ["fin.rating", "fin.mood", "fin.place", "fin.focus", "fin.cue", "fin.workOn"] {
                await send(c, then: 0.9)
            }
            await wait(1)
            await send("fin.save", then: 3)

            // Log a match.
            router.editingMatch = Match()
            await wait(2)
            for c in ["match.opponent", "match.set1", "match.set2", "match.serve", "match.worked"] {
                await send(c, then: 1.3)
            }
            await wait(1)
            await send("match.save", then: 3)

            // The saved data, tab by tab.
            for t in [Tab.journal, .matches, .stats, .gear, .home] {
                withAnimation { router.tab = t }
                await wait(3)
            }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? Data().write(to: docs.appendingPathComponent("demo_done"))
        }
    }
}

extension View {
    /// Runs `handle` for every autopilot cue. Inert outside -demoAutoplay.
    func onCue(_ handle: @escaping (String) -> Void) -> some View {
        onChange(of: Autopilot.shared.tick) { _, _ in handle(Autopilot.shared.cue) }
    }
}
