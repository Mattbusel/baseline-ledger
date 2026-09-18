import Foundation

/// Sample history, used only for store screenshots (-shot).
enum Demo {
    static func fill(_ l: Ledger) {
        var rng = SeededRNG(seed: 11)
        let cal = Calendar.current
        func daysAgo(_ d: Int, hour: Int = 18) -> Date {
            cal.date(bySettingHour: hour, minute: 0, second: 0, of: cal.date(byAdding: .day, value: -d, to: .now)!)!
        }
        let cues = [
            ("Split step as they make contact.", "Heavy crosscourt forehand finally sitting deep. Eight rallies past 15.", "Second serve toss drifting left under pressure."),
            ("Unit turn early, then let it go.", "Backhand down the line on the short ball. Committed every time.", "Recovery after the wide forehand. Too slow back to the middle."),
            ("Up and out on the serve. Stay tall.", "Kick serve to the ad-court backhand was a weapon today.", "First volley too flat. Open the face and stay low."),
            ("Watch the ball onto the strings.", "Returns deep through the middle, no free points.", "Overheads: turn sideways before tracking the ball."),
        ]
        let places = ["Riverside Club, Court 4", "City Park courts", "Riverside Club, Court 2", "Ball machine, home club"]
        let partners = ["Coach Dana", "Ravi", "Ball machine", "Sam", "Hitting group"]

        for i in 0..<14 {
            var s = PracticeSession()
            s.date = daysAgo(i * 2 + (i > 4 ? 1 : 0), hour: 7 + (i % 3) * 5)
            s.minutes = [60, 90, 75, 45, 60][i % 5]
            s.place = places[i % places.count]
            s.partner = partners[i % partners.count]
            s.focus = ["Crosscourt consistency", "Second serve kick", "Transition and volleys", "Return depth", "Point construction"][i % 5]
            s.rating = [4, 3, 5, 3, 4, 2, 4][i % 7]
            s.mood = [4, 3, 5, 4, 3][i % 5]
            s.energy = [3, 4, 4, 2, 5][i % 5]
            let c = cues[i % cues.count]
            s.cue = c.0; s.clicked = c.1; s.workOn = c.2
            s.journal = i == 0
                ? "Started with 15 minutes of mini tennis, then crosscourt forehands to a cone target. Depth was there from the start once I stopped trying to hit through the ball and let the spin do it. Serve block was mixed: the kick to the ad side worked, the wide deuce serve kept catching the net. Finished with ten-point tiebreaks and won three of four."
                : "Good structured hit. Stayed patient in the rallies."
            let improve = Double(14 - i) / 14
            let strokes: [Stroke] = i % 3 == 0 ? [.forehand, .backhand, .serve] : i % 3 == 1 ? [.serve, .volley, .ret] : [.forehand, .serve, .points]
            for st in strokes {
                var b = StrokeBlock(stroke: st)
                let n = Int.random(in: 40...70, using: &rng)
                if st.isServe {
                    b.side = i % 2 == 0 ? .deuce : .ad
                    b.serveNumber = i % 4 == 1 ? .second : .first
                    let inRate = b.serveNumber == .first ? 0.52 + improve * 0.12 : 0.82 + improve * 0.08
                    let ins = Int(Double(n) * inRate)
                    b.winners = Int(Double(ins) * 0.1)
                    b.made = ins - b.winners
                    b.zones = [.wide: ins * 3 / 10, .body: ins / 5, .t: ins - ins * 3 / 10 - ins / 5]
                    let f = n - ins
                    b.errors = [.net: f / 2, .long: f / 3, .wide: f - f / 2 - f / 3]
                } else {
                    b.pattern = [.crossCourt, .downTheLine, .insideOut, .liveBall, .deep][Int.random(in: 0...4, using: &rng)]
                    let inRate = 0.72 + improve * 0.14
                    let ins = Int(Double(n) * inRate)
                    b.winners = st == .points || st == .volley ? ins / 6 : ins / 12
                    b.made = ins - b.winners
                    let e = n - ins
                    b.errors = [.net: e * 4 / 10, .long: e * 3 / 10, .wide: e * 2 / 10, .framed: e - e * 4 / 10 - e * 3 / 10 - e * 2 / 10]
                    if st == .forehand || st == .backhand {
                        b.rallies = (0..<6).map { _ in Int.random(in: 6...Int(14 + improve * 16), using: &rng) }
                    }
                }
                s.blocks.append(b)
            }
            l.sessions.append(s)
        }

        let opps = [("Chris Maddox", "UTR 7.4"), ("Jordan Lee", "4.5 NTRP"), ("A. Petrova", "UTR 7.9"), ("Theo Grant", "UTR 6.8"), ("Nico Alvarez", "4.5 NTRP")]
        let events = ["Club ladder", "USTA league", "Fall open, R16", "Practice match", "Club ladder"]
        let scorelines: [[SetScore]] = [
            [SetScore(me: 6, them: 4), SetScore(me: 7, them: 6, tiebreak: 5)],
            [SetScore(me: 4, them: 6), SetScore(me: 6, them: 3), SetScore(me: 10, them: 7)],
            [SetScore(me: 3, them: 6), SetScore(me: 5, them: 7)],
            [SetScore(me: 6, them: 2), SetScore(me: 6, them: 4)],
            [SetScore(me: 6, them: 7, tiebreak: 4), SetScore(me: 6, them: 4), SetScore(me: 8, them: 10)],
        ]
        for i in 0..<12 {
            var m = Match()
            m.date = daysAgo(i * 5 + 2, hour: 10)
            let o = opps[i % opps.count]
            m.opponent = o.0; m.opponentLevel = o.1; m.event = events[i % events.count]
            m.surface = [.hard, .hard, .clay, .indoor][i % 4]
            m.sets = scorelines[i % scorelines.count]
            let games = m.sets.reduce(0) { $0 + $1.me + $1.them }
            let servePts = games * 3
            m.firstServesTotal = servePts
            m.firstServesIn = Int(Double(servePts) * (0.56 + Double(12 - i) * 0.008))
            m.firstServePointsWon = Int(Double(m.firstServesIn) * 0.68)
            m.secondServePointsPlayed = servePts - m.firstServesIn
            m.secondServePointsWon = Int(Double(m.secondServePointsPlayed) * 0.48)
            m.aces = Int.random(in: 1...7, using: &rng)
            m.doubleFaults = Int.random(in: 1...6, using: &rng)
            m.breakPointChances = Int.random(in: 4...11, using: &rng)
            m.breakPointsWon = min(m.breakPointChances, Int.random(in: 1...5, using: &rng))
            m.breakPointsFaced = Int.random(in: 3...9, using: &rng)
            m.breakPointsSaved = Int.random(in: 1...m.breakPointsFaced, using: &rng)
            m.winners = Int.random(in: 14...32, using: &rng)
            m.unforcedErrors = Int.random(in: 16...34, using: &rng) - (12 - i) / 2
            m.netPointsPlayed = Int.random(in: 8...20, using: &rng)
            m.netPointsWon = Int(Double(m.netPointsPlayed) * 0.66)
            m.gamePlan = "Serve to the backhand, crosscourt until the short ball."
            m.whatWorked = i == 0 ? "Kick serve out wide on the ad side. Won 9 of 11 points with it." : "Depth through the middle."
            m.whatDidnt = i == 0 ? "Went for too much on the forehand down the line when leading 5-3." : "Second-serve returns floated."
            m.mood = [4, 3, 2, 5, 3][i % 5]
            l.matches.append(m)
        }

        l.racquets = [
            Racquet(name: "Pure Aero 98", mains: "RPM Blast 17", crosses: "RPM Blast 17", mainTension: 52, crossTension: 50,
                    strung: daysAgo(12), hours: 9.5,
                    history: [Restring(date: daysAgo(12), setup: "RPM Blast 17 @ 52/50", hours: 0),
                              Restring(date: daysAgo(40), setup: "RPM Blast 17 @ 53/51", hours: 16),
                              Restring(date: daysAgo(71), setup: "ALU Power 16L @ 50/48", hours: 13)]),
            Racquet(name: "Pure Aero 98 (backup)", mains: "ALU Power 16L", crosses: "X-One Biphase 16", mainTension: 50, crossTension: 52,
                    strung: daysAgo(33), hours: 3),
        ]
        l.goals = [
            Goal(text: "First serve over 60% in a match", due: cal.date(byAdding: .day, value: 45, to: .now)),
            Goal(text: "Reach UTR 8", due: cal.date(byAdding: .month, value: 4, to: .now)),
            Goal(text: "20-ball crosscourt rally, backhand", due: nil, done: true),
        ]
        l.name = "Matthew"
        l.sessions.sort { $0.date > $1.date }
        l.matches.sort { $0.date > $1.date }
    }
}

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
