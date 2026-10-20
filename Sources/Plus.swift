import Charts
import StoreKit
import SwiftUI

/// True while the app is being driven for App Store screenshots: no prices, no StoreKit.
enum Shots {
    static let on = ProcessInfo.processInfo.arguments.contains("-shot") || ProcessInfo.processInfo.arguments.contains("-demoPreview")
}

enum Legal {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://tensorust.com/apps/baseline-ledger/privacy/")!
}

/// Baseline Ledger Plus: an auto-renewable subscription (monthly, or yearly with a free week).
/// Everything in Pro, plus the things that keep coming: a new practice plan every week, pressure
/// numbers, every court finish, monthly scouting reports and posters, and iCloud backup.
/// Kept apart from Pro so the one-time unlock and its grandfathering stay exactly as they were.
@MainActor
@Observable
final class Plus {
    static let monthlyID = "com.mattbusel.baselineledger.plus.monthly"
    static let yearlyID = "com.mattbusel.baselineledger.plus.yearly"
    static let ids = [yearlyID, monthlyID]
    static let name = "Baseline Ledger Plus"
    /// Posted after a purchase that started on the App Store product page.
    static let storeChanged = Notification.Name("BaselineStoreChanged")

    private(set) var active: Bool
    private(set) var products: [String: Product] = [:]
    /// The plan the subscriber is on, and when it renews or runs out.
    private(set) var plan: String?
    private(set) var renews: Date?
    private(set) var willRenew = true
    private(set) var trialEligible = true
    var busy = false
    var message: String?

    private var updates: Task<Void, Never>?
    private var intents: Task<Void, Never>?
    private let key = "baselineledger.plus.active"
    private let forced: Bool

    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { active = forced; plan = forced ? Plus.yearlyID : nil; return }
        active = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await r in Transaction.updates {
                guard case .verified(let t) = r, Plus.ids.contains(t.productID) else { continue }
                await t.finish()
                await self?.refresh()
            }
        }
        // A purchase started from the App Store product page (promoted in-app purchases): Plus, or a court finish.
        // Extras and Pro pick their own transactions up from Transaction.updates.
        intents = Task { [weak self] in
            for await intent in PurchaseIntent.intents {
                if case .success(let r)? = try? await intent.product.purchase(), case .verified(let t) = r { await t.finish() }
                await self?.refresh()
                NotificationCenter.default.post(name: Plus.storeChanged, object: nil)
            }
        }
        Task { await refresh() }
    }

    func product(_ id: String) -> Product? { products[id] }
    func price(_ id: String) -> String { products[id]?.displayPrice ?? (id == Plus.yearlyID ? "$14.99" : "$2.99") }
    func period(_ id: String) -> String { id == Plus.yearlyID ? "year" : "month" }

    /// The yearly price spread over twelve months, for comparing the plans.
    var yearlyPerMonth: String? {
        guard let p = products[Plus.yearlyID] else { return Shots.on ? nil : "$1.25" }
        return (p.price / 12).formatted(p.priceFormatStyle)
    }

    /// The free trial on the yearly plan, as the App Store has it configured, e.g. "1 week".
    var trialText: String? {
        guard trialEligible, let offer = products[Plus.yearlyID]?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else {
            return products[Plus.yearlyID] == nil && trialEligible ? "1 week" : nil
        }
        let u = offer.period.unit, n = offer.period.value
        let unit: String
        switch u {
        case .day: unit = n == 7 ? "week" : "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "week"
        }
        let count = u == .day && n == 7 ? 1 : n
        return "\(count) \(unit)\(count == 1 ? "" : "s")"
    }

    func refresh() async {
        guard !forced else { return }
        if products.count < Plus.ids.count, let ps = try? await Product.products(for: Plus.ids) {
            for p in ps { products[p.id] = p }
        }
        var on = false, which: String?, until: Date?, renewing = true
        for await r in Transaction.currentEntitlements {
            guard case .verified(let t) = r, Plus.ids.contains(t.productID), t.revocationDate == nil else { continue }
            if let e = t.expirationDate, e < .now { continue }
            on = true; which = t.productID; until = t.expirationDate
        }
        if let p = products[Plus.yearlyID] ?? products[Plus.monthlyID], let sub = p.subscription {
            trialEligible = await sub.isEligibleForIntroOffer
            if on, let statuses = try? await sub.status {
                for st in statuses {
                    if case .verified(let info) = st.renewalInfo, Plus.ids.contains(info.currentProductID) { renewing = info.willAutoRenew }
                }
            }
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { active = on }
        plan = which; renews = until; willRenew = renewing
        UserDefaults.standard.set(on, forKey: key)
    }

    func buy(_ id: String) async -> Bool {
        guard !forced, !busy else { return false }
        busy = true; message = nil
        defer { busy = false }
        if products[id] == nil { await refresh() }
        guard let p = products[id] else {
            message = "The App Store did not answer. Check your connection and try again."
            return false
        }
        do {
            switch try await p.purchase() {
            case .success(let r):
                if case .verified(let t) = r { await t.finish() }
                await refresh()
                if active { Haptic.done(); return true }
                message = "Apple could not confirm the subscription. Try Restore in a minute."
            case .pending: message = "Waiting for approval. Plus starts by itself once it is approved."
            case .userCancelled: break
            @unknown default: message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
        return false
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
        message = active ? "Plus is active. Welcome back." : nil
    }
}

// MARK: - What each tier has

enum PlusCopy {
    static let features: [(icon: String, title: String, body: String)] = [
        ("list.bullet.clipboard.fill", "A new practice plan every week", "Built from your own numbers: your weakest stroke, your miss, your serve. Four drills with targets."),
        ("flame.fill", "Pressure points", "Hold and break rates, deuce and 30-all points, tiebreak points, from every match you score live."),
        ("binoculars.fill", "10 scouting reports a month", "Plus 10 match posters, topped up on the first of every month."),
        ("paintpalette.fill", "Every court finish", "Red Clay, Lawn, Hard Court and Night Session, with their app icons."),
        ("icloud.fill", "iCloud backup", "The whole ledger backed up to your iCloud, restored on a new phone in one tap."),
        ("chart.xyaxis.line", "Everything in Pro", "The full stat book, momentum and clutch, the Form widget, every racquet, spreadsheet export."),
    ]
}

// MARK: - Paywall

/// Plus (yearly or monthly) first, the one-time Pro below it. Shows the price, the period, the trial,
/// the renewal terms and the legal links, as App Review asks.
struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(Plus.self) private var plus
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var pick = Plus.yearlyID
    @State private var shown = false
    @State private var redeem = false
    @State private var manage = false

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    SheetHeader(eyebrow: Plus.name, title: ProCopy.headline(reason)) { dismiss() }
                        .padding(.horizontal, -20)
                    Text(ProCopy.pitch).font(.body(15)).foregroundStyle(Gold.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    teaser
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(PlusCopy.features, id: \.title) { f in feature(f.icon, f.title, f.body) }
                    }
                    .card()
                    if plus.active { activeCard } else { plans }
                    if let m = plus.message ?? pro.message {
                        Text(m).font(.body(13, .semibold)).foregroundStyle(Gold.pale)
                            .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    }
                    if !plus.active {
                        FoilButton(cta, icon: "sparkles") { Task { if await plus.buy(pick) { dismiss() } } }
                            .disabled(plus.busy)
                        terms
                    }
                    if !reason.plusOnly && !pro.unlocked && !plus.active { proOnce }
                    if pro.unlocked && !plus.active {
                        Text(pro.grandfathered ? "You own Pro from the early days, and it stays yours. Plus adds the weekly plan, pressure points, every finish, monthly reports and posters, and backup."
                                               : "You own Pro, and it stays yours. Plus adds the weekly plan, pressure points, every finish, monthly reports and posters, and backup.")
                            .font(.body(12.5)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    links
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.15)) { shown = true } }
        .onChange(of: pro.has) { _, now in if now && !reason.plusOnly { dismiss() } }
        .offerCodeRedemption(isPresented: $redeem) { _ in Task { await plus.refresh(); await pro.refresh() } }
        .manageSubscriptionsSheet(isPresented: $manage)
        .task { await plus.refresh() }
    }

    private var cta: String {
        if plus.busy { return "One moment" }
        if pick == Plus.yearlyID, let t = plus.trialText { return "Start your free \(t)" }
        return "Subscribe for \(plus.price(pick)) a \(plus.period(pick))"
    }

    private var plans: some View {
        VStack(spacing: 10) {
            planRow(Plus.yearlyID, title: "Yearly",
                    line: plus.trialText.map { "\($0) free, then \(plus.price(Plus.yearlyID)) a year" } ?? "\(plus.price(Plus.yearlyID)) a year",
                    badge: plus.yearlyPerMonth.map { "\($0) a month" })
            planRow(Plus.monthlyID, title: "Monthly", line: "\(plus.price(Plus.monthlyID)) a month", badge: nil)
        }
    }

    private func planRow(_ id: String, title: String, line: String, badge: String?) -> some View {
        let on = pick == id
        return Button { Haptic.tap(); withAnimation(.snappy) { pick = id } } label: {
            HStack(spacing: 14) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                    .foregroundStyle(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.faint))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.display(19, .medium)).foregroundStyle(Gold.ivory)
                    Text(line).font(.body(13)).foregroundStyle(Gold.muted)
                }
                Spacer()
                if let badge {
                    Text(badge).font(.body(11.5, .bold)).foregroundStyle(Gold.ink)
                        .padding(.horizontal, 10).frame(height: 26).background(Capsule().fill(Gold.foil))
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Gold.lacquer))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.leaf.opacity(0.15)), lineWidth: on ? 1.6 : 0.8))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(title) plan, \(line)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var activeCard: some View {
        HStack(spacing: 14) {
            ProSeal(size: 56, label: "PLUS")
            VStack(alignment: .leading, spacing: 3) {
                Text("Plus is active").font(.display(19, .medium)).foregroundStyle(Gold.ivory)
                if let r = plus.renews {
                    Text("\(plus.willRenew ? "Renews" : "Ends") \(r.formatted(date: .abbreviated, time: .omitted))").font(.body(12.5)).foregroundStyle(Gold.muted)
                }
            }
            Spacer()
        }
        .card(padding: 16)
    }

    private var terms: some View {
        let y = plus.price(Plus.yearlyID), m = plus.price(Plus.monthlyID)
        let trial = plus.trialText.map { " The yearly plan starts with a free \($0) for new subscribers; if you don't cancel at least 24 hours before it ends, it becomes a paid yearly subscription." } ?? ""
        return Text("Plus is an auto-renewing subscription: \(y) a year or \(m) a month, charged to your Apple ID when you confirm. It renews automatically at the same price unless you turn off auto-renew at least 24 hours before the end of the current period; you can manage or cancel it any time in Settings > your name > Subscriptions.\(trial)")
            .font(.body(11)).foregroundStyle(Gold.faint).fixedSize(horizontal: false, vertical: true)
    }

    private var proOnce: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Or just the stat book")
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Pro.name), once").font(.display(18, .medium)).foregroundStyle(Gold.ivory)
                    Text(ProCopy.short).font(.body(12.5)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Button { Task { await pro.buy() } } label: {
                    Text(pro.busy ? "…" : pro.price).font(.body(14, .bold)).foregroundStyle(Gold.ink)
                        .padding(.horizontal, 14).frame(height: 36).background(Capsule().fill(Gold.foil))
                }
                .buttonStyle(PressStyle()).disabled(pro.busy)
                .accessibilityLabel("Unlock Pro for \(pro.price), one payment")
            }
            Text("One payment, no renewals. Family Sharing works.").font(.body(11)).foregroundStyle(Gold.faint)
        }
        .card(padding: 16)
    }

    private var links: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                GhostButton("Restore", icon: "arrow.clockwise") { Task { await plus.restore(); await pro.restore() } }
                GhostButton("Redeem code", icon: "giftcard") { redeem = true }
            }
            if plus.active { GhostButton("Manage subscription", icon: "gearshape") { manage = true } }
            HStack(spacing: 18) {
                Link("Terms of Use", destination: Legal.terms)
                Link("Privacy Policy", destination: Legal.privacy)
                Button("Not now") { dismiss() }
            }
            .font(.body(12.5, .semibold)).foregroundStyle(Gold.muted)
            Text("Everything you have logged stays yours, with or without Plus.").font(.body(11)).foregroundStyle(Gold.faint)
        }
        .frame(maxWidth: .infinity)
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
            .frame(height: 100)
            .blur(radius: 4)
            .overlay { ProSeal(size: 78, label: "PLUS").scaleEffect(shown ? 1 : 0.3).rotationEffect(.degrees(shown ? 0 : -30)) }
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
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Membership card on Home

/// Where you stand: free, Pro, or Plus. Restore always in reach.
struct MembershipCard: View {
    @Environment(Pro.self) private var pro
    @Environment(Plus.self) private var plus
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(plus.active ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi))
                Image(systemName: plus.active ? "checkmark" : "sparkles").font(.body(13, .bold))
                    .foregroundStyle(plus.active ? AnyShapeStyle(Gold.ink) : AnyShapeStyle(Gold.foil))
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(plus.active ? Plus.name : pro.unlocked ? "\(Pro.name) is yours" : Plus.name).font(.display(17, .medium)).foregroundStyle(Gold.ivory)
                Text(plus.active ? "Active. Your plan, pressure points, finishes and backup are on."
                     : pro.unlocked ? (pro.grandfathered ? "Thanks for buying the ledger early. Plus adds a weekly plan, pressure points and more." : "Plus adds a weekly plan, pressure points, every finish and backup.")
                     : (plus.trialText != nil ? "A weekly plan, pressure points, the stat book and more. Try a week free." : "A weekly plan, pressure points, the stat book and more."))
                    .font(.body(12)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
                if let m = plus.message ?? pro.message, pro.paywall == nil { Text(m).font(.body(11.5, .semibold)).foregroundStyle(Gold.pale) }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 8) {
                Button { pro.ask(.plus) } label: {
                    Text(plus.active ? "OPEN" : "SEE").font(.body(12, .bold)).tracking(1.5).foregroundStyle(Gold.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8).background(Capsule().fill(Gold.foil))
                }
                .buttonStyle(PressStyle())
                .opacity(plus.active ? 0 : 1).disabled(plus.active)
                if !plus.active {
                    Button { Task { await plus.restore(); await pro.restore() } } label: {
                        Text("Restore").font(.body(11, .semibold)).foregroundStyle(Gold.muted).underline()
                    }
                }
            }
        }
        .card(padding: 14)
    }
}
