import ActivityKit
import Charts
import SwiftUI

// MARK: - The rules

/// The score of a match after replaying its points. Everything is derived from the point list,
/// so undo is exact and the stats can never drift from the score.
struct ScoreState {
    var sets: [SetScore] = [SetScore(me: 0, them: 0)]
    var gameMe = 0
    var gameThem = 0
    var tiebreak = false
    var matchTiebreak = false
    var iServe = true
    var over = false
    var setsMe = 0
    var setsThem = 0
    /// Running points won minus points lost, after each point.
    var momentum: [Int] = []

    var aces = 0, doubleFaults = 0
    var firstServesIn = 0, firstServesTotal = 0, firstServePointsWon = 0
    var secondServePointsWon = 0, secondServePointsPlayed = 0
    var breakPointsWon = 0, breakPointChances = 0, breakPointsSaved = 0, breakPointsFaced = 0
    var winners = 0, unforcedErrors = 0
    var pointsWon = 0, pointsPlayed = 0

    var won: Bool { setsMe > setsThem }

    /// On their serve, one point from winning the game.
    func breakPoint(_ f: LiveFormat) -> Bool {
        !tiebreak && !iServe && (f.noAd ? gameMe >= 3 && gameThem <= 3 && gameMe >= gameThem : gameMe >= 3 && gameMe > gameThem)
    }
    /// On your serve, one point from losing the game.
    func facingBreak(_ f: LiveFormat) -> Bool {
        !tiebreak && iServe && (f.noAd ? gameThem >= 3 && gameMe <= 3 && gameThem >= gameMe : gameThem >= 3 && gameThem > gameMe)
    }

    /// The current game as it is called out: 15, 30, 40, Ad, or tiebreak points.
    func call(_ f: LiveFormat) -> (me: String, them: String) {
        if tiebreak { return ("\(gameMe)", "\(gameThem)") }
        let names = ["0", "15", "30", "40"]
        if gameMe >= 3 && gameThem >= 3 {
            if f.noAd || gameMe == gameThem { return ("40", "40") }
            return gameMe > gameThem ? ("AD", "") : ("", "AD")
        }
        return (names[min(gameMe, 3)], names[min(gameThem, 3)])
    }

    var status: String {
        if over { return won ? "Match won" : "Match lost" }
        if matchTiebreak { return "Match tiebreak" }
        if tiebreak { return "Tiebreak" }
        return ""
    }

    static func replay(_ points: [PointLog], _ f: LiveFormat) -> ScoreState {
        var s = ScoreState()
        s.iServe = f.iServeFirst
        var tbFirstServerMe = s.iServe
        var tbPoints = 0
        var diff = 0
        for p in points {
            guard !s.over else { break }
            s.count(p, f)
            diff += p.iWon ? 1 : -1
            s.momentum.append(diff)
            if p.iWon { s.gameMe += 1 } else { s.gameThem += 1 }
            let i = s.sets.count - 1
            if s.tiebreak {
                tbPoints += 1
                let target = s.matchTiebreak ? 10 : 7
                let hi = max(s.gameMe, s.gameThem), gap = abs(s.gameMe - s.gameThem)
                if hi >= target && gap >= 2 {
                    let meWon = s.gameMe > s.gameThem
                    if s.matchTiebreak {
                        s.sets[i] = SetScore(me: s.gameMe, them: s.gameThem)
                    } else {
                        s.sets[i].me += meWon ? 1 : 0
                        s.sets[i].them += meWon ? 0 : 1
                        s.sets[i].tiebreak = min(s.gameMe, s.gameThem)
                    }
                    // Whoever received the first point of the tiebreak serves the next set.
                    s.iServe = !tbFirstServerMe
                    s.endSet(meWon: meWon, f, &tbFirstServerMe, &tbPoints)
                } else if tbPoints % 2 == 1 {
                    s.iServe.toggle()
                }
            } else {
                let gameOver = f.noAd ? (s.gameMe == 4 || s.gameThem == 4) && !(s.gameMe >= 3 && s.gameThem >= 3 && s.gameMe == s.gameThem)
                                      : (max(s.gameMe, s.gameThem) >= 4 && abs(s.gameMe - s.gameThem) >= 2)
                if gameOver {
                    let meWon = s.gameMe > s.gameThem
                    if meWon { s.sets[i].me += 1 } else { s.sets[i].them += 1 }
                    s.gameMe = 0; s.gameThem = 0
                    s.iServe.toggle()
                    let a = s.sets[i].me, b = s.sets[i].them
                    if (a >= 6 || b >= 6) && abs(a - b) >= 2 || a == 7 || b == 7 {
                        s.endSet(meWon: a > b, f, &tbFirstServerMe, &tbPoints)
                    } else if a == 6 && b == 6 {
                        s.tiebreak = true
                        tbFirstServerMe = s.iServe
                        tbPoints = 0
                    }
                }
            }
        }
        return s
    }

    private mutating func endSet(meWon: Bool, _ f: LiveFormat, _ tbFirst: inout Bool, _ tbPoints: inout Int) {
        if meWon { setsMe += 1 } else { setsThem += 1 }
        gameMe = 0; gameThem = 0; tiebreak = false; matchTiebreak = false
        let need = f.bestOf / 2 + 1
        if setsMe >= need || setsThem >= need { over = true; return }
        sets.append(SetScore(me: 0, them: 0))
        if f.bestOf == 3 && f.matchTiebreak && setsMe == 1 && setsThem == 1 {
            tiebreak = true; matchTiebreak = true
            tbFirst = iServe; tbPoints = 0
        }
    }

    /// Serve, pressure and shot numbers for this point, from your side of the net.
    private mutating func count(_ p: PointLog, _ f: LiveFormat) {
        pointsPlayed += 1
        if p.iWon { pointsWon += 1 }
        if p.iServed {
            firstServesTotal += 1
            if p.kind == .doubleFault {
                doubleFaults += 1; secondServePointsPlayed += 1
            } else if p.firstIn {
                firstServesIn += 1
                if p.iWon { firstServePointsWon += 1 }
            } else {
                secondServePointsPlayed += 1
                if p.iWon { secondServePointsWon += 1 }
            }
            if p.kind == .ace && p.iWon { aces += 1 }
            if facingBreak(f) { breakPointsFaced += 1; if p.iWon { breakPointsSaved += 1 } }
        } else if breakPoint(f) {
            breakPointChances += 1
            if p.iWon { breakPointsWon += 1 }
        }
        if p.kind == .winner && p.iWon { winners += 1 }
        if p.kind == .error && !p.iWon { unforcedErrors += 1 }
    }

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
@MainActor
enum MatchLive {
    private static var activity: Activity<MatchActivity>?

    static func state(_ s: ScoreState, _ f: LiveFormat) -> MatchActivity.ContentState {
        let c = s.call(f)
        return .init(me: s.sets.map(\.me), them: s.sets.map(\.them), pointMe: c.me, pointThem: c.them,
                     iServe: s.iServe, status: s.breakPoint(f) ? "Break point" : s.facingBreak(f) ? "Break point against" : s.status)
    }
    static func start(opponent: String, _ s: ScoreState, _ f: LiveFormat) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled,
              !ProcessInfo.processInfo.arguments.contains("-shot") else { return }
        activity = try? Activity.request(attributes: MatchActivity(opponent: opponent),
                                         content: .init(state: state(s, f), staleDate: .now.addingTimeInterval(5 * 3600)))
    }
    static func update(_ s: ScoreState, _ f: LiveFormat) {
        guard let a = activity else { return }
        let st = state(s, f)
        Task { await a.update(.init(state: st, staleDate: .now.addingTimeInterval(5 * 3600))) }
    }
    static func end(_ s: ScoreState?, _ f: LiveFormat) {
        guard let a = activity else { return }
        activity = nil
        let final = s.map { state($0, f) }
        Task { await a.end(final.map { .init(state: $0, staleDate: nil) }, dismissalPolicy: .after(.now.addingTimeInterval(1800))) }
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

    init(match: Match) {
        _match = State(initialValue: match)
        _format = State(initialValue: match.scoring ?? LiveFormat())
        _started = State(initialValue: !match.points.isEmpty)
    }

    private var score: ScoreState { ScoreState.replay(match.points, format) }

    var body: some View {
        ZStack {
            LacquerBackground()
            if started { scorer } else { setup }
        }
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
                    if s.momentum.count > 3 { momentum(s) }
                }
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 40)
            }
        }
        .confirmationDialog("Leave the match?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Save it as it stands") { save() }
            Button("Discard", role: .destructive) { MatchLive.end(nil, format); dismiss() }
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
                    if secondServe { point(!s.iServe, .doubleFault) } else { withAnimation(.snappy) { secondServe = true } }
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
        MatchLive.update(after, format)
    }

    private func undo() {
        guard !match.points.isEmpty else { return }
        Haptic.tap()
        withAnimation(.snappy) { _ = match.points.popLast(); secondServe = false }
        MatchLive.update(score, format)
    }

    private func save() {
        let s = score
        var m = match
        m.scoring = format
        s.apply(to: &m)
        ledger.upsert(m)
        MatchLive.end(s, format)
        Haptic.done()
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
