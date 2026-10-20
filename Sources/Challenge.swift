import SwiftUI

// MARK: - The monthly challenge (free for everyone)

struct ChallengeTarget: Identifiable {
    let id: String
    let icon: String
    let title: String
    let have: Int
    let need: Int
    var done: Bool { have >= need }
    var progress: Double { min(1, Double(have) / Double(max(1, need))) }
}

struct MonthChallenge {
    let key: String          // "2026-11"
    let month: String        // "November"
    let name: String         // "The Serve Challenge"
    let blurb: String
    let daysLeft: Int
    let targets: [ChallengeTarget]
    var complete: Bool { targets.allSatisfy(\.done) }
}

/// Four themes that rotate through the year, counted automatically from what is logged that month.
/// November is the Serve Challenge, December the Rally Challenge, January the Match Challenge,
/// February the Pressure Challenge, and round again.
enum Challenges {
    static let themes = ["Serve", "Rally", "Match", "Pressure"]

    static func theme(for date: Date) -> Int { (Calendar.current.component(.month, from: date) + 1) % 4 }

    static func current(_ l: Ledger, date: Date = .now) -> MonthChallenge {
        let cal = Calendar.current
        let month = cal.dateInterval(of: .month, for: date)!
        let sessions = l.sessions.filter { month.contains($0.date) }
        let matches = l.matches.filter { month.contains($0.date) }
        let blocks = sessions.flatMap(\.blocks)
        let t = Shots.on ? 0 : theme(for: date)
        var targets: [ChallengeTarget] = []
        switch t {
        case 0:
            targets = [
                .init(id: "serves", icon: "arrow.up.to.line", title: "Hit 300 practice serves", have: blocks.filter(\.stroke.isServe).reduce(0) { $0 + $1.balls }, need: 300),
                .init(id: "fs60", icon: "percent", title: "60% first serves in a match", have: matches.filter { $0.firstServesTotal >= 10 && $0.firstServePct >= 60 }.count, need: 1),
                .init(id: "sessions", icon: "calendar", title: "Practise 6 times", have: sessions.count, need: 6),
            ]
        case 1:
            targets = [
                .init(id: "rally20", icon: "arrow.left.arrow.right", title: "A 20-ball rally", have: blocks.flatMap(\.rallies).max() ?? 0, need: 20),
                .init(id: "minutes", icon: "clock", title: "600 minutes on court", have: sessions.reduce(0) { $0 + $1.minutes }, need: 600),
                .init(id: "sessions", icon: "calendar", title: "Practise 8 times", have: sessions.count, need: 8),
            ]
        case 2:
            targets = [
                .init(id: "live", icon: "tennisball.fill", title: "Score 3 matches live", have: matches.filter(\.isLive).count, need: 3),
                .init(id: "wins", icon: "trophy.fill", title: "Win 2 matches", have: matches.filter(\.won).count, need: 2),
                .init(id: "notes", icon: "pencil.line", title: "Write what worked, 3 times", have: matches.filter { !$0.whatWorked.isEmpty }.count, need: 3),
            ]
        default:
            targets = [
                .init(id: "tb", icon: "flag.checkered", title: "Win a tiebreak set", have: matches.flatMap(\.sets).filter { $0.won && ($0.tiebreak != nil || $0.me == 7 && $0.them == 6) }.count, need: 1),
                .init(id: "bp", icon: "bolt.fill", title: "Convert 5 break points", have: matches.reduce(0) { $0 + $1.breakPointsWon }, need: 5),
                .init(id: "live", icon: "tennisball.fill", title: "Score 2 matches live", have: matches.filter(\.isLive).count, need: 2),
            ]
        }
        let blurbs = [
            "Thirty days of serving with purpose: volume in practice, percentage in matches.",
            "Thirty days of making one more ball: longer rallies, more court time.",
            "Thirty days of competing: score your matches, win a couple, learn from each.",
            "Thirty days of the big points: tiebreaks, break points, live scoring.",
        ]
        let left = max(0, cal.dateComponents([.day], from: cal.startOfDay(for: date), to: month.end).day ?? 0)
        let key = date.formatted(.iso8601.year().month())
        return MonthChallenge(key: key, month: date.formatted(.dateTime.month(.wide)), name: "The \(themes[t]) Challenge",
                              blurb: blurbs[t], daysLeft: left, targets: targets)
    }

    /// Months completed, newest first: the medal cabinet.
    static var won: [String] { (UserDefaults.standard.stringArray(forKey: "challenge.won") ?? []).sorted(by: >) }
    /// Records a finished month once. True the first time, for the celebration.
    @discardableResult static func record(_ c: MonthChallenge) -> Bool {
        guard c.complete, !Shots.on else { return false }
        var w = won
        guard !w.contains(c.key) else { return false }
        w.append(c.key)
        UserDefaults.standard.set(w, forKey: "challenge.won")
        return true
    }
}

struct ChallengeCard: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    var body: some View {
        let c = Challenges.current(ledger)
        return Button { router.challenge = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    ForEach(Array(c.targets.enumerated()), id: \.offset) { i, t in
                        FoilRing(progress: t.progress, width: 5).frame(width: 74 - CGFloat(i) * 16, height: 74 - CGFloat(i) * 16)
                    }
                    Image(systemName: c.complete ? "medal.fill" : "flag.fill").font(.system(size: 13, weight: .bold)).foil()
                }
                .frame(width: 74, height: 74)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("\(c.month) challenge · \(c.daysLeft) days left")
                    Text(c.name).font(.display(20, .medium)).foregroundStyle(Gold.ivory)
                    Text(c.complete ? "Complete. The medal is yours." : "\(c.targets.filter(\.done).count) of \(c.targets.count) done. " + (c.targets.first { !$0.done }?.title ?? ""))
                        .font(.body(12.5)).foregroundStyle(Gold.muted).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .card(padding: 16)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(c.name), \(c.targets.filter(\.done).count) of \(c.targets.count) targets done")
    }
}

struct ChallengeSheet: View {
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let c = Challenges.current(ledger)
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SheetHeader(eyebrow: "\(c.month) challenge · \(c.daysLeft) days left", title: c.name) { dismiss() }.padding(.horizontal, -20)
                    Text(c.blurb + " Everything counts by itself from what you log.").font(.body(14)).foregroundStyle(Gold.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(c.targets) { t in
                        HStack(spacing: 14) {
                            ZStack {
                                FoilRing(progress: t.progress, width: 6).frame(width: 52, height: 52)
                                Image(systemName: t.done ? "checkmark" : t.icon).font(.body(15, .bold)).foil()
                                    .symbolEffect(.bounce, value: t.done)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(t.title).font(.display(18, .medium)).foregroundStyle(Gold.ivory)
                                Text("\(min(t.have, t.need)) of \(t.need)").font(.body(12.5)).foregroundStyle(Gold.muted)
                            }
                            Spacer()
                        }
                        .card(padding: 14, radius: 20)
                        .accessibilityElement(children: .combine)
                    }
                    if c.complete {
                        HStack(spacing: 12) {
                            Image(systemName: "medal.fill").font(.system(size: 30)).foil()
                            Text("Complete. Your \(c.month) medal is in the cabinet.").font(.display(17)).foregroundStyle(Gold.ivory)
                        }
                        .frame(maxWidth: .infinity).card(padding: 18)
                    }
                    if !Challenges.won.isEmpty {
                        Eyebrow("Medal cabinet")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(Challenges.won, id: \.self) { k in
                                VStack(spacing: 4) {
                                    Image(systemName: "medal.fill").font(.system(size: 26)).foil()
                                    Text(k).font(.body(10.5, .semibold)).foregroundStyle(Gold.muted)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Gold.lacquer))
                            }
                        }
                    }
                    Text("A new challenge on the first of every month: Serve, Rally, Match, Pressure.").font(.body(11.5)).foregroundStyle(Gold.faint)
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
    }
}
