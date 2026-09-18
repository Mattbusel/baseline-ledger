import SwiftUI

/// After the range: how it went, in your own words.
struct FinishSessionView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    @State var session: PracticeSession

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHeader(eyebrow: session.date.ledgerDay, title: "How did it go?") { dismiss() }
                        .padding(.horizontal, -20)
                    summary
                    VStack(spacing: 18) {
                        ratingRow("Session", $session.rating)
                        divider
                        ratingRow("Mood", $session.mood)
                        divider
                        ratingRow("Energy", $session.energy)
                    }
                    .card()
                    LedgerField(label: "Where", text: $session.place, prompt: "Club, court number, park")
                    LedgerField(label: "Hitting partner", text: $session.partner, prompt: "Coach, friend, ball machine")
                    LedgerField(label: "Focus", text: $session.focus, prompt: "What were you working on?")
                    LedgerField(label: "Cue", text: $session.cue, prompt: "The one thought that worked")
                    LedgerField(label: "What clicked", text: $session.clicked, prompt: "Keep this", multiline: true)
                    LedgerField(label: "Work on next", text: $session.workOn, prompt: "Carry this into next time", multiline: true)
                    LedgerField(label: "Journal", text: $session.journal, prompt: "Anything else. Feel, conditions, what your coach said.", multiline: true)
                    FoilButton("Save to ledger", icon: "checkmark.seal.fill") {
                        ledger.upsert(session); Haptic.done(); dismiss()
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
        }
    }

    private var divider: some View { Rectangle().fill(Gold.leaf.opacity(0.1)).frame(height: 0.8) }

    private func ratingRow(_ label: String, _ v: Binding<Int>) -> some View {
        HStack {
            Text(label).font(.display(18)).foregroundStyle(Gold.ivory)
            Spacer()
            DiamondRating(value: v, size: 22)
        }
    }

    private var summary: some View {
        let strokes = session.blocks.filter { !$0.stroke.isServe }
        let serves = session.blocks.filter(\.stroke.isServe)
        let inPlay = strokes.reduce(0) { $0 + $1.made + $1.winners }, hit = strokes.reduce(0) { $0 + $1.balls }
        let sIn = serves.reduce(0) { $0 + $1.made + $1.winners }, sAll = serves.reduce(0) { $0 + $1.balls }
        return HStack(spacing: 10) {
            StatTile(label: "Minutes", value: "\(session.minutes)")
            StatTile(label: "In play", value: pct(inPlay, hit), unit: "%")
            StatTile(label: "Serves in", value: pct(sIn, sAll), unit: "%")
        }
    }
}

/// Read view of one session: the journal first, then the numbers.
struct SessionDetailView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let session: PracticeSession

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    SheetHeader(eyebrow: session.date.ledgerDay, title: session.focus.isEmpty ? "Practice" : session.focus) { dismiss() }
                        .padding(.horizontal, -20).padding(.top, 10)
                    HStack(spacing: 16) {
                        Label("\(session.minutes) min", systemImage: "clock")
                        Label("\(session.balls) balls", systemImage: "tennisball")
                        if !session.place.isEmpty { Label(session.place, systemImage: "mappin").lineLimit(1) }
                    }
                    .font(.body(12.5, .medium)).foregroundStyle(Gold.muted)

                    if !session.partner.isEmpty || session.longestRally > 0 {
                        HStack(spacing: 16) {
                            if !session.partner.isEmpty { Label(session.partner, systemImage: "person.2") }
                            if session.longestRally > 0 { Label("Longest rally \(session.longestRally)", systemImage: "arrow.left.arrow.right") }
                        }
                        .font(.body(12.5, .medium)).foregroundStyle(Gold.pale)
                    }
                    if !session.cue.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("Cue")
                            Text("“\(session.cue)”").font(.display(24).italic()).foregroundStyle(Gold.ivory)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).card()
                    }
                    if !session.clicked.isEmpty { note("What clicked", session.clicked, "sparkles") }
                    if !session.workOn.isEmpty { note("Work on next", session.workOn, "arrow.turn.down.right") }
                    if !session.journal.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow("Journal")
                            Text(session.journal).font(.display(17)).foregroundStyle(Gold.ivory.opacity(0.9)).lineSpacing(5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).card()
                    }
                    ForEach(session.blocks) { b in BlockCard(block: b) }
                    HStack(spacing: 12) {
                        GhostButton("Edit notes", icon: "pencil") {
                            let s = session; dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { router.finishing = s }
                        }
                        GhostButton("Delete", icon: "trash") {
                            ledger.sessions.removeAll { $0.id == session.id }; dismiss()
                        }
                        .frame(width: 130)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
        }
    }

    private func note(_ title: String, _ text: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.body(14, .semibold)).foil().frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(title)
                Text(text).font(.body(15)).foregroundStyle(Gold.ivory.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .card(padding: 16, radius: 20)
    }
}

struct BlockCard: View {
    let block: StrokeBlock
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: block.stroke.icon).font(.body(15, .semibold)).foil()
                    .frame(width: 36, height: 36).background(Circle().fill(Gold.leaf.opacity(0.1)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(block.title).font(.body(15, .semibold)).foregroundStyle(Gold.ivory)
                    Text("\(block.balls) balls · \(block.winners) \(block.stroke.isServe ? "aces" : "winners")").font(.body(12)).foregroundStyle(Gold.muted)
                }
                Spacer()
                Text("\(Int(block.inRate.rounded()))%").font(.figure(24)).foil()
            }
            SplitBar(parts: [("In", block.made + block.winners)] + StrokeError.allCases.map { ($0.rawValue, block.errors[$0] ?? 0) })
            if block.stroke.isServe && !block.zones.isEmpty {
                ServiceBox(side: block.side, counts: block.zones).frame(height: 120).allowsHitTesting(false)
            }
            if !block.rallies.isEmpty {
                Text("Rallies: " + block.rallies.map(String.init).joined(separator: " · ") + "   best \(block.rallies.max() ?? 0)")
                    .font(.body(12, .medium)).foregroundStyle(Gold.pale)
            }
        }
        .card(padding: 16, radius: 20)
    }
}
