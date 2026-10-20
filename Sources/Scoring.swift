import ActivityKit
import Charts
import SwiftUI
import TipKit

extension ScoreState {
    /// Write the score and the numbers onto the match.
    func apply(to m: inout Match) {
        var s = sets
        if !over, let last = s.last, last.me == 0, last.them == 0, s.count > 1 { s.removeLast() }
        m.sets = s
        m.retired = false
        m.aces = aces; m.doubleFaults = doubleFaults
        m.firstServesIn = firstServesIn; m.firstServesTotal = firstServesTotal; m.firstServePointsWon = firstServePointsWon
        m.secondServePointsWon = secondServePointsWon; m.secondServePointsPlayed = secondServePointsPlayed
        m.breakPointsWon = breakPointsWon; m.breakPointChances = breakPointChances
        m.breakPointsSaved = breakPointsSaved; m.breakPointsFaced = breakPointsFaced
        m.winners = winners; m.unforcedErrors = unforcedErrors
    }
}

// MARK: - Live Activity

/// Keeps the Lock Screen card and the Dynamic Island in step with the scorer. Free for everyone.
/// Works from whatever activity is running, so a match resumed after a relaunch keeps its card.
@MainActor
enum MatchLive {
    static func state(_ s: ScoreState, _ f: LiveFormat, secondServe: Bool = false) -> MatchActivity.ContentState {
        MatchActivity.ContentState(s, f, secondServe: secondServe)
    }
    /// A new match replaces whatever card a previous one left behind.
    static func start(opponent: String, _ s: ScoreState, _ f: LiveFormat) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, !Shots.on else { return }
        let old = Activity<MatchActivity>.activities
        Task {
            for a in old { await a.end(nil, dismissalPolicy: .immediate) }
            _ = try? Activity.request(attributes: MatchActivity(opponent: opponent),
                                      content: .init(state: state(s, f), staleDate: .now.addingTimeInterval(5 * 3600)))
        }
    }
    static func update(_ s: ScoreState, _ f: LiveFormat, secondServe: Bool = false) {
        let st = state(s, f, secondServe: secondServe)
        for a in Activity<MatchActivity>.activities where a.activityState == .active {
            Task { await a.update(.init(state: st, staleDate: .now.addingTimeInterval(5 * 3600))) }
        }
    }
    static func end(_ s: ScoreState?, _ f: LiveFormat) {
        let final = s.map { state($0, f) }
        for a in Activity<MatchActivity>.activities where a.activityState == .active || a.activityState == .stale {
            Task { await a.end(final.map { .init(state: $0, staleDate: nil) }, dismissalPolicy: final == nil ? .immediate : .after(.now.addingTimeInterval(1800))) }
        }
    }
}

// MARK: - The scorer

/// Score a match point by point on court: two big buttons, and the numbers fill themselves in.
struct LiveMatchView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State var match: Match
    @State private var format = LiveFormat()
    @State private var started = false
    @State private var secondServe = false
    @State private var confirmLeave = false
    @Environment(\.scenePhase) private var phase

    init(match: Match, secondServe: Bool = false) {
        _match = State(initialValue: match)
        _format = State(initialValue: match.scoring ?? LiveFormat())
        _started = State(initialValue: !match.points.isEmpty || match.scoring != nil)
        _secondServe = State(initialValue: secondServe)
    }

    /// Every change goes to the app group straight away: the match survives the app closing, and the
    /// Lock Screen buttons score into the same list.
    private func persist() {
        guard started, !Shots.on else { return }
        var m = match
        m.points = []
        LiveDraft(matchID: match.id, match: (try? JSONEncoder().encode(m)) ?? Data(), opponent: match.opponent,
                  format: format, points: match.points, secondServe: secondServe).save()
    }

    /// Points scored from the Lock Screen while the app was in the background.
    private func pull() {
        guard let d = LiveDraft.load(), d.matchID == match.id else { return }
        if d.points != match.points || d.secondServe != secondServe {
            withAnimation(.snappy) { match.points = d.points; secondServe = d.secondServe }
        }
    }

    private var score: ScoreState { ScoreState.replay(match.points, format) }

    var body: some View {
        ZStack {
            LacquerBackground()
            if started { scorer } else { setup }
        }
        .onReceive(NotificationCenter.default.publisher(for: LiveDraft.changed)) { _ in pull() }
        .onChange(of: phase) { _, p in if p == .active { pull() } }
        .onCue { cue in
            switch cue {
            case "score.start": begin()
            case "score.won": point(true, .rally)
            case "score.winner": point(true, .winner)
            case "score.ace": point(true, .ace)
            case "score.error": point(false, .error)
            case "score.lost": point(false, .rally)
            case "score.save": save()
            default: break
            }
        }
    }

    // MARK: setup

    private var pastOpponents: [String] { Array(ledger.opponents.prefix(8).map(\.name)) }

    private var setup: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(eyebrow: "Score it live", title: "New match") { dismiss() }.padding(.horizontal, -20)
                Text("Tap who won each point. The score, serve numbers, break points and momentum fill themselves in, and the score sits on your Lock Screen.")
                    .font(.body(14)).foregroundStyle(Gold.muted)
                LedgerField(label: "Opponent", text: $match.opponent, prompt: "Name")
                if !pastOpponents.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(pastOpponents, id: \.self) { n in
                                Button {
                                    Haptic.tap(); match.opponent = n
                                    if let lvl = ledger.opponents.first(where: { $0.name == n })?.level { match.opponentLevel = lvl }
                                } label: {
                                    Text(n).font(.body(13, .medium)).foregroundStyle(match.opponent == n ? Gold.ink : Gold.ivory.opacity(0.8))
                                        .padding(.horizontal, 12).frame(height: 32)
                                        .background(Capsule().fill(match.opponent == n ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi)))
                                }.buttonStyle(PressStyle())
                            }
                        }.padding(.horizontal, 20)
                    }.padding(.horizontal, -20)
                }
                HStack(spacing: 10) {
                    LedgerField(label: "Their level", text: $match.opponentLevel, prompt: "UTR 7.2")
                    LedgerField(label: "Event", text: $match.event, prompt: "League, ladder")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow("Surface")
                    ChipRow(options: Surface.allCases, selection: $match.surface) { $0.rawValue }.padding(.horizontal, -36)
                    Eyebrow("Format")
                    ChipRow(options: [3, 1], selection: $format.bestOf) { $0 == 3 ? "Best of three" : "One set" }.padding(.horizontal, -36)
                    if format.bestOf == 3 {
                        Toggle(isOn: $format.matchTiebreak) { Text("Deciding set is a 10-point tiebreak").font(.body(14, .medium)).foregroundStyle(Gold.ivory) }.tint(Gold.leaf)
                    }
                    Toggle(isOn: $format.noAd) { Text("No-ad scoring").font(.body(14, .medium)).foregroundStyle(Gold.ivory) }.tint(Gold.leaf)
                    Eyebrow("First to serve")
                    ChipRow(options: [true, false], selection: $format.iServeFirst) { $0 ? "You" : "Them" }.padding(.horizontal, -36)
                }
                .card(padding: 16)
                FoilButton("Start the match", icon: "play.fill") { begin() }
            }
            .padding(.horizontal, 20).padding(.vertical, 16).padding(.bottom, 30)
        }
    }

    private func begin() {
        match.scoring = format
        withAnimation(.snappy) { started = true }
        persist()
        MatchLive.start(opponent: match.opponent, score, format)
        Haptic.done()
    }

    // MARK: scoring

    private var scorer: some View {
        let s = score
        return VStack(spacing: 0) {
            HStack {
                Button { confirmLeave = true } label: {
                    Image(systemName: "xmark").font(.body(15, .bold)).foregroundStyle(Gold.muted)
                        .frame(width: 40, height: 40).background(Circle().fill(Gold.lacquerHi))
                }
                Spacer()
                VStack(spacing: 1) {
                    Text(match.opponent.isEmpty ? "Live match" : "vs \(match.opponent)").font(.display(18, .medium)).foregroundStyle(Gold.ivory).lineLimit(1)
                    Text("\(s.pointsWon) of \(s.pointsPlayed) points won").font(.body(11)).foregroundStyle(Gold.muted)
                }
                Spacer()
                Button { save() } label: {
                    Text(s.over ? "Save" : "End").font(.body(14, .bold)).foregroundStyle(Gold.ink)
                        .padding(.horizontal, 16).frame(height: 36).background(Capsule().fill(Gold.foil))
                }.buttonStyle(PressStyle())
            }
            .padding(.horizontal, 18).padding(.top, 10)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    board(s)
                    if s.over { finished(s) } else { pad(s) }
                    if !s.over { TipView(LockScreenTip()).tipBackground(Gold.lacquer) }
                    if s.momentum.count > 3 { momentum(s) }
                }
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 40)
            }
        }
        .confirmationDialog("Leave the match?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Save it as it stands") { save() }
            Button("Discard", role: .destructive) { MatchLive.end(nil, format); LiveDraft.clear(); dismiss() }
        } message: { Text("Saving keeps the score and every number so far.") }
    }

    private func board(_ s: ScoreState) -> some View {
        let c = s.call(format)
        let flag = s.breakPoint(format) ? "BREAK POINT" : s.facingBreak(format) ? "BREAK POINT AGAINST" : s.status.uppercased()
        return VStack(spacing: 12) {
            row(name: "You", serving: s.iServe && !s.over, games: s.sets.map(\.me), other: s.sets.map(\.them), point: c.me, s: s)
            Rectangle().fill(Gold.leaf.opacity(0.12)).frame(height: 0.8)
            row(name: match.opponent.isEmpty ? "Them" : String(match.opponent.split(separator: " ").first ?? "Them"),
                serving: !s.iServe && !s.over, games: s.sets.map(\.them), other: s.sets.map(\.me), point: c.them, s: s)
            if !flag.isEmpty {
                Text(flag).font(.body(11, .bold)).tracking(2)
                    .foregroundStyle(s.facingBreak(format) ? Gold.bad : Gold.ink)
                    .padding(.horizontal, 12).frame(height: 26)
                    .background(Capsule().fill(s.facingBreak(format) ? AnyShapeStyle(Gold.bad.opacity(0.15)) : AnyShapeStyle(Gold.foil)))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy, value: flag)
        .card(padding: 18, radius: 26)
    }

    private func row(name: String, serving: Bool, games: [Int], other: [Int], point: String, s: ScoreState) -> some View {
        HStack(spacing: 10) {
            Circle().fill(serving ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Color.clear)).frame(width: 9, height: 9)
            Text(name).font(.display(19, .medium)).foregroundStyle(Gold.ivory).lineLimit(1)
            Spacer(minLength: 6)
            ForEach(Array(games.enumerated()), id: \.offset) { i, g in
                let current = i == games.count - 1 && !s.over
                Text("\(g)").font(.figure(22, current ? .medium : .light))
                    .foregroundStyle(g > other[i] && !current ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.ivory.opacity(current ? 1 : 0.55)))
                    .frame(width: 26)
            }
            Text(s.over ? "" : point).font(.figure(26)).foil()
                .frame(width: 54, height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Gold.ink.opacity(0.6)))
                .contentTransition(.numericText())
        }
    }

    private func pad(_ s: ScoreState) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(s.iServe ? (secondServe ? "Your second serve" : "Your first serve") : (secondServe ? "Their second serve" : "Their first serve"))
                    .font(.body(13, .semibold)).foregroundStyle(Gold.muted)
                Spacer()
                Button {
                    Haptic.tap()
                    if secondServe { point(!s.iServe, .doubleFault) } else {
                        withAnimation(.snappy) { secondServe = true }
                        persist(); MatchLive.update(s, format, secondServe: true)
                    }
                } label: {
                    Text(secondServe ? "Double fault" : "Fault").font(.body(13, .bold)).foregroundStyle(secondServe ? Gold.bad : Gold.ivory)
                        .padding(.horizontal, 14).frame(height: 34)
                        .overlay(Capsule().strokeBorder(secondServe ? Gold.bad.opacity(0.6) : Gold.leaf.opacity(0.3)))
                }.buttonStyle(PressStyle())
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 10) {
                    big("You won it", icon: "arrow.up", foil: true) { point(true, .rally) }
                    small("Winner") { point(true, .winner) }
                    if s.iServe { small("Ace") { point(true, .ace) } }
                }
                VStack(spacing: 10) {
                    big("They won it", icon: "arrow.down", foil: false) { point(false, .rally) }
                    small("Your error") { point(false, .error) }
                    if !s.iServe { small("Their ace") { point(false, .ace) } }
                }
            }
            HStack {
                Button { undo() } label: {
                    Label("Undo last point", systemImage: "arrow.uturn.backward").font(.body(13, .semibold)).foregroundStyle(Gold.muted)
                }.disabled(match.points.isEmpty)
                Spacer()
                Text("Winner and error tag the point for your stats.").font(.body(11)).foregroundStyle(Gold.faint)
            }
        }
    }

    private func big(_ t: String, icon: String, foil: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 26, weight: .bold))
                Text(t).font(.display(18, .medium))
            }
            .foregroundStyle(foil ? AnyShapeStyle(Gold.ink) : AnyShapeStyle(Gold.ivory))
            .frame(maxWidth: .infinity).frame(height: 128)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(foil ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Gold.hairline, lineWidth: foil ? 0 : 0.8))
            .shadow(color: foil ? Gold.leaf.opacity(0.35) : .clear, radius: 16, y: 6)
        }.buttonStyle(PressStyle())
    }

    private func small(_ t: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(t).font(.body(14, .semibold)).foregroundStyle(Gold.ivory)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Gold.lacquer))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Gold.leaf.opacity(0.18)))
        }.buttonStyle(PressStyle())
    }

    private func finished(_ s: ScoreState) -> some View {
        VStack(spacing: 14) {
            Image(systemName: s.won ? "trophy.fill" : "tennisball.fill").font(.system(size: 40)).foil()
            Text(s.won ? "Match won" : "Match lost").font(.display(28)).foregroundStyle(Gold.ivory)
            Text(s.sets.map(\.text).joined(separator: "  ")).font(.figure(22)).foil()
            HStack(spacing: 0) {
                fig("\(Int(pctValue(s.firstServesIn, s.firstServesTotal).rounded()))%", "1st serve")
                fig("\(s.breakPointsWon)/\(s.breakPointChances)", "BP won")
                fig("\(s.winners)/\(s.unforcedErrors)", "W / UE")
            }
            FoilButton("Save the match", icon: "checkmark.seal.fill") { save() }
            Button { undo() } label: { Text("Undo last point").font(.body(13, .semibold)).foregroundStyle(Gold.muted) }
        }
        .frame(maxWidth: .infinity).card(padding: 22, radius: 26)
    }

    private func fig(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) { Text(v).font(.figure(19)).foregroundStyle(Gold.ivory); Text(l).font(.body(10.5)).foregroundStyle(Gold.muted) }.frame(maxWidth: .infinity)
    }

    private func momentum(_ s: ScoreState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Momentum")
            MomentumChart(values: s.momentum).frame(height: 90)
        }
        .card(padding: 16)
    }

    // MARK: actions

    private func point(_ iWon: Bool, _ kind: PointKind) {
        let s = score
        guard !s.over else { return }
        let p = PointLog(iWon: iWon, iServed: s.iServe, kind: kind, firstIn: kind == .doubleFault ? false : !secondServe)
        withAnimation(.snappy) { match.points.append(p); secondServe = false }
        let after = score
        if after.over { Haptic.done() } else if after.setsMe + after.setsThem > s.setsMe + s.setsThem || after.sets.last.map({ $0.me + $0.them }) != s.sets.last.map({ $0.me + $0.them }) { Haptic.thud() } else { Haptic.tap() }
        persist()
        MatchLive.update(after, format)
    }

    private func undo() {
        guard !match.points.isEmpty else { return }
        Haptic.tap()
        withAnimation(.snappy) { _ = match.points.popLast(); secondServe = false }
        persist()
        MatchLive.update(score, format)
    }

    private func save() {
        let s = score
        var m = match
        m.scoring = format
        s.apply(to: &m)
        ledger.upsert(m)
        MatchLive.end(s, format)
        LiveDraft.clear()
        Haptic.done()
        if s.won { router.happyMoment() }
        dismiss()
        // Straight into the match sheet, for the plan, the notes and the poster.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { router.editingMatch = m }
    }
}

/// Points won minus points lost across a match: the swing of it.
struct MomentumChart: View {
    let values: [Int]
    var body: some View {
        Chart {
            RuleMark(y: .value("Even", 0)).foregroundStyle(Gold.leaf.opacity(0.25)).lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                AreaMark(x: .value("Point", i), y: .value("Lead", v))
                    .foregroundStyle(LinearGradient(colors: [Gold.leaf.opacity(0.35), Gold.leaf.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Point", i), y: .value("Lead", v)).foregroundStyle(Gold.foil).lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisValueLabel().foregroundStyle(Gold.muted) } }
    }
}
