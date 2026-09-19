import SwiftUI

struct MatchesView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @State private var surface: Surface? = nil

    private var list: [Match] { ledger.matches.filter { surface == nil || $0.surface == surface } }

    var body: some View {
        Page {
            HStack(alignment: .bottom) {
                PageHeader(eyebrow: "\(ledger.record.won) won · \(ledger.record.lost) lost", title: "Matches")
                Spacer()
                Button { router.editingMatch = Match() } label: {
                    Image(systemName: "plus").font(.body(18, .semibold)).foregroundStyle(Gold.ink)
                        .frame(width: 48, height: 48).background(Circle().fill(Gold.foil))
                        .shadow(color: Gold.leaf.opacity(0.4), radius: 12)
                }
                .buttonStyle(PressStyle())
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", surface == nil) { surface = nil }
                    ForEach(Surface.allCases, id: \.self) { s in chip(s.rawValue, surface == s) { surface = s } }
                }
                .padding(.horizontal, 18)
            }
            .padding(.horizontal, -18)
            if ledger.matches.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy").font(.system(size: 38)).foil()
                    Text("No matches yet").font(.display(20)).foregroundStyle(Gold.ivory)
                    Text("Log the score, the serve numbers, break points and what worked. The patterns show up after a few.")
                        .font(.body(14)).foregroundStyle(Gold.muted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).card(padding: 26)
            }
            ForEach(list) { m in
                Button { router.editingMatch = m } label: { MatchCard(match: m) }.buttonStyle(PressStyle())
            }
        }
    }

    private func chip(_ t: String, _ on: Bool, _ act: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); withAnimation(.snappy) { act() } } label: {
            Text(t).font(.body(13, on ? .semibold : .medium))
                .foregroundStyle(on ? AnyShapeStyle(Gold.ink) : AnyShapeStyle(Gold.ivory.opacity(0.75)))
                .padding(.horizontal, 14).frame(height: 34)
                .background(Capsule().fill(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi)))
        }
        .buttonStyle(PressStyle())
    }
}

struct MatchCard: View {
    let match: Match
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Text(match.won ? "W" : "L").font(.display(20, .bold))
                    .foregroundStyle(match.won ? Gold.ink : Gold.ivory.opacity(0.7))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(match.won ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi)))
                    .overlay(Circle().strokeBorder(Gold.hairline, lineWidth: match.won ? 0 : 0.8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(match.opponent.isEmpty ? "Opponent" : match.opponent).font(.display(20, .medium)).foregroundStyle(Gold.ivory)
                    Text([match.date.ledgerDay, match.event, match.surface.rawValue].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.body(12)).foregroundStyle(Gold.muted).lineLimit(1)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                ForEach(match.sets) { s in
                    VStack(spacing: 0) {
                        Text("\(s.me)").font(.figure(24)).foregroundStyle(s.won ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.ivory.opacity(0.5)))
                        Text("\(s.them)").font(.figure(24)).foregroundStyle(s.won ? AnyShapeStyle(Gold.ivory.opacity(0.5)) : AnyShapeStyle(Gold.ivory))
                    }
                    .frame(width: 44, height: 66)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Gold.ink.opacity(0.5)))
                    .overlay(alignment: .topTrailing) {
                        if let tb = s.tiebreak { Text("\(tb)").font(.body(9, .bold)).foregroundStyle(Gold.pale).padding(4) }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    stat("1st serve", "\(Int(match.firstServePct.rounded()))%")
                    stat("W / UE", "\(match.winners) / \(match.unforcedErrors)")
                    stat("BP won", "\(match.breakPointsWon)/\(match.breakPointChances)")
                }
            }
        }
        .card()
    }
    private func stat(_ l: String, _ v: String) -> some View {
        HStack(spacing: 8) {
            Text(l.uppercased()).font(.body(9.5, .bold)).tracking(1).foregroundStyle(Gold.muted)
            Text(v).font(.figure(14)).foregroundStyle(Gold.ivory)
        }
    }
}

/// The match sheet: score, serve, pressure points, shot quality, reflection.
struct MatchEditorView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    @State var match: Match
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHeader(eyebrow: match.date.ledgerDay, title: match.opponent.isEmpty ? "New match" : "vs \(match.opponent)") { dismiss() }
                        .padding(.horizontal, -20)
                    scoreboard
                    LedgerField(label: "Opponent", text: $match.opponent, prompt: "Name")
                    HStack(spacing: 10) {
                        LedgerField(label: "Their level", text: $match.opponentLevel, prompt: "UTR 7.2")
                        LedgerField(label: "Event", text: $match.event, prompt: "League, ladder")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow("Surface")
                        ChipRow(options: Surface.allCases, selection: $match.surface) { $0.rawValue }.padding(.horizontal, -36)
                        Eyebrow("Format")
                        ChipRow(options: Format.allCases, selection: $match.format) { $0.rawValue }.padding(.horizontal, -36)
                        DatePicker("Date", selection: $match.date, displayedComponents: .date)
                            .font(.body(15, .medium)).foregroundStyle(Gold.ivory)
                    }
                    .card(padding: 16)

                    group("Serve") {
                        LedgerStepper(label: "Aces", value: $match.aces)
                        line
                        LedgerStepper(label: "Double faults", value: $match.doubleFaults)
                        line
                        LedgerStepper(label: "1st serves in", value: $match.firstServesIn)
                        LedgerStepper(label: "1st serves hit", value: $match.firstServesTotal)
                        ratio(match.firstServesIn, match.firstServesTotal, "first serve percentage", good: 60)
                        line
                        LedgerStepper(label: "1st serve points won", value: $match.firstServePointsWon)
                        ratio(match.firstServePointsWon, match.firstServesIn, "won behind the first serve", good: 70)
                        line
                        LedgerStepper(label: "2nd serve points won", value: $match.secondServePointsWon)
                        LedgerStepper(label: "2nd serve points played", value: $match.secondServePointsPlayed)
                        ratio(match.secondServePointsWon, match.secondServePointsPlayed, "won behind the second serve", good: 50)
                    }
                    group("Pressure") {
                        LedgerStepper(label: "Break points won", value: $match.breakPointsWon)
                        LedgerStepper(label: "Break point chances", value: $match.breakPointChances)
                        ratio(match.breakPointsWon, match.breakPointChances, "converted", good: 40)
                        line
                        LedgerStepper(label: "Break points saved", value: $match.breakPointsSaved)
                        LedgerStepper(label: "Break points faced", value: $match.breakPointsFaced)
                        ratio(match.breakPointsSaved, match.breakPointsFaced, "saved", good: 60)
                    }
                    group("Shots") {
                        LedgerStepper(label: "Winners", value: $match.winners)
                        LedgerStepper(label: "Unforced errors", value: $match.unforcedErrors)
                        HStack {
                            Text("Winner to error ratio").font(.body(12.5)).foregroundStyle(Gold.muted)
                            Spacer()
                            Text(String(format: "%.2f", Double(match.winners) / Double(max(1, match.unforcedErrors))))
                                .font(.figure(15)).foregroundStyle(match.winners >= match.unforcedErrors ? Gold.good : Gold.pale)
                        }
                        line
                        LedgerStepper(label: "Net points won", value: $match.netPointsWon)
                        LedgerStepper(label: "Net points played", value: $match.netPointsPlayed)
                        ratio(match.netPointsWon, match.netPointsPlayed, "won at net", good: 65)
                    }
                    LedgerField(label: "Game plan", text: $match.gamePlan, prompt: "What you set out to do", multiline: true)
                    LedgerField(label: "What worked", text: $match.whatWorked, prompt: "Patterns, plays, serves", multiline: true)
                    LedgerField(label: "What didn't", text: $match.whatDidnt, prompt: "Be honest", multiline: true)
                    LedgerField(label: "Notes", text: $match.notes, prompt: "Conditions, nerves, their game", multiline: true)
                    HStack {
                        Text("How you felt").font(.display(18)).foregroundStyle(Gold.ivory)
                        Spacer()
                        DiamondRating(value: $match.mood, size: 22)
                    }
                    .card()
                    FoilButton("Save match", icon: "checkmark.seal.fill") { ledger.upsert(match); Haptic.done(); dismiss() }
                    if ledger.matches.contains(where: { $0.id == match.id }) {
                        Button("Delete match", role: .destructive) { confirmDelete = true }
                            .font(.body(14, .semibold)).frame(maxWidth: .infinity)
                            .confirmationDialog("Delete this match?", isPresented: $confirmDelete) {
                                Button("Delete", role: .destructive) { ledger.matches.removeAll { $0.id == match.id }; dismiss() }
                            }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16).padding(.bottom, 30)
            }
        }
        .onCue { cue in
            withAnimation(.snappy) {
                switch cue {
                case "match.opponent": match.opponent = "J. Okafor"; match.event = "Club ladder"
                case "match.set1": match.sets = [SetScore(me: 6, them: 4)]
                case "match.set2": match.sets.append(SetScore(me: 7, them: 5))
                case "match.serve": match.aces = 4; match.doubleFaults = 2; match.firstServesIn = 38; match.firstServesTotal = 61
                case "match.worked": match.whatWorked = "Serving to the backhand on big points."
                case "match.save": ledger.upsert(match); Haptic.done(); dismiss()
                default: break
                }
            }
        }
    }

    private var line: some View { Rectangle().fill(Gold.leaf.opacity(0.1)).frame(height: 0.8) }

    private func group<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(title)
            c()
        }
        .card()
    }

    private func ratio(_ n: Int, _ d: Int, _ label: String, good: Double) -> some View {
        let v = pctValue(n, d)
        return HStack(spacing: 10) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Gold.ink.opacity(0.6))
                    Capsule().fill(Gold.foil).frame(width: g.size.width * CGFloat(min(v, 100) / 100))
                }
            }
            .frame(height: 6)
            Text(d == 0 ? "–" : "\(Int(v.rounded()))% \(label)").font(.body(11.5, .semibold))
                .foregroundStyle(d > 0 && v >= good ? Gold.good : Gold.muted).fixedSize()
        }
        .animation(.snappy, value: v)
    }

    // MARK: score

    private var scoreboard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("").frame(width: 60)
                ForEach(match.sets.indices, id: \.self) { i in
                    Text("SET \(i + 1)").font(.body(10, .bold)).tracking(1.2).foregroundStyle(Gold.muted).frame(maxWidth: .infinity)
                }
            }
            row("You", mine: true)
            row(match.opponent.isEmpty ? "Them" : String(match.opponent.split(separator: " ").first ?? "Them"), mine: false)
            HStack(spacing: 10) {
                Button {
                    Haptic.tap()
                    withAnimation(.snappy) { if match.sets.count < 5 { match.sets.append(SetScore(me: 0, them: 0)) } }
                } label: {
                    Label("Add set", systemImage: "plus").font(.body(13, .semibold)).foil()
                        .padding(.horizontal, 14).frame(height: 34).overlay(Capsule().strokeBorder(Gold.hairline))
                }
                if match.sets.count > 1 {
                    Button {
                        Haptic.tap(); withAnimation(.snappy) { _ = match.sets.popLast() }
                    } label: {
                        Label("Remove", systemImage: "minus").font(.body(13, .semibold)).foregroundStyle(Gold.muted)
                            .padding(.horizontal, 14).frame(height: 34).overlay(Capsule().strokeBorder(Gold.hairline))
                    }
                }
                Spacer()
                Text(match.won ? "WIN" : match.setsLost > match.setsWon ? "LOSS" : "—")
                    .font(.display(18, .bold)).tracking(2)
                    .foregroundStyle(match.won ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.muted))
            }
        }
        .card(padding: 18, radius: 26)
    }

    private func row(_ name: String, mine: Bool) -> some View {
        HStack {
            Text(name).font(.display(16, .medium)).foregroundStyle(Gold.ivory).lineLimit(1).frame(width: 60, alignment: .leading)
            ForEach(match.sets.indices, id: \.self) { i in
                let v = mine ? match.sets[i].me : match.sets[i].them
                let wonSet = mine ? match.sets[i].me > match.sets[i].them : match.sets[i].them > match.sets[i].me
                Menu {
                    ForEach(0...10, id: \.self) { n in
                        Button("\(n)") {
                            if mine { match.sets[i].me = n } else { match.sets[i].them = n }
                            let s = match.sets[i]
                            match.sets[i].tiebreak = (max(s.me, s.them) == 7 && min(s.me, s.them) == 6) ? (s.tiebreak ?? 5) : nil
                        }
                    }
                } label: {
                    Text("\(v)").font(.figure(30, .light))
                        .foregroundStyle(wonSet ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.ivory.opacity(0.6)))
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Gold.ink.opacity(0.55)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(wonSet ? Gold.leaf.opacity(0.6) : Gold.leaf.opacity(0.12)))
                }
            }
        }
    }
}
