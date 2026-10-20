import AppIntents
import SwiftUI
import TipKit

// MARK: - Siri, Shortcuts, Spotlight and the Action button

struct ScoreMatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Score a Match"
    static var description = IntentDescription("Opens the live scorer, ready for a new match.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Router.shared.open(.score)
        return .result()
    }
}

struct StartHittingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Hitting"
    static var description = IntentDescription("Starts a practice session, ball by ball.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Router.shared.open(.hit)
        return .result()
    }
}

struct MatchRecordIntent: AppIntent {
    static var title: LocalizedStringResource = "Match Record"
    static var description = IntentDescription("Says your match record, your streak and this week's court time.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let g = Glance.load()
        guard g.won + g.lost > 0 else {
            return .result(dialog: "No matches in your ledger yet. Score your next one live.")
        }
        var line = "You're \(g.won) and \(g.lost)."
        if g.winStreak > 1 { line += " \(g.winStreak) wins in a row." }
        if !g.lastOpponent.isEmpty { line += " Last time you \(g.lastWon ? "beat" : "lost to") \(g.lastOpponent), \(g.lastScore)." }
        line += " \(g.weekMinutes) minutes on court this week."
        return .result(dialog: IntentDialog(stringLiteral: line))
    }
}

struct BaselineShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ScoreMatchIntent(), phrases: [
            "Score a match in \(.applicationName)",
            "Start a match in \(.applicationName)",
            "Keep score with \(.applicationName)",
        ], shortTitle: "Score a Match", systemImageName: "tennisball.fill")
        AppShortcut(intent: StartHittingIntent(), phrases: [
            "Start hitting in \(.applicationName)",
            "Start practice in \(.applicationName)",
        ], shortTitle: "Start Hitting", systemImageName: "figure.tennis")
        AppShortcut(intent: MatchRecordIntent(), phrases: [
            "What's my record in \(.applicationName)",
            "My tennis record in \(.applicationName)",
        ], shortTitle: "Match Record", systemImageName: "trophy.fill")
    }
}

// MARK: - Tips

struct ScoreLiveTip: Tip {
    var title: Text { Text("Score it live") }
    var message: Text? { Text("Tap who won each point. The score, serve numbers and break points fill themselves in.") }
    var image: Image? { Image(systemName: "tennisball.fill") }
}

struct LockScreenTip: Tip {
    var title: Text { Text("Score from your Lock Screen") }
    var message: Text? { Text("Lock your phone between points: Won, Lost and Fault are right on the Lock Screen and in the Dynamic Island. No unlocking.") }
    var image: Image? { Image(systemName: "lock.iphone") }
}

struct HeadToHeadTip: Tip {
    var title: Text { Text("Head to head") }
    var message: Text? { Text("Everyone you've played, your record against them, and a scouting report before the rematch.") }
    var image: Image? { Image(systemName: "person.2.fill") }
}
