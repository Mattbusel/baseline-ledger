import ActivityKit
import AppIntents
import Foundation

/// The match being scored right now, written to the app group after every point. It is what lets a
/// match survive the app being closed mid-set, and what the Lock Screen buttons score into without
/// opening the app.
struct LiveDraft: Codable, Equatable {
    var matchID: UUID
    /// The match itself (opponent, event, surface), encoded by the app. Opaque to the widget.
    var match: Data
    var opponent: String
    var format: LiveFormat
    var points: [PointLog] = []
    var secondServe = false
    var updated = Date.now

    static let key = "liveDraft"
    /// Posted in the app's process when a point arrives from the Lock Screen.
    static let changed = Notification.Name("LiveDraftChanged")

    static func load() -> LiveDraft? {
        guard let d = Shared.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LiveDraft.self, from: d)
    }
    func save() {
        var me = self
        me.updated = .now
        if let d = try? JSONEncoder().encode(me) { Shared.defaults.set(d, forKey: LiveDraft.key) }
    }
    static func clear() { Shared.defaults.removeObject(forKey: key) }

    var score: ScoreState { ScoreState.replay(points, format) }

    /// One tap from the Lock Screen: "won", "lost" or "fault". The same rules the in-app buttons use.
    mutating func apply(_ action: String) {
        let s = score
        guard !s.over else { return }
        switch action {
        case "fault":
            if secondServe {
                points.append(PointLog(iWon: !s.iServe, iServed: s.iServe, kind: .doubleFault, firstIn: false))
                secondServe = false
            } else {
                secondServe = true
            }
        case "won", "lost":
            points.append(PointLog(iWon: action == "won", iServed: s.iServe, kind: .rally, firstIn: !secondServe))
            secondServe = false
        case "undo":
            if secondServe { secondServe = false } else if !points.isEmpty { points.removeLast() }
        default: break
        }
    }
}

extension MatchActivity.ContentState {
    /// What the Lock Screen and the Dynamic Island show for a score.
    init(_ s: ScoreState, _ f: LiveFormat, secondServe: Bool = false) {
        let c = s.call(f)
        self.init(me: s.sets.map(\.me), them: s.sets.map(\.them), pointMe: c.me, pointThem: c.them, iServe: s.iServe,
                  status: s.breakPoint(f) ? "Break point" : s.facingBreak(f) ? "Break point against" : s.status,
                  secondServe: secondServe, over: s.over)
    }
}

/// The Won, Lost and Fault buttons on the Lock Screen. Live Activity intents run in the app's process,
/// so the point goes through the same draft the in-app scorer reads.
struct ScorePointIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Score a point"
    static var description = IntentDescription("Scores a point in the match on your Lock Screen.")

    @Parameter(title: "Point") var action: String

    init() {}
    init(_ action: String) { self.action = action }

    func perform() async throws -> some IntentResult {
        guard var d = LiveDraft.load() else { return .result() }
        d.apply(action)
        d.save()
        let state = MatchActivity.ContentState(d.score, d.format, secondServe: d.secondServe)
        for a in Activity<MatchActivity>.activities {
            await a.update(.init(state: state, staleDate: .now.addingTimeInterval(5 * 3600)))
        }
        await MainActor.run { NotificationCenter.default.post(name: LiveDraft.changed, object: nil) }
        return .result()
    }
}
