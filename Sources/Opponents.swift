import SwiftUI

// MARK: - Head to head

struct OpponentSummary: Identifiable, Hashable {
    let name: String
    let level: String
    let matches: [Match]
    var id: String { name.lowercased() }
    var won: Int { matches.filter(\.won).count }
    var lost: Int { matches.count - won }
    var last: Match? { matches.first }
}

extension Ledger {
    /// Everyone you've played, most recent first, matched on the name as typed (case-insensitive).
    var opponents: [OpponentSummary] {
        var groups: [String: [Match]] = [:]
        var order: [String] = []
        for m in matches {
            let n = m.opponent.trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty else { continue }
            let k = n.lowercased()
            if groups[k] == nil { order.append(k) }
            groups[k, default: []].append(m)
        }
        return order.compactMap { k in
            guard let ms = groups[k], let first = ms.first else { return nil }
            let level = ms.first { !$0.opponentLevel.isEmpty }?.opponentLevel ?? ""
            return OpponentSummary(name: first.opponent.trimmingCharacters(in: .whitespaces), level: level, matches: ms)
        }
    }

    /// The small summary the widgets read.
    func glance(unlocked: Bool, weeklyTarget: Int) -> Glance {
        let rec = record
        let last10 = Array(matches.prefix(10))
        let served = last10.filter { $0.firstServesTotal > 0 }
        let bpC = last10.reduce(0) { $0 + $1.breakPointChances }, bpW = last10.reduce(0) { $0 + $1.breakPointsWon }
        let last = matches.first
        return Glance(won: rec.won, lost: rec.lost, winStreak: matches.prefix(while: { $0.won }).count,
                      weekMinutes: minutes(inLast: 7), weeklyTarget: weeklyTarget, streakWeeks: practiceStreakWeeks,
                      recent: last10.reversed().map(\.won),
                      firstServePct: served.isEmpty ? nil : Int((served.reduce(0.0) { $0 + $1.firstServePct } / Double(served.count)).rounded()),
                      bpConverted: bpC == 0 ? nil : Int(pctValue(bpW, bpC).rounded()),
                      lastOpponent: last?.opponent ?? "", lastScore: last?.scoreline ?? "", lastWon: last?.won ?? false,
                      racquet: racquets.first?.name ?? "", freshness: racquets.first?.freshness, unlocked: unlocked)
    }
}

struct OpponentsView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    @State private var open: OpponentSummary?

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SheetHeader(eyebrow: "\(ledger.opponents.count) players", title: "Head to head") { dismiss() }.padding(.horizontal, -20)
                    if ledger.opponents.isEmpty {
                        Text("Everyone you log a match against shows up here, with your record against them and your notes.")
                            .font(.display(17)).foregroundStyle(Gold.muted).card()
                    }
                    ForEach(ledger.opponents) { o in
                        Button { open = o } label: { OpponentRow(o: o) }.buttonStyle(PressStyle())
                    }
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
        .sheet(item: $open) { o in OpponentDetail(name: o.name).presentationBackground(Gold.ink) }
    }
}

struct OpponentRow: View {
    let o: OpponentSummary
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Gold.lacquerHi)
                Circle().strokeBorder(Gold.hairline, lineWidth: 0.8)
                Text(o.name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined()).font(.display(17, .medium)).foil()
            }.frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(o.name).font(.display(19, .medium)).foregroundStyle(Gold.ivory).lineLimit(1)
                Text([o.level, o.last.map { "last " + $0.date.shortDay } ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.body(12)).foregroundStyle(Gold.muted).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(o.won)–\(o.lost)").font(.figure(22)).foregroundStyle(o.won >= o.lost ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.ivory.opacity(0.7)))
                Text("H2H").font(.body(9.5, .bold)).tracking(1.4).foregroundStyle(Gold.muted)
            }
        }
        .card(padding: 14, radius: 20)
    }
}

struct OpponentDetail: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Extras.self) private var extras
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let name: String
    @State private var notes = ""
    @State private var report: ScoutReport?
    @State private var shop = false

    private var o: OpponentSummary? { ledger.opponents.first { $0.id == name.lowercased() } }

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHeader(eyebrow: o?.level.isEmpty == false ? o!.level : "Opponent", title: name) { dismiss() }.padding(.horizontal, -20)
                    if let o {
                        HStack(spacing: 18) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("HEAD TO HEAD").font(.body(10, .semibold)).tracking(1.6).foregroundStyle(Gold.muted)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(o.won)").font(.figure(50, .light)).foil()
                                    Text("–").font(.figure(34, .ultraLight)).foregroundStyle(Gold.muted)
                                    Text("\(o.lost)").font(.figure(50, .light)).foregroundStyle(Gold.ivory.opacity(0.55))
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                let sw = o.matches.reduce(0) { $0 + $1.setsWon }, sl = o.matches.reduce(0) { $0 + $1.setsLost }
                                Text("Sets \(sw)–\(sl)").font(.figure(15)).foregroundStyle(Gold.ivory)
                                let served = o.matches.filter { $0.firstServesTotal > 0 }
                                if !served.isEmpty {
                                    Text("1st serve \(Int((served.reduce(0.0) { $0 + $1.firstServePct } / Double(served.count)).rounded()))%").font(.body(12)).foregroundStyle(Gold.muted)
                                }
                            }
                        }
                        .card(padding: 20, radius: 26)

                        scoutButton(o)

                        LedgerField(label: "Your notes on \(name.split(separator: " ").first.map(String.init) ?? "them")", text: $notes,
                                    prompt: "Lefty. Big forehand, chips the backhand. Struggles with high balls.", multiline: true)
                            .onChange(of: notes) { _, v in ledger.scouting[name.lowercased()] = v.isEmpty ? nil : v }

                        Eyebrow("Every match")
                        ForEach(o.matches) { m in
                            Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { router.editingMatch = m } } label: { MatchCard(match: m) }
                                .buttonStyle(PressStyle())
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
        .onAppear { notes = ledger.scouting[name.lowercased()] ?? "" }
        .sheet(item: $report) { r in ScoutSheet(report: r).presentationBackground(Gold.ink) }
        .sheet(isPresented: $shop) { ShopSheet().presentationBackground(Gold.ink) }
    }

    private func scoutButton(_ o: OpponentSummary) -> some View {
        Button {
            if extras.spendScout() { report = Scout.make(ledger, opponent: o) }
            else { Task { if await extras.buy(Extras.scoutsID), extras.spendScout() { report = Scout.make(ledger, opponent: o) } } }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "binoculars.fill").font(.body(18, .semibold)).foregroundStyle(Gold.ink)
                    .frame(width: 44, height: 44).background(Circle().fill(Gold.foil))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Scouting report").font(.display(18, .medium)).foregroundStyle(Gold.ivory)
                    Text(extras.freeScoutLeft ? "This week's free report is ready." : extras.scouts > 0 ? "\(extras.scouts) banked." : "3 more for \(extras.price(Extras.scoutsID)).")
                        .font(.body(12)).foregroundStyle(Gold.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.body(12, .bold)).foregroundStyle(Gold.muted)
            }
            .card(padding: 14, radius: 20)
        }
        .buttonStyle(PressStyle()).disabled(extras.busy != nil)
    }
}

// MARK: - Scouting report

struct ScoutReport: Identifiable {
    let id = UUID()
    let opponent: String
    let record: String
    let sections: [(title: String, body: String)]
    let plan: [String]
}

/// Built on the phone from your own matches. Nothing leaves the ledger.
enum Scout {
    /// Non-empty lines, each once, in order.
    static func unique(_ xs: [String]) -> [String] {
        var seen = Set<String>()
        return xs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    static func make(_ l: Ledger, opponent o: OpponentSummary) -> ScoutReport {
        let ms = o.matches
        let all = l.matches
        func avg(_ xs: [Match], _ f: (Match) -> Double) -> Double? { xs.isEmpty ? nil : xs.reduce(0) { $0 + f($1) } / Double(xs.count) }
        let served = ms.filter { $0.firstServesTotal > 0 }, servedAll = all.filter { $0.firstServesTotal > 0 }
        let fsVs = avg(served) { $0.firstServePct }, fsAll = avg(servedAll) { $0.firstServePct }
        let bpC = ms.reduce(0) { $0 + $1.breakPointChances }, bpW = ms.reduce(0) { $0 + $1.breakPointsWon }
        let bpF = ms.reduce(0) { $0 + $1.breakPointsFaced }, bpS = ms.reduce(0) { $0 + $1.breakPointsSaved }
        let w = ms.reduce(0) { $0 + $1.winners }, ue = ms.reduce(0) { $0 + $1.unforcedErrors }
        let wAll = all.reduce(0) { $0 + $1.winners }, ueAll = all.reduce(0) { $0 + $1.unforcedErrors }
        let df = avg(ms) { Double($0.doubleFaults) } ?? 0, dfAll = avg(all) { Double($0.doubleFaults) } ?? 0
        let first = o.name.split(separator: " ").first.map(String.init) ?? o.name

        var sections: [(String, String)] = []
        if let last = o.last {
            sections.append(("The record", "You're \(o.won)–\(o.lost) against \(first), \(ms.reduce(0) { $0 + $1.setsWon })–\(ms.reduce(0) { $0 + $1.setsLost }) in sets. Last time, \(last.date.formatted(.dateTime.month(.wide).day())): \(last.won ? "won" : "lost") \(last.scoreline)\(last.surface == .hard ? "" : " on \(last.surface.rawValue.lowercased())")."))
        }
        if let fsVs {
            let gap = fsAll.map { fsVs - $0 } ?? 0
            sections.append(("Your serve against them", "First serves in: \(Int(fsVs.rounded()))%" + (fsAll.map { " against \(Int($0.rounded()))% across all your matches" } ?? "") + ". " +
                             (gap < -4 ? "It drops against \(first): they're getting into your head on serve." : gap > 4 ? "Your serve travels well against them." : "About your usual.") +
                             " Double faults: \(String(format: "%.1f", df)) a match" + (dfAll > 0 ? " (usually \(String(format: "%.1f", dfAll)))." : ".")))
        }
        if bpC + bpF > 0 {
            sections.append(("Big points", "Break points converted \(bpW) of \(bpC)" + (bpC > 0 ? " (\(pct(bpW, bpC))%)" : "") + ", saved \(bpS) of \(bpF)" + (bpF > 0 ? " (\(pct(bpS, bpF))%)." : ".")))
        }
        if w + ue > 0 {
            let r = Double(w) / Double(max(1, ue)), rAll = Double(wAll) / Double(max(1, ueAll))
            sections.append(("Shot quality", "\(w) winners to \(ue) unforced errors against \(first), a ratio of \(String(format: "%.2f", r))" + (all.count > ms.count ? " (you average \(String(format: "%.2f", rAll)))." : ".")))
        }
        let worked = unique(ms.filter(\.won).map(\.whatWorked)).prefix(2)
        if !worked.isEmpty { sections.append(("What's worked", worked.map { "“\($0)”" }.joined(separator: "\n"))) }
        let hurt = unique(ms.map(\.whatDidnt)).prefix(2)
        if !hurt.isEmpty { sections.append(("What's hurt you", hurt.map { "“\($0)”" }.joined(separator: "\n"))) }
        if let n = l.scouting[o.id], !n.isEmpty { sections.append(("Your notes", n)) }

        var plan: [String] = []
        if let fsVs, fsVs < 58 { plan.append("Take 10% off the first serve and aim for 65% in. Free points on serve matter more than pace against \(first).") }
        if ue > w { plan.append("Play with more margin: high over the net and deep through the middle until you get a short ball.") }
        if bpC > 0, pctValue(bpW, bpC) < 40 { plan.append("On break points, make them play: a deep return through the middle, no first-strike winners.") }
        if bpF > 0, pctValue(bpS, bpF) < 55 { plan.append("When you face break point, go to your highest-percentage serve. Body or T, with spin.") }
        if df > dfAll + 0.5 { plan.append("Second serve: more spin, more height. A double fault against \(first) is a gift they're waiting for.") }
        if let w = worked.first { plan.append("Repeat what's worked: \(w.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")))." ) }
        if plan.count < 3 { plan.append("Start the match with your most reliable pattern and stay with it until it stops working.") }
        if plan.count < 3 { plan.append("Write one line after the match in What worked. The next report gets sharper.") }

        return ScoutReport(opponent: o.name, record: "\(o.won)–\(o.lost)", sections: sections, plan: Array(plan.prefix(3)))
    }
}

struct ScoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let report: ScoutReport

    private var shareText: String {
        var lines: [String] = [report.opponent + " · scouting report", ""]
        for (i, p) in report.plan.enumerated() { lines.append("\(i + 1). \(p)") }
        lines.append("")
        for sec in report.sections { lines.append(sec.title); lines.append(sec.body); lines.append("") }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SheetHeader(eyebrow: "Scouting report", title: report.opponent) { dismiss() }.padding(.horizontal, -20)
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow("The plan")
                        ForEach(Array(report.plan.enumerated()), id: \.offset) { i, p in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(i + 1)").font(.figure(16)).foregroundStyle(Gold.ink).frame(width: 28, height: 28).background(Circle().fill(Gold.foil))
                                Text(p).font(.display(16)).foregroundStyle(Gold.ivory).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .card(padding: 18)
                    ForEach(Array(report.sections.enumerated()), id: \.offset) { _, s in
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(s.title)
                            Text(s.body).font(.body(14.5)).foregroundStyle(Gold.ivory.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 16)
                    }
                    ShareLink(item: shareText) {
                        Label("Share the report", systemImage: "square.and.arrow.up").font(.body(15, .semibold)).foil()
                            .frame(maxWidth: .infinity).frame(height: 50).overlay(Capsule().strokeBorder(Gold.hairline))
                    }
                    Text("Built on your phone from your own matches. Nothing leaves the ledger.").font(.body(11.5)).foregroundStyle(Gold.faint).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Clutch (Pro)

/// How you play when it's close: tiebreaks, deciding sets, break points.
struct ClutchCard: View {
    @Environment(Ledger.self) private var ledger
    var body: some View {
        let ms = ledger.matches
        let tbSets = ms.flatMap(\.sets).filter { $0.tiebreak != nil || (max($0.me, $0.them) == 7 && min($0.me, $0.them) == 6) }
        let tbWon = tbSets.filter(\.won).count
        let deciders = ms.filter { $0.sets.count == 3 || $0.sets.count == 5 }
        let decWon = deciders.filter(\.won).count
        let bpC = ms.reduce(0) { $0 + $1.breakPointChances }, bpW = ms.reduce(0) { $0 + $1.breakPointsWon }
        let bpF = ms.reduce(0) { $0 + $1.breakPointsFaced }, bpS = ms.reduce(0) { $0 + $1.breakPointsSaved }
        let live = ms.filter(\.isLive)
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow("When it's close")
            HStack(spacing: 10) {
                tile("\(tbWon)–\(tbSets.count - tbWon)", "tiebreak sets")
                tile("\(decWon)–\(deciders.count - decWon)", "deciding sets")
            }
            HStack(spacing: 10) {
                tile(bpC == 0 ? "–" : "\(pct(bpW, bpC))%", "break points won")
                tile(bpF == 0 ? "–" : "\(pct(bpS, bpF))%", "break points saved")
            }
            if let m = live.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Momentum, last match scored live: vs \(m.opponent.isEmpty ? "opponent" : m.opponent)").font(.body(12, .semibold)).foregroundStyle(Gold.muted)
                    MomentumChart(values: ScoreState.replay(m.points, m.scoring ?? LiveFormat()).momentum).frame(height: 90)
                }
            }
        }
        .card()
    }
    private func tile(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.figure(24)).foil()
            Text(l).font(.body(11)).foregroundStyle(Gold.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Gold.ink.opacity(0.5)))
    }
}

// MARK: - Screenshot only

/// The widgets and the live match on a Lock Screen, for the App Store screenshot. The real widgets draw the same views.
struct WidgetShowcase: View {
    @Environment(Ledger.self) private var ledger
    var body: some View {
        let g = ledger.glance(unlocked: true, weeklyTarget: 300)
        let f = LiveFormat()
        let m = ledger.matches.first { $0.isLive }
        let s = ScoreState.replay(Array((m?.points ?? []).prefix(max(0, (m?.points.count ?? 0) - 9))), m?.scoring ?? f)
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.20), Color(red: 0.05, green: 0.05, blue: 0.08), Gold.ink], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 22) {
                VStack(spacing: 2) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.body(17, .semibold)).foregroundStyle(.white.opacity(0.8))
                    Text("9:41").font(.system(size: 84, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.92))
                }.padding(.top, 50)
                MatchLiveView(opponent: m?.opponent ?? "Chris Maddox", s: MatchLive.state(s, m?.scoring ?? f))
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Gold.ink.opacity(0.92)))
                    .padding(.horizontal, 14)
                HStack(spacing: 22) {
                    tile(RecordGlanceView(g: g), w: 170, h: 170)
                    VStack(spacing: 14) {
                        ForEach(0..<2, id: \.self) { _ in
                            HStack(spacing: 14) { ForEach(0..<2, id: \.self) { _ in RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.12)).frame(width: 64, height: 64) } }
                        }
                    }
                }
                tile(FormGlanceView(g: g), w: 364, h: 170)
                Spacer()
            }
        }
    }
    private func tile<V: View>(_ v: V, w: CGFloat, h: CGFloat) -> some View {
        v.padding(16).frame(width: w, height: h, alignment: .topLeading)
            .background(LacquerBackground().clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Gold.hairline, lineWidth: 0.6))
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }
}
