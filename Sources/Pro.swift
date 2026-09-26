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

    enum Reason: String, Identifiable { case stats, export, racquets, settings; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var grandfathered = false
    private(set) var product: Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil

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

    func ask(_ why: Reason) { if !unlocked { paywall = why } }

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
    static let pitch = "Logging stays free forever. Pro turns the ledger into a stat book."
    static let short = "The full stat book, every racquet, CSV export."
    static let features: [(icon: String, title: String, body: String)] = [
        ("chart.line.uptrend.xyaxis", "Serve and error trends", "First serve percentage and winners against errors, match by match."),
        ("square.grid.3x3.fill", "Where your serves land", "Wide, body and T on each side, first and second serve."),
        ("tennisball.fill", "Stroke read", "In-play rate by stroke, how you miss, and what to do about it."),
        ("tennis.racket", "Every racquet", "Track strings, tension and hours on as many frames as you carry."),
        ("square.and.arrow.up", "Export the ledger", "Matches and sessions as spreadsheet files, yours to keep."),
    ]
    static func headline(_ r: Pro.Reason) -> String {
        switch r {
        case .export: return "Take your ledger anywhere."
        case .racquets: return "Keep every frame fresh."
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

// MARK: - Paywall

struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var shown = false

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    SheetHeader(eyebrow: Pro.name, title: ProCopy.headline(reason)) { dismiss() }
                        .padding(.horizontal, -20)
                    Text(ProCopy.pitch).font(.body(15)).foregroundStyle(Gold.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    teaser
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(ProCopy.features, id: \.title) { f in feature(f.icon, f.title, f.body) }
                    }
                    .card()
                    priceBlock
                    if let m = pro.message {
                        Text(m).font(.body(13, .semibold)).foregroundStyle(Gold.pale)
                            .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    }
                    FoilButton(pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "lock.open.fill") {
                        Task { await pro.buy() }
                    }
                    .disabled(pro.busy)
                    HStack(spacing: 12) {
                        GhostButton("Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        GhostButton("Not now") { dismiss() }.frame(width: 120)
                    }
                    Text("One payment, yours for good. No subscription. Family Sharing works. Everything you have logged stays yours, Pro or not.")
                        .font(.body(11.5)).foregroundStyle(Gold.faint).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.15)) { shown = true } }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    private var teaser: some View {
        let t = ledger.proTeaser
        let lo = (t.values.min() ?? 0) - 2, hi = (t.values.max() ?? 1) + 2
        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow(t.label)
            Chart(Array(t.values.enumerated()), id: \.offset) { item in
                AreaMark(x: .value("i", item.offset), yStart: .value("lo", lo), yEnd: .value("v", item.element))
                    .foregroundStyle(LinearGradient(colors: [Gold.leaf.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("i", item.offset), y: .value("v", item.element))
                    .foregroundStyle(Gold.foil).lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: lo...hi)
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .frame(height: 120)
            .blur(radius: 4)
            .overlay { ProSeal(size: 84).scaleEffect(shown ? 1 : 0.3).rotationEffect(.degrees(shown ? 0 : -30)) }
        }
        .card()
    }

    private var priceBlock: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pro.price).font(.figure(40, .light)).foil()
                Text("ONCE. NOT A MONTH.").font(.body(10.5, .semibold)).tracking(2).foregroundStyle(Gold.muted)
            }
            Spacer()
            Text("No\nsubscription").font(.display(14).italic()).multilineTextAlignment(.trailing).foregroundStyle(Gold.pale)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Gold.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .card()
    }

    private func feature(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.body(15, .semibold)).foil()
                .frame(width: 38, height: 38).background(Circle().fill(Gold.lacquerHi))
                .overlay(Circle().strokeBorder(Gold.hairline, lineWidth: 0.8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.display(18, .medium)).foregroundStyle(Gold.ivory)
                Text(body).font(.body(13)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A foil wax seal with a lock in it.
struct ProSeal: View {
    var size: CGFloat = 90
    var body: some View {
        ZStack {
            Circle().fill(Gold.foil)
            Circle().strokeBorder(Gold.ink.opacity(0.35), lineWidth: 1).padding(size * 0.08)
            VStack(spacing: 1) {
                Image(systemName: "lock.fill").font(.system(size: size * 0.2, weight: .bold))
                Text("PRO").font(.body(size * 0.13, .bold)).tracking(2)
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
                ProSeal(size: 96)
                Text(title).font(.display(28)).foregroundStyle(Gold.ivory).multilineTextAlignment(.center)
                Text(pitch).font(.body(14.5)).foregroundStyle(Gold.muted).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                FoilButton("See \(Pro.name)", icon: "sparkles") { pro.ask(reason) }
                Text("\(pro.price) once. Your ledger stays free.").font(.body(12)).foregroundStyle(Gold.faint)
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
            if pro.unlocked {
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
        .task(id: pro.unlocked) { if pro.unlocked { files = ledger.exportCSV() } }
    }
}

/// The Pro status card on Home, with Restore always in reach.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(pro.unlocked ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi))
                Image(systemName: pro.unlocked ? "checkmark" : "lock.fill").font(.body(13, .bold))
                    .foregroundStyle(pro.unlocked ? AnyShapeStyle(Gold.ink) : AnyShapeStyle(Gold.foil))
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(pro.unlocked ? Pro.name : "\(Pro.name), \(pro.price) once").font(.display(17, .medium)).foregroundStyle(Gold.ivory)
                Text(pro.unlocked ? (pro.grandfathered ? "Unlocked. Thanks for buying the ledger early." : "Unlocked. Thank you.") : ProCopy.short)
                    .font(.body(12)).foregroundStyle(Gold.muted)
                if let m = pro.message, pro.paywall == nil { Text(m).font(.body(11.5, .semibold)).foregroundStyle(Gold.pale) }
            }
            Spacer(minLength: 6)
            if !pro.unlocked {
                VStack(alignment: .trailing, spacing: 8) {
                    Button { pro.ask(.settings) } label: {
                        Text("SEE").font(.body(12, .bold)).tracking(1.5).foregroundStyle(Gold.ink)
                            .padding(.horizontal, 14).padding(.vertical, 8).background(Capsule().fill(Gold.foil))
                    }
                    .buttonStyle(PressStyle())
                    Button { Task { await pro.restore() } } label: {
                        Text("Restore").font(.body(11, .semibold)).foregroundStyle(Gold.muted).underline()
                    }
                }
            }
        }
        .card(padding: 14)
    }
}
