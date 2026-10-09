import ActivityKit
import SwiftUI
import WidgetKit

/// What the widgets show, written by the app after every save. Small, so a widget never reads the whole ledger.
struct Glance: Codable {
    var won = 0
    var lost = 0
    var winStreak = 0
    var weekMinutes = 0
    var weeklyTarget = 300
    var streakWeeks = 0
    /// Oldest first, up to ten: true for a win.
    var recent: [Bool] = []
    var firstServePct: Int?
    var bpConverted: Int?
    var lastOpponent = ""
    var lastScore = ""
    var lastWon = false
    var racquet = ""
    var freshness: Double?
    var unlocked = false

    static let key = "glance"
    static func load() -> Glance {
        guard let d = Shared.defaults.data(forKey: key), let g = try? JSONDecoder().decode(Glance.self, from: d) else { return Glance() }
        return g
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { Shared.defaults.set(d, forKey: Glance.key) }
    }
    static var sample: Glance {
        Glance(won: 9, lost: 4, winStreak: 3, weekMinutes: 210, weeklyTarget: 300, streakWeeks: 7,
               recent: [true, false, true, true, false, true, false, true, true, true], firstServePct: 61, bpConverted: 44,
               lastOpponent: "Chris Maddox", lastScore: "6-4  7-6(5)", lastWon: true, racquet: "Pure Aero 98", freshness: 0.37, unlocked: true)
    }
}

/// A match being scored, on the Lock Screen and in the Dynamic Island.
struct MatchActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var me: [Int]
        var them: [Int]
        var pointMe: String
        var pointThem: String
        var iServe: Bool
        var status: String
    }
    var opponent: String
}

// MARK: Views

/// Small: the record, the win streak and this week's hitting.
struct RecordGlanceView: View {
    let g: Glance
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RECORD").font(.body(9, .semibold)).tracking(1.6).foregroundStyle(Gold.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(g.won)").font(.figure(36, .light)).foil()
                Text("–").font(.figure(24, .ultraLight)).foregroundStyle(Gold.muted)
                Text("\(g.lost)").font(.figure(36, .light)).foregroundStyle(Gold.ivory.opacity(0.55))
            }
            .minimumScaleFactor(0.6)
            Text(g.winStreak > 1 ? "\(g.winStreak) wins in a row" : g.lastOpponent.isEmpty ? "Log a match to start" : "\(g.lastWon ? "Beat" : "Lost to") \(g.lastOpponent)")
                .font(.body(10.5, .semibold)).foregroundStyle(Gold.ivory.opacity(0.8)).lineLimit(1)
            Spacer(minLength: 0)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Gold.leaf.opacity(0.15))
                    Capsule().fill(Gold.foil).frame(width: geo.size.width * min(1, Double(g.weekMinutes) / Double(max(1, g.weeklyTarget))))
                }
            }.frame(height: 5)
            Text("\(g.weekMinutes) of \(g.weeklyTarget) min this week").font(.body(9.5)).foregroundStyle(Gold.muted)
        }
    }
}

/// Medium: the last ten results, the serve and the strings.
struct FormGlanceView: View {
    let g: Glance
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("FORM").font(.body(9, .semibold)).tracking(1.6).foregroundStyle(Gold.muted)
                Text("\(g.won)–\(g.lost)").font(.figure(30, .light)).foil()
                Spacer(minLength: 0)
                stat("1st serve", g.firstServePct.map { "\($0)%" } ?? "–")
                stat("BP won", g.bpConverted.map { "\($0)%" } ?? "–")
            }.frame(width: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text("LAST \(g.recent.count)").font(.body(9, .semibold)).tracking(1.6).foregroundStyle(Gold.muted)
                HStack(spacing: 4) {
                    ForEach(Array(g.recent.enumerated()), id: \.offset) { _, w in
                        Text(w ? "W" : "L").font(.body(10, .bold))
                            .foregroundStyle(w ? Gold.ink : Gold.ivory.opacity(0.7))
                            .frame(width: 19, height: 19)
                            .background(Circle().fill(w ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi)))
                    }
                }
                if !g.lastOpponent.isEmpty {
                    Text("\(g.lastScore) vs \(g.lastOpponent)").font(.body(11, .semibold)).foregroundStyle(Gold.ivory).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let f = g.freshness {
                    HStack(spacing: 6) {
                        Image(systemName: "tennis.racket").font(.system(size: 11)).foregroundStyle(Gold.leaf)
                        Text(f < 0.25 ? "\(g.racquet): time to restring" : "\(g.racquet) strings \(Int((f * 100).rounded()))% fresh")
                            .font(.body(10.5)).foregroundStyle(f < 0.25 ? Gold.bad : Gold.muted).lineLimit(1)
                    }
                }
            }
        }
    }
    private func stat(_ l: String, _ v: String) -> some View {
        HStack { Text(l).font(.body(10)).foregroundStyle(Gold.muted); Spacer(); Text(v).font(.figure(12)).foregroundStyle(Gold.ivory) }
    }
}

/// The free plan's medium widget.
struct LockedGlanceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "lock.fill").font(.system(size: 15, weight: .semibold)).foil()
            Text("Baseline Ledger Pro").font(.display(17, .medium)).foregroundStyle(Gold.ivory)
            Text("Your last ten results, serve numbers and string life on the Home Screen come with Pro. The Record widget is free.")
                .font(.body(11)).foregroundStyle(Gold.muted)
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The Lock Screen card for a match being scored.
struct MatchLiveView: View {
    let opponent: String
    let s: MatchActivity.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(opponent.isEmpty ? "LIVE MATCH" : "VS \(opponent.uppercased())").font(.body(10, .semibold)).tracking(1.4).foregroundStyle(Gold.muted).lineLimit(1)
                Spacer()
                if !s.status.isEmpty { Text(s.status.uppercased()).font(.body(9.5, .bold)).tracking(1.2).foregroundStyle(Gold.leaf) }
            }
            line("You", s.me, s.pointMe, serving: s.iServe)
            line("Them", s.them, s.pointThem, serving: !s.iServe)
        }
        .padding(16)
    }
    private func line(_ name: String, _ games: [Int], _ point: String, serving: Bool) -> some View {
        HStack(spacing: 8) {
            Circle().fill(serving ? Gold.leaf : .clear).frame(width: 7, height: 7)
            Text(name).font(.display(17, .medium)).foregroundStyle(Gold.ivory)
            Spacer()
            ForEach(Array(games.enumerated()), id: \.offset) { _, g in
                Text("\(g)").font(.figure(19)).foregroundStyle(Gold.ivory).frame(width: 22)
            }
            Text(point).font(.figure(19)).foregroundStyle(Gold.leaf).frame(width: 40, alignment: .trailing)
        }
    }
}
