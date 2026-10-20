import SwiftUI

// MARK: - The weekly practice plan (Plus)

struct Drill: Identifiable, Hashable {
    let id: String
    let icon: String
    let title: String
    /// Why this drill, in the user's own numbers.
    let why: String
    let target: String
    let minutes: Int
    /// What to put on the session when it's started from the plan.
    let stroke: Stroke
}

struct WeekPlan {
    let week: String
    let focus: String
    let drills: [Drill]
    /// False when there is not enough logged yet and the plan is the general one.
    let personal: Bool
    var minutes: Int { drills.reduce(0) { $0 + $1.minutes } }
}

/// Builds this week's plan on the phone from the ledger: the weakest stroke, the most common miss,
/// the serve, the double faults, the big points. Different every week: the order of the candidates
/// that are close in need rotates with the week number.
enum Planner {
    static func make(_ l: Ledger, week: String = Extras.week) -> WeekPlan {
        let since = Calendar.current.date(byAdding: .day, value: -60, to: .now) ?? .distantPast
        let recent = l.sessions.filter { $0.date >= since }
        let blocks = (recent.isEmpty ? l.sessions : recent).flatMap(\.blocks)
        let ms = Array(l.matches.prefix(10))
        var cands: [(need: Double, drill: Drill)] = []

        // The weakest groundstroke by in-play rate, from practice.
        let ground: [Stroke] = [.forehand, .backhand, .ret, .volley, .slice]
        let rates: [(Stroke, Double, Int)] = ground.compactMap { st in
            let bs = blocks.filter { $0.stroke == st }
            let balls = bs.reduce(0) { $0 + $1.balls }
            guard balls >= 20 else { return nil }
            return (st, pctValue(bs.reduce(0) { $0 + $1.made + $1.winners }, balls), balls)
        }
        if let worst = rates.min(by: { $0.1 < $1.1 }) {
            let r = Int(worst.1.rounded())
            cands.append((Double(100 - r) + 10, Drill(id: "stroke-\(worst.0.rawValue)", icon: worst.0.icon,
                title: "\(worst.0.rawValue): margin first",
                why: "\(worst.0.rawValue) is your least reliable shot in practice: \(r)% in play over \(worst.2) balls.",
                target: "4 sets of 25, cross-court, a metre over the net. Beat \(min(95, r + 5))% in.", minutes: 20, stroke: worst.0)))
        }

        // The most common miss.
        var errs: [StrokeError: Int] = [:]
        for b in blocks { for (k, v) in b.errors { errs[k, default: 0] += v } }
        let errTotal = errs.values.reduce(0, +)
        if errTotal >= 15, let top = errs.max(by: { $0.value < $1.value }) {
            let share = pct(top.value, errTotal)
            let fix: String
            switch top.key {
            case .net: fix = "Rally to a target zone well above the net tape: aim twice as high as feels right. 3 x 20-ball rallies with no net errors."
            case .long: fix = "More spin, less flat drive: rally inside the service line for 5 minutes, then extend to the baseline. 50 balls landing in the back third."
            case .wide: fix = "Aim through the middle third of the court. 3 rallies of 20 where every ball lands inside the singles sideline by a metre."
            case .framed: fix = "Eyes on the contact point and a slower take-back. 40 balls at 70% pace, then 20 at full."
            }
            cands.append((Double(Int(share) ?? 30) * 0.8, Drill(id: "miss-\(top.key.rawValue)", icon: "scope",
                title: "Cut the \(top.key.rawValue.lowercased()) misses",
                why: "\(top.key.rawValue) is \(share)% of your errors in practice.", target: fix, minutes: 15, stroke: .forehand)))
        }

        // First serve percentage in matches, or in practice if there are no matches yet.
        let fsTotal = ms.reduce(0) { $0 + $1.firstServesTotal }
        let practiceFirst = blocks.filter { $0.stroke == .serve && $0.serveNumber == .first }
        let pBalls = practiceFirst.reduce(0) { $0 + $1.balls }
        let fs: Double? = fsTotal >= 20 ? pctValue(ms.reduce(0) { $0 + $1.firstServesIn }, fsTotal)
                        : pBalls >= 20 ? pctValue(practiceFirst.reduce(0) { $0 + $1.made + $1.winners }, pBalls) : nil
        if let fs {
            let r = Int(fs.rounded())
            cands.append((max(0, 68 - fs) * 1.6 + 8, Drill(id: "first-serve", icon: "arrow.up.to.line",
                title: "First serve rhythm",
                why: "Your first serve goes in \(r)% of the time" + (fsTotal >= 20 ? " across your last \(ms.count) matches." : " in practice."),
                target: "60 first serves, 30 a side, at 85% pace. Aim for \(min(75, max(60, r + 6)))% in, then add 5% pace.", minutes: 20, stroke: .serve)))
        }

        // Double faults.
        if !ms.isEmpty {
            let df = Double(ms.reduce(0) { $0 + $1.doubleFaults }) / Double(ms.count)
            if df >= 1.5 {
                cands.append((df * 9, Drill(id: "second-serve", icon: "arrow.up.forward",
                    title: "Second serve you trust",
                    why: "You average \(String(format: "%.1f", df)) double faults a match.",
                    target: "50 second serves with full spin and height. Count in tens: a miss restarts the ten. Log them as 2nd serves.", minutes: 15, stroke: .serve)))
            }
            // Break points.
            let bpC = ms.reduce(0) { $0 + $1.breakPointChances }, bpW = ms.reduce(0) { $0 + $1.breakPointsWon }
            if bpC >= 5 {
                let c = pctValue(bpW, bpC)
                cands.append((max(0, 50 - c) * 1.3 + 4, Drill(id: "return", icon: "arrow.uturn.left",
                    title: "Break point returns",
                    why: "You convert \(Int(c.rounded()))% of break points (\(bpW) of \(bpC)).",
                    target: "Partner serves second serves: 30 returns deep through the middle, no winners allowed. Then 10 off first serves.", minutes: 15, stroke: .ret)))
            }
            let bpF = ms.reduce(0) { $0 + $1.breakPointsFaced }, bpS = ms.reduce(0) { $0 + $1.breakPointsSaved }
            if bpF >= 5 {
                let sv = pctValue(bpS, bpF)
                cands.append((max(0, 62 - sv) * 1.2 + 3, Drill(id: "bp-serve", icon: "shield.lefthalf.filled",
                    title: "Serve under pressure",
                    why: "You save \(Int(sv.rounded()))% of break points you face.",
                    target: "Play serve games from 30-40 down: 10 games, first serve to your most reliable spot. Score them live.", minutes: 15, stroke: .serve)))
            }
            // Winners against errors.
            let w = ms.reduce(0) { $0 + $1.winners }, ue = ms.reduce(0) { $0 + $1.unforcedErrors }
            if ue > w, w + ue > 20 {
                cands.append((Double(ue - w) / Double(ms.count) * 3, Drill(id: "patience", icon: "tortoise.fill",
                    title: "Make one more ball",
                    why: "\(ue) unforced errors to \(w) winners in your last \(ms.count) matches.",
                    target: "Points from the baseline where you may only hit a winner off a short ball. Play to 11 three times.", minutes: 15, stroke: .points)))
            }
        }

        // Serve placement: the zone you use least.
        var zones: [Zone: Int] = [:]
        for b in blocks where b.stroke == .serve { for (k, v) in b.zones { zones[k, default: 0] += v } }
        let zTotal = zones.values.reduce(0, +)
        if zTotal >= 30, let least = Zone.allCases.min(by: { zones[$0, default: 0] < zones[$1, default: 0] }) {
            cands.append((Double(33 - (Int(pct(zones[least, default: 0], zTotal)) ?? 33)) + 6, Drill(id: "zone-\(least.rawValue)", icon: "square.grid.3x3.fill",
                title: "Find the \(least == .t ? "T" : least.rawValue.lowercased())",
                why: "Only \(pct(zones[least, default: 0], zTotal))% of your practice serves land \(least == .t ? "on the T" : least == .wide ? "wide" : "at the body").",
                target: "30 serves aimed \(least == .t ? "down the T" : least == .wide ? "out wide" : "into the body"), 15 a side. Tap where each lands.", minutes: 12, stroke: .serve)))
        }

        // Rally tolerance.
        let rallies = blocks.flatMap(\.rallies)
        if rallies.count >= 6 {
            let avg = Double(rallies.reduce(0, +)) / Double(rallies.count)
            if avg < 18 {
                cands.append((18 - avg + 5, Drill(id: "rally", icon: "arrow.left.arrow.right",
                    title: "Rally tolerance",
                    why: "Your counted rallies average \(Int(avg.rounded())) balls.",
                    target: "Cross-court, both wings: 5 rallies of \(Int(avg.rounded()) + 6). Use the rally counter.", minutes: 15, stroke: .forehand)))
            }
        }

        // Always-useful fillers so the plan has four drills even with little logged.
        let fillers: [Drill] = [
            Drill(id: "tiebreaks", icon: "flag.checkered", title: "Tiebreak practice",
                  why: "Tiebreaks are where close matches go. Practise the scoring and the nerves.",
                  target: "Three 10-point tiebreaks against a partner. Score them live in the app.", minutes: 20, stroke: .points),
            Drill(id: "transition", icon: "figure.tennis", title: "Approach and volley",
                  why: "Finishing at the net shortens points you are already winning.",
                  target: "Short ball, approach down the line, first volley deep, second volley angled. 3 x 10.", minutes: 15, stroke: .volley),
            Drill(id: "footwork", icon: "figure.run", title: "Split step and recover",
                  why: "Most errors start with late feet.",
                  target: "Cross-court rally, recover to the middle after every ball. Partner calls 'split' on each contact. 4 x 3 minutes.", minutes: 12, stroke: .forehand),
            Drill(id: "serve-plus-one", icon: "arrow.up.right", title: "Serve plus one",
                  why: "The first ball after your serve decides most of your service points.",
                  target: "Serve, then hit the next ball to the open court. 20 points a side.", minutes: 15, stroke: .points),
        ]
        let personal = !cands.isEmpty
        let v = weekNumber(week)
        var picked: [Drill] = []
        let sorted = cands.sorted { $0.need > $1.need }.map(\.drill)
        // The two biggest needs every week, then the rest rotate.
        picked += sorted.prefix(2)
        var rest = Array(sorted.dropFirst(2)) + fillers.filter { f in !sorted.contains { $0.id == f.id } }
        if !rest.isEmpty { rest = Array(rest[(v % rest.count)...] + rest[..<(v % rest.count)]) }
        for d in rest where picked.count < 4 && !picked.contains(where: { $0.id == d.id }) { picked.append(d) }
        let focus = picked.first.map { personal ? $0.title : "A solid all-round week" } ?? "A solid all-round week"
        return WeekPlan(week: week, focus: focus, drills: picked, personal: personal)
    }

    static func weekNumber(_ week: String) -> Int { Int(week.split(separator: "-").last ?? "0") ?? 0 }

    private static func doneKey(_ week: String) -> String { "plan.done." + week }
    static func done(_ week: String) -> Set<String> { Set(UserDefaults.standard.stringArray(forKey: doneKey(week)) ?? []) }
    static func toggle(_ id: String, week: String) {
        var s = done(week)
        if s.contains(id) { s.remove(id) } else { s.insert(id) }
        UserDefaults.standard.set(Array(s), forKey: doneKey(week))
    }
}

/// This week's plan on Home: the focus and the first drill for everyone; the whole plan with Plus.
struct PlanCard: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    var body: some View {
        let plan = Planner.make(ledger)
        let done = Planner.done(plan.week)
        return Button { if pro.plusActive { router.plan = true } else { pro.ask(.plan) } } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow("This week's plan")
                    Spacer()
                    Text("\(done.intersection(plan.drills.map(\.id)).count)/\(plan.drills.count) · \(plan.minutes) min").font(.body(11.5, .semibold)).foregroundStyle(Gold.muted)
                }
                Text(plan.focus).font(.display(22, .medium)).foregroundStyle(Gold.ivory)
                if let first = plan.drills.first {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: first.icon).font(.body(13, .bold)).foil().frame(width: 22)
                        Text(first.why).font(.body(13)).foregroundStyle(Gold.ivory.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 6) {
                    ForEach(plan.drills.dropFirst()) { d in
                        Label(d.title, systemImage: pro.plusActive ? d.icon : "lock.fill").labelStyle(.titleAndIcon)
                            .font(.body(11, .semibold)).foregroundStyle(Gold.pale).lineLimit(1)
                            .padding(.horizontal, 9).frame(height: 24).background(Capsule().fill(Gold.leaf.opacity(0.1)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).clipped()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(PressStyle())
        .accessibilityHint(pro.plusActive ? "Opens the full plan" : "The full plan comes with Plus")
    }
}

/// The whole week: every drill with why, the target and a Start button that opens practice on that stroke.
struct PlanSheet: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var tick = 0

    var body: some View {
        let plan = Planner.make(ledger)
        let done = Planner.done(plan.week)
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SheetHeader(eyebrow: "This week's plan · \(plan.minutes) min", title: plan.focus) { dismiss() }.padding(.horizontal, -20)
                    Text(plan.personal ? "Built on your phone from what you've logged. A new plan every Monday."
                                       : "Log a few sessions and matches and the plan starts working from your own numbers.")
                        .font(.body(13.5)).foregroundStyle(Gold.muted)
                    ForEach(Array(plan.drills.enumerated()), id: \.element.id) { i, d in
                        let on = done.contains(d.id)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Text("\(i + 1)").font(.figure(16)).foregroundStyle(Gold.ink).frame(width: 28, height: 28).background(Circle().fill(Gold.foil))
                                Text(d.title).font(.display(19, .medium)).foregroundStyle(on ? Gold.muted : Gold.ivory).strikethrough(on, color: Gold.leaf)
                                Spacer()
                                Text("\(d.minutes) min").font(.body(11.5, .semibold)).foregroundStyle(Gold.muted)
                            }
                            Text(d.why).font(.body(13.5)).foregroundStyle(Gold.pale).fixedSize(horizontal: false, vertical: true)
                            Text(d.target).font(.body(14)).foregroundStyle(Gold.ivory.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 10) {
                                Button {
                                    Haptic.tap(); Planner.toggle(d.id, week: plan.week); tick += 1
                                } label: {
                                    Label(on ? "Done" : "Mark done", systemImage: on ? "checkmark.seal.fill" : "seal")
                                        .font(.body(13, .semibold)).foregroundStyle(on ? Gold.ink : Gold.ivory)
                                        .padding(.horizontal, 12).frame(height: 34)
                                        .background(Capsule().fill(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi)))
                                }
                                .buttonStyle(PressStyle())
                                .symbolEffect(.bounce, value: on)
                                Button {
                                    dismiss()
                                    var s = PracticeSession(); s.focus = d.title
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { router.live = s }
                                } label: {
                                    Label("Start", systemImage: "play.fill").font(.body(13, .semibold)).foil()
                                        .padding(.horizontal, 12).frame(height: 34).overlay(Capsule().strokeBorder(Gold.hairline))
                                }
                                .buttonStyle(PressStyle())
                            }
                        }
                        .card(padding: 16)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
                .id(tick)
            }
        }
    }
}
