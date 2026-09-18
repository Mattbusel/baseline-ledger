import Foundation
import Observation

// MARK: practice

enum Stroke: String, Codable, CaseIterable, Identifiable {
    case forehand = "Forehand", backhand = "Backhand", serve = "Serve", ret = "Return",
         volley = "Volley", overhead = "Overhead", slice = "Slice", drop = "Drop Shot", points = "Points"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .forehand: return "arrow.right"
        case .backhand: return "arrow.left"
        case .serve: return "arrow.up.to.line"
        case .ret: return "arrow.uturn.left"
        case .volley: return "hand.raised"
        case .overhead: return "arrow.down.right"
        case .slice: return "wind"
        case .drop: return "arrow.down.to.line"
        case .points: return "tennisball"
        }
    }
    var isServe: Bool { self == .serve }
}

enum Pattern: String, Codable, CaseIterable {
    case crossCourt = "Cross-court", downTheLine = "Down the line", insideOut = "Inside-out", insideIn = "Inside-in",
         deep = "Deep middle", liveBall = "Live ball", basket = "Basket feed"
}
enum StrokeError: String, Codable, CaseIterable { case net = "Net", long = "Long", wide = "Wide", framed = "Framed" }
enum Side: String, Codable, CaseIterable { case deuce = "Deuce", ad = "Ad" }
enum ServeNumber: String, Codable, CaseIterable { case first = "1st", second = "2nd" }
enum Zone: String, Codable, CaseIterable { case wide = "Wide", body = "Body", t = "T" }

/// One block of practice: a stroke and a pattern, with every ball tallied.
struct StrokeBlock: Codable, Identifiable, Hashable {
    var id = UUID()
    var stroke: Stroke
    var pattern: Pattern = .crossCourt
    var side: Side = .deuce
    var serveNumber: ServeNumber = .first

    var made: Int = 0                   // in play, to target
    var winners: Int = 0                // clean winners / aces
    var errors: [StrokeError: Int] = [:]
    var zones: [Zone: Int] = [:]        // serves that landed, by zone
    var rallies: [Int] = []             // rally lengths, for consistency drills
    var note: String = ""

    var errorCount: Int { errors.values.reduce(0, +) }
    var balls: Int { made + winners + errorCount }
    var inRate: Double { pctValue(made + winners, balls) }
    var title: String {
        stroke.isServe ? "\(serveNumber.rawValue) serve · \(side.rawValue)" : stroke == .points ? "Point play" : "\(stroke.rawValue) · \(pattern.rawValue)"
    }
}

struct PracticeSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date.now
    var minutes: Int = 0
    var place: String = ""
    var partner: String = ""
    var focus: String = ""
    var blocks: [StrokeBlock] = []
    var rating: Int = 3
    var mood: Int = 3
    var energy: Int = 3
    var cue: String = ""
    var clicked: String = ""
    var workOn: String = ""
    var journal: String = ""

    var balls: Int { blocks.reduce(0) { $0 + $1.balls } }
    var longestRally: Int { blocks.flatMap(\.rallies).max() ?? 0 }
}

// MARK: matches

enum Surface: String, Codable, CaseIterable { case hard = "Hard", clay = "Clay", grass = "Grass", indoor = "Indoor", carpet = "Carpet" }
enum Format: String, Codable, CaseIterable { case singles = "Singles", doubles = "Doubles" }

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

struct Match: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date.now
    var opponent: String = ""
    var opponentLevel: String = ""
    var event: String = ""
    var surface: Surface = .hard
    var format: Format = .singles
    var sets: [SetScore] = [SetScore(me: 0, them: 0)]
    var retired = false

    var aces = 0
    var doubleFaults = 0
    var firstServesIn = 0
    var firstServesTotal = 0
    var firstServePointsWon = 0
    var secondServePointsWon = 0
    var secondServePointsPlayed = 0
    var breakPointsWon = 0
    var breakPointChances = 0
    var breakPointsSaved = 0
    var breakPointsFaced = 0
    var winners = 0
    var unforcedErrors = 0
    var netPointsWon = 0
    var netPointsPlayed = 0

    var gamePlan: String = ""
    var whatWorked: String = ""
    var whatDidnt: String = ""
    var notes: String = ""
    var mood: Int = 3

    var setsWon: Int { sets.filter(\.won).count }
    var setsLost: Int { sets.filter { $0.them > $0.me }.count }
    var won: Bool { setsWon > setsLost }
    var scoreline: String { sets.map(\.text).joined(separator: "  ") }
    var firstServePct: Double { pctValue(firstServesIn, firstServesTotal) }
}

// MARK: gear

struct Racquet: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var mains: String
    var crosses: String
    var mainTension: Int
    var crossTension: Int
    var strung: Date
    var hours: Double = 0
    var history: [Restring] = []

    /// Most polyester strings go dead somewhere past 10 to 15 hours of hitting.
    var freshness: Double { max(0, 1 - hours / 15) }
}

struct Restring: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var setup: String
    var hours: Double
}

struct Goal: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var due: Date?
    var done = false
}

// MARK: store

@Observable
final class Ledger {
    var sessions: [PracticeSession] = [] { didSet { save() } }
    var matches: [Match] = [] { didSet { save() } }
    var racquets: [Racquet] = [] { didSet { save() } }
    var goals: [Goal] = [] { didSet { save() } }
    var name: String = "" { didSet { save() } }

    private struct Snapshot: Codable {
        var sessions: [PracticeSession]; var matches: [Match]; var racquets: [Racquet]; var goals: [Goal]; var name: String
    }
    private var loading = false
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ledger.json")

    init(demo: Bool = false) {
        loading = true
        if demo { Demo.fill(self) } else if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Snapshot.self, from: d) {
            sessions = s.sessions; matches = s.matches; racquets = s.racquets; goals = s.goals; name = s.name
        }
        loading = false
    }

    private func save() {
        guard !loading else { return }
        let snap = Snapshot(sessions: sessions, matches: matches, racquets: racquets, goals: goals, name: name)
        if let d = try? JSONEncoder().encode(snap) { try? d.write(to: url, options: .atomic) }
    }

    func upsert(_ s: PracticeSession) {
        if let i = sessions.firstIndex(where: { $0.id == s.id }) {
            sessions[i] = s
        } else {
            sessions.insert(s, at: 0)
            // Hitting time goes on the racquet currently in use.
            if !racquets.isEmpty { racquets[0].hours += Double(s.minutes) / 60 }
        }
        sessions.sort { $0.date > $1.date }
    }
    func upsert(_ m: Match) {
        if let i = matches.firstIndex(where: { $0.id == m.id }) { matches[i] = m } else { matches.insert(m, at: 0) }
        matches.sort { $0.date > $1.date }
    }

    // MARK: derived

    var record: (won: Int, lost: Int) { (matches.filter(\.won).count, matches.filter { !$0.won }.count) }

    func minutes(inLast days: Int) -> Int {
        let from = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        return sessions.filter { $0.date >= from }.reduce(0) { $0 + $1.minutes }
    }

    var practiceStreakWeeks: Int {
        let cal = Calendar.current
        var n = 0
        var week = cal.dateInterval(of: .weekOfYear, for: .now)!
        while sessions.contains(where: { week.contains($0.date) }) {
            n += 1
            week = cal.dateInterval(of: .weekOfYear, for: week.start.addingTimeInterval(-3600))!
        }
        return n
    }

    var allBlocks: [StrokeBlock] { sessions.flatMap(\.blocks) }

    func blocks(_ s: Stroke) -> [StrokeBlock] { allBlocks.filter { $0.stroke == s } }

    var errorTotals: [StrokeError: Int] {
        allBlocks.reduce(into: [:]) { acc, b in for (k, v) in b.errors { acc[k, default: 0] += v } }
    }

    func zoneTotals(side: Side) -> [Zone: Int] {
        blocks(.serve).filter { $0.side == side }.reduce(into: [:]) { acc, b in for (k, v) in b.zones { acc[k, default: 0] += v } }
    }

    var minutesByStroke: [(Stroke, Int)] {
        var m: [Stroke: Int] = [:]
        for s in sessions where !s.blocks.isEmpty {
            let per = s.minutes / s.blocks.count
            for b in s.blocks { m[b.stroke, default: 0] += per }
        }
        return Stroke.allCases.compactMap { k in m[k].map { (k, $0) } }.filter { $0.1 > 0 }
    }
}
