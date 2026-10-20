import SwiftUI

/// The points that decide matches, read from every match scored live: how often you hold and break,
/// and how you play the tight points inside a game. Plus.
struct Pressure {
    var matches = 0
    var serviceGames = 0, held = 0
    var returnGames = 0, broke = 0
    var tightPoints = 0, tightWon = 0          // 30-30, deuce and no-ad deciding points
    var firstPoints = 0, firstWon = 0          // the first point of each game
    var tbPoints = 0, tbWon = 0                // tiebreak points
    var gamePoints = 0, gamePointsWon = 0      // your game points on serve
    var afterBreak = 0, consolidated = 0       // service games right after breaking

    static func read(_ ms: [Match]) -> Pressure {
        var p = Pressure()
        for m in ms where m.isLive {
            p.matches += 1
            let f = m.scoring ?? LiveFormat()
            var justBroke = false
            _ = ScoreState.replay(m.points, f) { b, pt, a in
                if b.tiebreak {
                    p.tbPoints += 1; if pt.iWon { p.tbWon += 1 }
                    return
                }
                if b.gameMe == 0 && b.gameThem == 0 { p.firstPoints += 1; if pt.iWon { p.firstWon += 1 } }
                if b.gameMe >= 2 && b.gameMe == b.gameThem { p.tightPoints += 1; if pt.iWon { p.tightWon += 1 } }
                // Game point on your serve: 40-x or advantage (and the deciding point, no-ad).
                if b.iServe && b.gameMe >= 3 && (f.noAd ? b.gameMe >= b.gameThem : b.gameMe > b.gameThem) {
                    p.gamePoints += 1; if pt.iWon { p.gamePointsWon += 1 }
                }
                // A game ended on this point if the games in the set moved, or a set was completed.
                let before = b.sets.reduce(0) { $0 + $1.me + $1.them }, after = a.sets.reduce(0) { $0 + $1.me + $1.them }
                guard after != before || a.sets.count != b.sets.count || a.over else { return }
                if b.iServe {
                    p.serviceGames += 1
                    if pt.iWon { p.held += 1 }
                    if justBroke { p.afterBreak += 1; if pt.iWon { p.consolidated += 1 } }
                    justBroke = false
                } else {
                    p.returnGames += 1
                    if pt.iWon { p.broke += 1; justBroke = true } else { justBroke = false }
                }
            }
        }
        return p
    }

    /// One line in plain words: where the close games are being won or lost.
    var summary: String {
        guard serviceGames + returnGames > 0 else { return "Score a match live and this fills in, point by point." }
        let hold = pctValue(held, serviceGames), tight = pctValue(tightWon, tightPoints)
        if tightPoints >= 8 && tight < 45 { return "You win \(Int(tight.rounded()))% of 30-all and deuce points. That is where your close games slip: play the high-percentage pattern there." }
        if afterBreak >= 3 && pctValue(consolidated, afterBreak) < 60 { return "You give breaks straight back: \(consolidated) of \(afterBreak) holds after breaking. Slow down on the change of ends and serve to your safest spot." }
        if serviceGames >= 6 && hold < 65 { return "You hold \(Int(hold.rounded()))% of service games. More first serves in will move this faster than more pace." }
        if tightPoints >= 8 && tight >= 55 { return "You win \(Int(tight.rounded()))% of the tight points. You're a closer: back yourself in long games." }
        return "Hold \(Int(hold.rounded()))%, break \(pct(broke, returnGames))%. Keep scoring live and the patterns sharpen."
    }
}

struct PressureCard: View {
    @Environment(Ledger.self) private var ledger
    var body: some View {
        let p = Pressure.read(ledger.matches)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Pressure points")
                Spacer()
                Text(p.matches == 1 ? "1 live match" : "\(p.matches) live matches").font(.body(11.5, .semibold)).foregroundStyle(Gold.muted)
            }
            HStack(spacing: 10) {
                tile(pct(p.held, p.serviceGames), "%", "service games held", "\(p.held) of \(p.serviceGames)")
                tile(pct(p.broke, p.returnGames), "%", "return games broken", "\(p.broke) of \(p.returnGames)")
            }
            HStack(spacing: 10) {
                tile(pct(p.tightWon, p.tightPoints), "%", "30-all and deuce", "\(p.tightWon) of \(p.tightPoints)")
                tile(pct(p.firstWon, p.firstPoints), "%", "first point of a game", "\(p.firstWon) of \(p.firstPoints)")
            }
            HStack(spacing: 10) {
                tile(pct(p.gamePointsWon, p.gamePoints), "%", "game points on serve", "\(p.gamePointsWon) of \(p.gamePoints)")
                tile(pct(p.tbWon, p.tbPoints), "%", "tiebreak points", "\(p.tbWon) of \(p.tbPoints)")
            }
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "flame.fill").font(.body(13, .bold)).foil()
                Text(p.summary).font(.body(13.5)).foregroundStyle(Gold.ivory.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private func tile(_ v: String, _ unit: String, _ l: String, _ of: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(v).font(.figure(24)).foil().contentTransition(.numericText())
                if v != "–" { Text(unit).font(.figure(13)).foregroundStyle(Gold.muted) }
            }
            Text(l).font(.body(11)).foregroundStyle(Gold.muted)
            Text(of).font(.body(10)).foregroundStyle(Gold.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Gold.ink.opacity(0.5)))
        .accessibilityElement(children: .combine)
    }
}
