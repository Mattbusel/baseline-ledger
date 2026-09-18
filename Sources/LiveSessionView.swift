import SwiftUI

/// The on-court screen. Pick the stroke and pattern, then tap each ball's outcome.
/// Serves are logged by tapping where they landed in the service box.
struct LiveSessionView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State var session: PracticeSession
    @State private var stroke: Stroke = .forehand
    @State private var pattern: Pattern = .crossCourt
    @State private var side: Side = .deuce
    @State private var serveNumber: ServeNumber = .first
    @State private var started = Date.now
    @State private var history: [[StrokeBlock]] = []
    @State private var rally = 0
    @State private var confirmQuit = false

    init(session: PracticeSession) {
        _session = State(initialValue: session)
        if let b = session.blocks.last {
            _stroke = State(initialValue: b.stroke); _pattern = State(initialValue: b.pattern)
            _side = State(initialValue: b.side); _serveNumber = State(initialValue: b.serveNumber)
        }
        _started = State(initialValue: Date.now.addingTimeInterval(-Double(session.minutes) * 60))
    }

    var body: some View {
        ZStack {
            LacquerBackground()
            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        ChipRow(options: Stroke.allCases, selection: $stroke) { $0.rawValue }
                            .padding(.horizontal, -20)
                        if stroke.isServe { servePad } else { rallyPad }
                        blocksStrip
                    }
                    .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 120)
                }
            }
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button { undo() } label: {
                        Image(systemName: "arrow.uturn.backward").font(.body(17, .semibold))
                            .foregroundStyle(history.isEmpty ? Gold.faint : Gold.pale)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Gold.lacquerHi))
                            .overlay(Circle().strokeBorder(Gold.hairline, lineWidth: 0.8))
                    }
                    .disabled(history.isEmpty)
                    FoilButton("Finish & journal", icon: "checkmark") { finish() }
                }
                .padding(.horizontal, 20).padding(.bottom, 8)
                .background(LinearGradient(colors: [.clear, Gold.ink.opacity(0.95)], startPoint: .top, endPoint: .center).ignoresSafeArea().padding(.top, -30))
            }
        }
        .confirmationDialog("End this session?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Discard session", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                if session.balls == 0 { dismiss() } else { confirmQuit = true }
            } label: {
                Image(systemName: "xmark").font(.body(13, .bold)).foregroundStyle(Gold.ivory.opacity(0.7))
                    .frame(width: 36, height: 36).background(Circle().fill(Gold.lacquerHi))
            }
            Spacer()
            VStack(spacing: 2) {
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    let s = Int(tl.date.timeIntervalSince(started))
                    Text(String(format: "%d:%02d", s / 60, s % 60)).font(.figure(24, .light)).foil().monospacedDigit()
                }
                Text("\(session.balls) balls · \(session.blocks.count) \(session.blocks.count == 1 ? "block" : "blocks")")
                    .font(.body(11.5, .medium)).foregroundStyle(Gold.muted)
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(Gold.bad).frame(width: 7, height: 7)
                Text("LIVE").font(.body(10.5, .bold)).tracking(1.5).foregroundStyle(Gold.ivory.opacity(0.8))
            }
            .frame(width: 60, height: 30).background(Capsule().fill(Gold.lacquerHi))
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    // MARK: recording

    private func matches(_ b: StrokeBlock) -> Bool {
        guard b.stroke == stroke else { return false }
        return stroke.isServe ? (b.side == side && b.serveNumber == serveNumber) : b.pattern == pattern
    }

    private var current: StrokeBlock {
        if let last = session.blocks.last, matches(last) { return last }
        return StrokeBlock(stroke: stroke, pattern: pattern, side: side, serveNumber: serveNumber)
    }

    private func record(_ change: (inout StrokeBlock) -> Void) {
        history.append(session.blocks)
        if history.count > 200 { history.removeFirst() }
        if let last = session.blocks.last, matches(last) {
            change(&session.blocks[session.blocks.count - 1])
        } else {
            var b = StrokeBlock(stroke: stroke, pattern: pattern, side: side, serveNumber: serveNumber)
            change(&b)
            withAnimation(.snappy) { session.blocks.append(b) }
        }
    }

    private func undo() {
        guard let prev = history.popLast() else { return }
        Haptic.thud()
        withAnimation(.snappy) { session.blocks = prev }
    }

    // MARK: rally strokes

    private var rallyPad: some View {
        let b = current
        return VStack(alignment: .leading, spacing: 18) {
            if stroke != .points {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Pattern")
                    ChipRow(options: Pattern.allCases, selection: $pattern) { $0.rawValue }.padding(.horizontal, -20)
                }
            }
            HStack(spacing: 20) {
                ZStack {
                    FoilRing(progress: b.balls == 0 ? 0 : b.inRate / 100, width: 10)
                    VStack(spacing: 0) {
                        Text(b.balls == 0 ? "–" : "\(Int(b.inRate.rounded()))").font(.figure(34, .light)).foil()
                        Text("in play %").font(.body(10.5, .medium)).foregroundStyle(Gold.muted)
                    }
                }
                .frame(width: 118, height: 118)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(b.made + b.winners) of \(b.balls)").font(.display(26)).foregroundStyle(Gold.ivory)
                    Text(stroke == .points ? "points in play" : "\(stroke.rawValue.lowercased()), \(pattern.rawValue.lowercased())")
                        .font(.body(14)).foregroundStyle(Gold.muted)
                    if b.winners > 0 { Text("\(b.winners) winners").font(.body(12.5, .semibold)).foregroundStyle(Gold.pale) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 18)

            HStack(spacing: 10) {
                TallyButton(label: "In", sub: "to target", count: b.made, tone: Gold.good, tall: 110) { record { $0.made += 1 } }
                TallyButton(label: "Winner", sub: "unreturnable", count: b.winners, tone: Gold.pale, tall: 110) { record { $0.winners += 1 } }
            }
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Error")
                HStack(spacing: 8) {
                    ForEach(StrokeError.allCases, id: \.self) { e in
                        TallyButton(label: e.rawValue, count: b.errors[e] ?? 0, tone: Gold.bad, tall: 70) {
                            record { $0.errors[e, default: 0] += 1 }
                        }
                    }
                }
            }
            if stroke == .forehand || stroke == .backhand || stroke == .points { rallyCounter(b) }
        }
    }

    private func rallyCounter(_ b: StrokeBlock) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Rally counter")
                Spacer()
                if let best = b.rallies.max() { Text("best \(best)").font(.body(12, .semibold)).foil() }
            }
            HStack(spacing: 14) {
                Button {
                    Haptic.tap(); withAnimation(.snappy) { rally += 1 }
                } label: {
                    VStack(spacing: 0) {
                        Text("\(rally)").font(.figure(46, .light)).foil().contentTransition(.numericText())
                        Text("tap each shot").font(.body(11, .medium)).foregroundStyle(Gold.muted)
                    }
                    .frame(maxWidth: .infinity).frame(height: 104)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Gold.ink.opacity(0.55)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Gold.hairline, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
                Button {
                    guard rally > 0 else { return }
                    let n = rally
                    record { $0.rallies.append(n) }
                    Haptic.done()
                    withAnimation(.snappy) { rally = 0 }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "stop.fill").font(.body(18, .semibold))
                        Text("Rally over").font(.body(12.5, .semibold))
                    }
                    .foregroundStyle(Gold.ink)
                    .frame(width: 110, height: 104)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Gold.foil))
                }
                .buttonStyle(PressStyle())
            }
            if !b.rallies.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(b.rallies.enumerated()), id: \.offset) { _, r in
                            Text("\(r)").font(.figure(13)).foregroundStyle(r == b.rallies.max() ? Gold.ink : Gold.pale)
                                .padding(.horizontal, 10).frame(height: 26)
                                .background(Capsule().fill(r == b.rallies.max() ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.leaf.opacity(0.1))))
                        }
                    }
                }
            }
        }
        .card(padding: 16, radius: 22)
    }

    // MARK: serve

    private var servePad: some View {
        let b = current
        let ins = b.made + b.winners
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                segmented(Side.allCases, $side) { $0.rawValue }
                segmented(ServeNumber.allCases, $serveNumber) { $0.rawValue }
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow("Tap where it landed")
                    Spacer()
                    Text("\(pct(ins, b.balls))% in · \(b.winners) aces").font(.body(12, .semibold)).foil()
                }
                ServiceBox(side: side, counts: b.zones) { z in
                    record { $0.made += 1; $0.zones[z, default: 0] += 1 }
                }
                .frame(height: 230)
            }
            .card(padding: 16, radius: 24)

            TallyButton(label: "Ace / unreturned", sub: "also counts as in", count: b.winners, tone: Gold.pale, tall: 72) {
                record { $0.winners += 1 }
            }
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(serveNumber == .second ? "Fault · double fault" : "Fault")
                HStack(spacing: 8) {
                    ForEach([StrokeError.net, .long, .wide], id: \.self) { e in
                        TallyButton(label: e.rawValue, count: b.errors[e] ?? 0, tone: Gold.bad, tall: 70) {
                            record { $0.errors[e, default: 0] += 1 }
                        }
                    }
                }
            }
        }
    }

    private func segmented<T: Hashable>(_ opts: [T], _ sel: Binding<T>, label: @escaping (T) -> String) -> some View {
        HStack(spacing: 0) {
            ForEach(opts, id: \.self) { o in
                let on = sel.wrappedValue == o
                Button { Haptic.tap(); withAnimation(.snappy) { sel.wrappedValue = o } } label: {
                    Text(label(o)).font(.body(14, .semibold))
                        .foregroundStyle(on ? Gold.ink : Gold.ivory.opacity(0.7))
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(Capsule().fill(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Color.clear)).padding(3))
                }
                .buttonStyle(.plain)
            }
        }
        .background(Capsule().fill(Gold.lacquer))
        .overlay(Capsule().strokeBorder(Gold.hairline, lineWidth: 0.8))
    }

    @ViewBuilder private var blocksStrip: some View {
        if !session.blocks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("This session")
                ForEach(session.blocks.reversed()) { b in
                    HStack(spacing: 12) {
                        Image(systemName: b.stroke.icon).font(.body(14, .semibold)).foil()
                            .frame(width: 34, height: 34).background(Circle().fill(Gold.leaf.opacity(0.1)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.title).font(.body(14, .semibold)).foregroundStyle(Gold.ivory)
                            Text("\(b.balls) balls · \(Int(b.inRate.rounded()))% in · \(b.winners) \(b.stroke.isServe ? "aces" : "winners")")
                                .font(.body(12)).foregroundStyle(Gold.muted)
                        }
                        Spacer()
                        if b.id == session.blocks.last?.id && matches(b) {
                            Text("NOW").font(.body(9.5, .bold)).tracking(1.2).foregroundStyle(Gold.ink)
                                .padding(.horizontal, 8).frame(height: 20).background(Capsule().fill(Gold.foil))
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Gold.lacquer))
                }
            }
        }
    }

    private func finish() {
        session.minutes = max(1, Int(Date.now.timeIntervalSince(started) / 60))
        if session.date.timeIntervalSinceNow > -60 { session.date = started }
        let s = session
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { router.finishing = s }
    }
}

/// The service box seen from the server's side, split into wide / body / T.
/// On the deuce side the T is on the left; on the ad side it's on the right.
struct ServiceBox: View {
    let side: Side
    let counts: [Zone: Int]
    var onTap: ((Zone) -> Void)?
    @State private var flash: Zone?

    private var order: [Zone] { side == .deuce ? [.t, .body, .wide] : [.wide, .body, .t] }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let total = max(1, counts.values.reduce(0, +))
            ZStack(alignment: .topLeading) {
                // Court surface
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [Color(red: 0.13, green: 0.20, blue: 0.17), Color(red: 0.08, green: 0.12, blue: 0.10)], startPoint: .top, endPoint: .bottom))
                HStack(spacing: 0) {
                    ForEach(order, id: \.self) { z in
                        let n = counts[z] ?? 0
                        Button {
                            Haptic.tap(); onTap?(z)
                            flash = z
                            withAnimation(.easeOut(duration: 0.5)) { flash = nil }
                        } label: {
                            ZStack {
                                Rectangle().fill(Gold.leaf.opacity(flash == z ? 0.4 : 0.05 + 0.4 * Double(n) / Double(total)))
                                VStack(spacing: 2) {
                                    Text("\(n)").font(.figure(30, .light)).foregroundStyle(n > 0 ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.faint))
                                        .contentTransition(.numericText())
                                    Text(z.rawValue.uppercased()).font(.body(10.5, .bold)).tracking(1.4).foregroundStyle(Gold.ivory.opacity(0.7))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: w / 3)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                // Lines: box outline, zone guides, net at the top.
                Path { p in
                    p.addRect(CGRect(x: 1, y: 1, width: w - 2, height: h - 2))
                }
                .stroke(Gold.pale.opacity(0.9), lineWidth: 2)
                Path { p in
                    for i in 1...2 {
                        let x = w * CGFloat(i) / 3
                        p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h))
                    }
                }
                .stroke(Gold.pale.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                Rectangle().fill(LinearGradient(colors: [Gold.ivory.opacity(0.9), Gold.ivory.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                    .frame(height: 5)
                Text("NET").font(.body(9, .bold)).tracking(2).foregroundStyle(Gold.ink).padding(.horizontal, 6)
                    .background(Capsule().fill(Gold.ivory.opacity(0.9))).offset(x: w / 2 - 18, y: -6)
                // Centre service line runs along the T side.
                Rectangle().fill(Gold.pale.opacity(0.9)).frame(width: 3, height: h)
                    .offset(x: side == .deuce ? 0 : w - 3)
            }
        }
        .animation(.snappy, value: counts)
    }
}
