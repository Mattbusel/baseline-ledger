import SwiftUI
import StoreKit
import Charts

/// Baseline Ledger Pro: one non-consumable. Logging is free forever; Pro is the stat book.
///
/// Everyone who installed a build from the paid era keeps everything. AppTransaction's
/// originalAppVersion is the build number they first installed; the paid 1.0 was build 1.
/// Only trusted in production: sandbox and Xcode report made-up values, and App Review
/// must see the real paywall.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.baselineledger.pro"
    static let name = "Baseline Ledger Pro"
    /// The first build that has Pro in it. Anything earlier was sold with every feature.
    static let firstFreemiumBuild = 2

    enum Reason: String, Identifiable {
        case stats, export, racquets, settings
        // 1.2: things only Baseline Ledger Plus has.
        case plan, pressure, backup, plus
        var id: String { rawValue }
        var plusOnly: Bool { [.plan, .pressure, .backup, .plus].contains(self) }
    }

    private(set) var unlocked: Bool
    private(set) var grandfathered = false
    private(set) var product: Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil
    /// Set by the app from Plus: a subscriber gets everything Pro has without buying it.
    var plusActive = false
    /// Pro features are open: bought, grandfathered, or included in Plus.
    var has: Bool { unlocked || plusActive }

    private var updates: Task<Void, Never>?
    private let key = "baselineledger.pro.unlocked"
    private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$4.99" }

    func ask(_ why: Reason) {
        if why.plusOnly ? !plusActive : !has { paywall = why }
    }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production, (Int(app.originalAppVersion) ?? Int.max) < Pro.firstFreemiumBuild {
            grandfathered = true
            grant()
        }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = unlocked ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

// MARK: - What Pro adds, in this app's words

enum ProCopy {
    static let pitch = "Logging, live scoring and head to head stay free forever. Plus turns the ledger into a coach."
    static let short = "The full stat book, momentum and clutch, every racquet, the Form widget, CSV export."
    static let features: [(icon: String, title: String, body: String)] = [
        ("chart.line.uptrend.xyaxis", "Serve and error trends", "First serve percentage and winners against errors, match by match."),
        ("waveform.path.ecg", "Momentum and clutch", "The swing of every match you score live, plus your tiebreak, deciding-set and break point record."),
        ("rectangle.3.group.fill", "The Form widget", "Your last ten results, serve numbers and string life on the Home Screen."),
        ("square.grid.3x3.fill", "Where your serves land", "Wide, body and T on each side, first and second serve."),
        ("tennisball.fill", "Stroke read", "In-play rate by stroke, how you miss, and what to do about it."),
        ("tennis.racket", "Every racquet", "Track strings, tension and hours on as many frames as you carry."),
        ("square.and.arrow.up", "Export the ledger", "Matches and sessions as spreadsheet files, yours to keep."),
    ]
    static func headline(_ r: Pro.Reason) -> String {
        switch r {
        case .export: return "Take your ledger anywhere."
        case .racquets: return "Keep every frame fresh."
        case .plan: return "A new plan every week."
        case .pressure: return "Win the points that matter."
        case .backup: return "Never lose the ledger."
        case .plus: return "Train like you have a coach."
        default: return "Read your game like a pro."
        }
    }
}

extension Ledger {
    /// The paywall teaser: the user's own first serve percentage if there is enough, sample otherwise.
    var proTeaser: (label: String, values: [Double]) {
        let ms = matches.prefix(12).reversed().filter { $0.firstServesTotal > 0 }.map(\.firstServePct)
        if ms.count >= 3 { return ("Your first serve %, last \(ms.count) matches", Array(ms)) }
        return ("What it looks like", [52, 55, 51, 58, 56, 60, 57, 62, 61, 64, 63, 66])
    }

    /// Two spreadsheet files: every match, and every practice session.
    func exportCSV() -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("BaselineLedgerExport", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let day = Date.now.formatted(.iso8601.year().month().day())
        var m = [csvRow(["date", "opponent", "opponent level", "event", "surface", "format", "score", "result", "retired",
                         "aces", "double faults", "first serves in", "first serves", "first serve points won",
                         "second serve points won", "second serve points", "break points won", "break point chances",
                         "break points saved", "break points faced", "winners", "unforced errors", "net points won",
                         "net points", "game plan", "what worked", "what didn't", "notes"])]
        for x in matches {
            m.append(csvRow([x.date.formatted(.iso8601.year().month().day()), x.opponent, x.opponentLevel, x.event,
                             x.surface.rawValue, x.format.rawValue, x.scoreline, x.won ? "won" : "lost", x.retired ? "yes" : "no",
                             "\(x.aces)", "\(x.doubleFaults)", "\(x.firstServesIn)", "\(x.firstServesTotal)",
                             "\(x.firstServePointsWon)", "\(x.secondServePointsWon)", "\(x.secondServePointsPlayed)",
                             "\(x.breakPointsWon)", "\(x.breakPointChances)", "\(x.breakPointsSaved)", "\(x.breakPointsFaced)",
                             "\(x.winners)", "\(x.unforcedErrors)", "\(x.netPointsWon)", "\(x.netPointsPlayed)",
                             x.gamePlan, x.whatWorked, x.whatDidnt, x.notes]))
        }
        var s = [csvRow(["date", "minutes", "place", "partner", "focus", "balls", "longest rally", "rating", "mood", "energy",
                         "cue", "what clicked", "work on next", "journal"])]
        for x in sessions {
            s.append(csvRow([x.date.formatted(.iso8601.year().month().day()), "\(x.minutes)", x.place, x.partner, x.focus,
                             "\(x.balls)", "\(x.longestRally)", "\(x.rating)", "\(x.mood)", "\(x.energy)",
                             x.cue, x.clicked, x.workOn, x.journal]))
        }
        let a = dir.appendingPathComponent("Baseline Ledger matches \(day).csv")
        let b = dir.appendingPathComponent("Baseline Ledger practice \(day).csv")
        try? m.joined(separator: "\n").write(to: a, atomically: true, encoding: .utf8)
        try? s.joined(separator: "\n").write(to: b, atomically: true, encoding: .utf8)
        return [a, b]
    }
}

func csvRow(_ fields: [String]) -> String {
    fields.map { f in
        let needs = f.contains(",") || f.contains("\"") || f.contains("\n")
        return needs ? "\"" + f.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : f
    }.joined(separator: ",")
}

/// A foil wax seal with a lock in it.
struct ProSeal: View {
    var size: CGFloat = 90
    var label = "PRO"
    var body: some View {
        ZStack {
            Circle().fill(Gold.foil)
            Circle().strokeBorder(Gold.ink.opacity(0.35), lineWidth: 1).padding(size * 0.08)
            VStack(spacing: 1) {
                Image(systemName: "lock.fill").font(.system(size: size * 0.2, weight: .bold))
                Text(label).font(.body(size * 0.13, .bold)).tracking(2)
            }
            .foregroundStyle(Gold.ink)
        }
        .frame(width: size, height: size)
        .shadow(color: Gold.leaf.opacity(0.45), radius: 18)
    }
}

// MARK: - Locked content

/// Pro content for a free user: the real section drawn from their own data, frosted, with a way in.
struct LockedSection<Content: View>: View {
    @Environment(Pro.self) private var pro
    let reason: Pro.Reason
    let title: String
    let pitch: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 22) { content }
                .frame(maxHeight: 560, alignment: .top).clipped()
                .blur(radius: 10).allowsHitTesting(false).accessibilityHidden(true)
                .overlay(LinearGradient(colors: [Gold.ink.opacity(0.2), Gold.ink.opacity(0.9)], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 16) {
                ProSeal(size: 96, label: reason.plusOnly ? "PLUS" : "PRO")
                Text(title).font(.display(28)).foregroundStyle(Gold.ivory).multilineTextAlignment(.center)
                Text(pitch).font(.body(14.5)).foregroundStyle(Gold.muted).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                FoilButton(reason.plusOnly ? "See \(Plus.name)" : "See the plans", icon: "sparkles") { pro.ask(reason) }
                if !Shots.on {
                    Text(reason.plusOnly ? "Included in Plus. Your ledger stays yours." : "Pro, or Plus with everything. Your ledger stays yours.")
                        .font(.body(12)).foregroundStyle(Gold.faint)
                }
            }
            .padding(.horizontal, 20).padding(.top, 60)
        }
        .frame(minHeight: 460)
    }
}

/// Export card: Pro shares the files, free opens the paywall.
struct ExportCard: View {
    @Environment(Pro.self) private var pro
    @Environment(Ledger.self) private var ledger
    @State private var files: [URL] = []

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "tablecells").font(.body(17, .semibold)).foil()
                .frame(width: 42, height: 42).background(Circle().fill(Gold.lacquerHi))
            VStack(alignment: .leading, spacing: 2) {
                Text("Export the ledger").font(.display(18, .medium)).foregroundStyle(Gold.ivory)
                Text("Spreadsheet files for Numbers, Excel or Sheets").font(.body(12)).foregroundStyle(Gold.muted)
            }
            Spacer()
            if pro.has {
                ShareLink(items: files) {
                    Image(systemName: "square.and.arrow.up").font(.body(16, .bold)).foregroundStyle(Gold.ink)
                        .frame(width: 44, height: 44).background(Circle().fill(Gold.foil))
                }
                .disabled(files.isEmpty)
            } else {
                Button { pro.ask(.export) } label: {
                    Image(systemName: "lock.fill").font(.body(15, .bold)).foil()
                        .frame(width: 44, height: 44).overlay(Circle().strokeBorder(Gold.hairline, lineWidth: 1))
                }
            }
        }
        .card(padding: 14)
        .task(id: pro.has) { if pro.has { files = ledger.exportCSV() } }
    }
}

