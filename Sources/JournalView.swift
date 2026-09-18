import SwiftUI

struct JournalView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @State private var query = ""
    @State private var filter: Stroke? = nil

    private var entries: [PracticeSession] {
        ledger.sessions.filter { s in
            let q = query.lowercased()
            let hitsQuery = q.isEmpty || [s.focus, s.place, s.partner, s.cue, s.clicked, s.workOn, s.journal].contains { $0.lowercased().contains(q) }
            let hitsKind = filter == nil || s.blocks.contains { $0.stroke == filter }
            return hitsQuery && hitsKind
        }
    }

    var body: some View {
        Page {
            PageHeader(eyebrow: "\(ledger.sessions.count) sessions · \(ledger.sessions.reduce(0) { $0 + $1.minutes } / 60) hours", title: "Journal")
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Gold.muted)
                TextField("", text: $query, prompt: Text("Search cues, partners, places").foregroundStyle(Gold.faint))
                    .foregroundStyle(Gold.ivory).font(.body(15))
            }
            .padding(.horizontal, 16).frame(height: 48)
            .background(Capsule().fill(Gold.lacquer))
            .overlay(Capsule().strokeBorder(Gold.hairline, lineWidth: 0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", filter == nil) { filter = nil }
                    ForEach(Stroke.allCases) { k in chip(k.rawValue, filter == k) { filter = k } }
                }
                .padding(.horizontal, 18)
            }
            .padding(.horizontal, -18)

            if entries.isEmpty {
                Text(ledger.sessions.isEmpty ? "Finish a practice session and your journal starts here." : "Nothing matches.")
                    .font(.display(17)).foregroundStyle(Gold.muted).frame(maxWidth: .infinity).padding(.top, 40)
            }

            ForEach(groupedByMonth, id: \.0) { month, list in
                Eyebrow(month).padding(.leading, 4).padding(.top, 6)
                ForEach(list) { s in entry(s) }
            }
        }
    }

    private var groupedByMonth: [(String, [PracticeSession])] {
        var out: [(String, [PracticeSession])] = []
        for s in entries {
            let m = s.date.formatted(.dateTime.month(.wide).year())
            if out.last?.0 == m { out[out.count - 1].1.append(s) } else { out.append((m, [s])) }
        }
        return out
    }

    private func chip(_ t: String, _ on: Bool, _ act: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); withAnimation(.snappy) { act() } } label: {
            Text(t).font(.body(13, on ? .semibold : .medium))
                .foregroundStyle(on ? AnyShapeStyle(Gold.ink) : AnyShapeStyle(Gold.ivory.opacity(0.75)))
                .padding(.horizontal, 14).frame(height: 34)
                .background(Capsule().fill(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi)))
        }
        .buttonStyle(PressStyle())
    }

    private func entry(_ s: PracticeSession) -> some View {
        Button { router.viewing = s } label: {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 2) {
                    Text(s.date.formatted(.dateTime.day())).font(.figure(28, .light)).foil()
                    Text(s.date.formatted(.dateTime.weekday(.abbreviated)).uppercased()).font(.body(10, .bold)).tracking(1.2).foregroundStyle(Gold.muted)
                }
                .frame(width: 44)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(s.focus.isEmpty ? "Practice" : s.focus).font(.display(18, .medium)).foregroundStyle(Gold.ivory).lineLimit(1)
                        Spacer()
                        DiamondRating(value: .constant(s.rating), size: 9).allowsHitTesting(false)
                    }
                    if !s.cue.isEmpty {
                        Text("“\(s.cue)”").font(.display(15).italic()).foregroundStyle(Gold.pale.opacity(0.9)).lineLimit(2)
                    }
                    Text(s.journal.isEmpty ? s.clicked : s.journal).font(.body(13.5)).foregroundStyle(Gold.muted).lineLimit(3)
                    HStack(spacing: 12) {
                        Label("\(s.minutes)m", systemImage: "clock")
                        Label("\(s.balls)", systemImage: "tennisball")
                        HStack(spacing: 4) { ForEach(uniqueKinds(s), id: \.self) { k in Image(systemName: k.icon) } }
                    }
                    .font(.body(11.5, .medium)).foregroundStyle(Gold.leaf.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 16, radius: 22)
        }
        .buttonStyle(PressStyle())
    }

    private func uniqueKinds(_ s: PracticeSession) -> [Stroke] {
        var seen: [Stroke] = []
        for b in s.blocks where !seen.contains(b.stroke) { seen.append(b.stroke) }
        return seen
    }
}
