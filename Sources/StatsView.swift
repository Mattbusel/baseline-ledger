import SwiftUI
import Charts

struct StatsView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Pro.self) private var pro

    var body: some View {
        Page {
            PageHeader(eyebrow: "Everything you've logged", title: "The numbers")
            if ledger.matches.isEmpty && ledger.sessions.isEmpty {
                Text("Charts appear once you have a few sessions or matches in the ledger.")
                    .font(.display(17)).foregroundStyle(Gold.muted).card()
            }
            // The last-ten averages are free; the stat book below them is Pro.
            if !ledger.matches.isEmpty { matchAverages }
            if pro.unlocked {
                statBook
            } else {
                LockedSection(reason: .stats, title: "The full stat book",
                              pitch: "Serve trends, winners against errors, results by surface, where your serves land and how each stroke holds up, all from what you have logged.") {
                    if ledger.matches.isEmpty && ledger.sessions.isEmpty { sampleCard } else { statBook }
                }
            }
            ExportCard()
        }
    }

    @ViewBuilder private var statBook: some View {
        if !ledger.matches.isEmpty {
            firstServeTrend
            winnersVsErrors
            bySurface
        }
        if !ledger.blocks(.serve).isEmpty { servePlacement }
        if !ledger.allBlocks.isEmpty {
            strokeConsistency
            errorMix
            practiceMix
        }
    }

    /// Something to frost when the ledger is still empty.
    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("First serve %")
            Chart(Array([52, 55, 51, 58, 56, 60, 57, 62].enumerated()), id: \.offset) { item in
                LineMark(x: .value("Match", item.offset), y: .value("First serve", item.element))
                    .foregroundStyle(Gold.foil).interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .frame(height: 190)
        }
        .card()
    }

    private var matchAverages: some View {
        let ms = Array(ledger.matches.prefix(10))
        let n = Double(ms.count)
        let first = pct(ms.reduce(0) { $0 + $1.firstServesIn }, ms.reduce(0) { $0 + $1.firstServesTotal })
        let firstWon = pct(ms.reduce(0) { $0 + $1.firstServePointsWon }, ms.reduce(0) { $0 + $1.firstServesIn })
        let secondWon = pct(ms.reduce(0) { $0 + $1.secondServePointsWon }, ms.reduce(0) { $0 + $1.secondServePointsPlayed })
        let bp = pct(ms.reduce(0) { $0 + $1.breakPointsWon }, ms.reduce(0) { $0 + $1.breakPointChances })
        let saved = pct(ms.reduce(0) { $0 + $1.breakPointsSaved }, ms.reduce(0) { $0 + $1.breakPointsFaced })
        let df = String(format: "%.1f", Double(ms.reduce(0) { $0 + $1.doubleFaults }) / n)
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Last \(ms.count) matches")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                StatTile(label: "1st in", value: first, unit: "%")
                StatTile(label: "1st won", value: firstWon, unit: "%")
                StatTile(label: "2nd won", value: secondWon, unit: "%")
                StatTile(label: "BP won", value: bp, unit: "%")
                StatTile(label: "BP saved", value: saved, unit: "%")
                StatTile(label: "DF / match", value: df)
            }
        }
    }

    private func axes() -> some AxisContent {
        AxisMarks(position: .leading) { _ in
            AxisGridLine().foregroundStyle(Gold.leaf.opacity(0.08))
            AxisValueLabel().foregroundStyle(Gold.muted).font(.body(10))
        }
    }

    private var firstServeTrend: some View {
        let ms = Array(ledger.matches.prefix(15).reversed())
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("First serve %")
                Spacer()
                Text("target 60%").font(.body(11.5, .semibold)).foregroundStyle(Gold.muted)
            }
            Chart {
                RuleMark(y: .value("Target", 60)).foregroundStyle(Gold.leaf.opacity(0.35)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                ForEach(Array(ms.enumerated()), id: \.element.id) { i, m in
                    AreaMark(x: .value("Match", i), yStart: .value("Floor", 40), yEnd: .value("1st", m.firstServePct))
                        .foregroundStyle(LinearGradient(colors: [Gold.leaf.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Match", i), y: .value("1st", m.firstServePct))
                        .foregroundStyle(Gold.foil).lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round)).interpolationMethod(.monotone)
                    PointMark(x: .value("Match", i), y: .value("1st", m.firstServePct))
                        .foregroundStyle(m.won ? Gold.pale : Gold.bad).symbolSize(34)
                }
            }
            .chartYScale(domain: 40...80)
            .chartXAxis(.hidden)
            .chartYAxis { axes() }
            .frame(height: 180)
            HStack(spacing: 14) {
                HStack(spacing: 5) { Circle().fill(Gold.pale).frame(width: 7); Text("won") }
                HStack(spacing: 5) { Circle().fill(Gold.bad).frame(width: 7); Text("lost") }
            }
            .font(.body(11)).foregroundStyle(Gold.muted)
        }
        .card()
    }

    private var winnersVsErrors: some View {
        let ms = Array(ledger.matches.prefix(10).reversed())
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Winners vs unforced errors")
                Spacer()
                HStack(spacing: 10) {
                    HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(Gold.foil).frame(width: 10, height: 10); Text("W") }
                    HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(Gold.bad.opacity(0.7)).frame(width: 10, height: 10); Text("UE") }
                }
                .font(.body(11)).foregroundStyle(Gold.muted)
            }
            Chart {
                ForEach(Array(ms.enumerated()), id: \.element.id) { i, m in
                    BarMark(x: .value("Match", "\(i)"), y: .value("Count", m.winners))
                        .foregroundStyle(LinearGradient(colors: [Gold.pale, Gold.deep], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(4).position(by: .value("Kind", "W"))
                    BarMark(x: .value("Match", "\(i)"), y: .value("Count", m.unforcedErrors))
                        .foregroundStyle(Gold.bad.opacity(0.7))
                        .cornerRadius(4).position(by: .value("Kind", "UE"))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis { axes() }
            .frame(height: 170)
        }
        .card()
    }

    private var bySurface: some View {
        let rows: [(Surface, Int, Int)] = Surface.allCases.compactMap { s in
            let ms = ledger.matches.filter { $0.surface == s }
            return ms.isEmpty ? nil : (s, ms.filter(\.won).count, ms.count)
        }
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Win rate by surface")
            ForEach(rows, id: \.0) { s, w, n in
                HStack(spacing: 12) {
                    Text(s.rawValue).font(.display(16)).foregroundStyle(Gold.ivory).frame(width: 64, alignment: .leading)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Gold.ink.opacity(0.6))
                            Capsule().fill(Gold.foil).frame(width: g.size.width * CGFloat(w) / CGFloat(max(n, 1)))
                        }
                    }
                    .frame(height: 10)
                    Text("\(w)–\(n - w)").font(.figure(14)).foregroundStyle(Gold.pale).frame(width: 44, alignment: .trailing)
                }
            }
        }
        .card()
    }

    private var servePlacement: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Where your serves land")
            HStack(spacing: 12) {
                ForEach(Side.allCases, id: \.self) { side in
                    VStack(spacing: 8) {
                        ServiceBox(side: side, counts: ledger.zoneTotals(side: side)).frame(height: 130).allowsHitTesting(false)
                        Text(side.rawValue.uppercased()).font(.body(10, .bold)).tracking(1.4).foregroundStyle(Gold.muted)
                    }
                }
            }
            let serves = ledger.blocks(.serve)
            let first = serves.filter { $0.serveNumber == .first }, second = serves.filter { $0.serveNumber == .second }
            HStack(spacing: 10) {
                StatTile(label: "1st in, practice", value: pct(first.reduce(0) { $0 + $1.made + $1.winners }, first.reduce(0) { $0 + $1.balls }), unit: "%")
                StatTile(label: "2nd in, practice", value: pct(second.reduce(0) { $0 + $1.made + $1.winners }, second.reduce(0) { $0 + $1.balls }), unit: "%")
            }
        }
        .card()
    }

    private var strokeConsistency: some View {
        let rows: [(Stroke, Double, Int)] = Stroke.allCases.compactMap { s in
            let bs = ledger.blocks(s)
            let balls = bs.reduce(0) { $0 + $1.balls }
            guard balls > 0 else { return nil }
            return (s, pctValue(bs.reduce(0) { $0 + $1.made + $1.winners }, balls), balls)
        }
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow("In-play % by stroke, practice")
            Chart {
                ForEach(rows, id: \.0) { s, v, _ in
                    BarMark(x: .value("In", v), y: .value("Stroke", s.rawValue))
                        .foregroundStyle(Gold.foil).cornerRadius(4)
                        .annotation(position: .trailing) { Text("\(Int(v.rounded()))%").font(.body(10.5, .semibold)).foregroundStyle(Gold.pale) }
                }
            }
            .chartXScale(domain: 0...110)
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Gold.ivory.opacity(0.8)).font(.body(11.5, .medium)) } }
            .frame(height: CGFloat(rows.count) * 34 + 10)
            if let best = ledger.allBlocks.flatMap(\.rallies).max() {
                Text("Longest rally logged: \(best) shots").font(.body(12.5, .medium)).foregroundStyle(Gold.pale)
            }
        }
        .card()
    }

    private var errorMix: some View {
        let e = ledger.errorTotals
        let total = max(1, e.values.reduce(0, +))
        let top = StrokeError.allCases.max { (e[$0] ?? 0) < (e[$1] ?? 0) } ?? .net
        let advice: [StrokeError: String] = [
            .net: "Most errors find the net. Aim higher over it and let topspin bring the ball down.",
            .long: "Most errors sail long. More spin, or a lower target over the net.",
            .wide: "Most errors go wide. Pull targets a metre inside the lines.",
            .framed: "Framed balls lead the list. Earlier preparation and watching contact will help.",
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow("How you miss")
            SplitBar(parts: StrokeError.allCases.map { ($0.rawValue, e[$0] ?? 0) })
            Text(total < 10 ? "Log more errors to see a pattern." : advice[top] ?? "")
                .font(.body(12.5)).foregroundStyle(Gold.pale.opacity(0.85))
        }
        .card()
    }

    private var practiceMix: some View {
        let mix = ledger.minutesByStroke
        let total = max(1, mix.map(\.1).reduce(0, +))
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Where your court time goes")
            HStack(spacing: 20) {
                Chart(mix, id: \.0) { k, m in
                    SectorMark(angle: .value("Minutes", m), innerRadius: .ratio(0.62), angularInset: 2)
                        .foregroundStyle(Gold.chartScale[(Stroke.allCases.firstIndex(of: k) ?? 0) % Gold.chartScale.count])
                        .cornerRadius(3)
                }
                .frame(width: 140, height: 140)
                .overlay {
                    VStack(spacing: 0) {
                        Text("\(total / 60)").font(.figure(26)).foil()
                        Text("hours").font(.body(10.5)).foregroundStyle(Gold.muted)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(mix, id: \.0) { k, m in
                        HStack(spacing: 8) {
                            Circle().fill(Gold.chartScale[(Stroke.allCases.firstIndex(of: k) ?? 0) % Gold.chartScale.count]).frame(width: 8, height: 8)
                            Text(k.rawValue).font(.body(12.5, .medium)).foregroundStyle(Gold.ivory.opacity(0.85))
                            Spacer()
                            Text("\(m * 100 / total)%").font(.figure(12.5)).foregroundStyle(Gold.muted)
                        }
                    }
                }
            }
        }
        .card()
    }
}
