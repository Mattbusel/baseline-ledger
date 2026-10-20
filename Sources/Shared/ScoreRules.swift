import Foundation

// The rules of tennis scoring, shared by the app and the widget extension so a point scored
// from the Lock Screen is counted by exactly the same code as one scored in the app.

struct SetScore: Codable, Hashable, Identifiable {
    var id = UUID()
    var me: Int
    var them: Int
    var tiebreak: Int? = nil   // loser's tiebreak points, the way it's written
    var text: String {
        if let tiebreak { return "\(me)-\(them)(\(tiebreak))" }
        return "\(me)-\(them)"
    }
    var won: Bool { me > them }
}

/// How a point ended, from the point of view of whoever hit the last good ball.
enum PointKind: String, Codable, CaseIterable {
    case rally, ace, doubleFault, winner, error
}

/// One point of a match scored live.
struct PointLog: Codable, Hashable {
    var iWon: Bool
    var iServed: Bool
    var kind: PointKind = .rally
    /// The point started on a first serve. False: second serve (or a double fault).
    var firstIn: Bool = true
}

/// The rules a live match is scored under.
struct LiveFormat: Codable, Hashable {
    /// 1 (one set) or 3.
    var bestOf: Int = 3
    var noAd = false
    /// The deciding set is a 10-point match tiebreak.
    var matchTiebreak = true
    var iServeFirst = true
}

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

    /// `each` sees the score before and after every point, for the pressure numbers.
    static func replay(_ points: [PointLog], _ f: LiveFormat, each: ((ScoreState, PointLog, ScoreState) -> Void)? = nil) -> ScoreState {
        var s = ScoreState()
        s.iServe = f.iServeFirst
        var tbFirstServerMe = s.iServe
        var tbPoints = 0
        var diff = 0
        for p in points {
            guard !s.over else { break }
            let before: ScoreState? = each == nil ? nil : s
            defer { if let before { each?(before, p, s) } }
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
}

