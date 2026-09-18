import SwiftUI

struct GearView: View {
    @Environment(Ledger.self) private var ledger
    @State private var editing: Racquet?

    var body: some View {
        Page {
            HStack(alignment: .bottom) {
                PageHeader(eyebrow: "Racquets & strings", title: "Gear")
                Spacer()
                Button {
                    editing = Racquet(name: "", mains: "", crosses: "", mainTension: 52, crossTension: 50, strung: .now)
                } label: {
                    Image(systemName: "plus").font(.body(18, .semibold)).foregroundStyle(Gold.ink)
                        .frame(width: 48, height: 48).background(Circle().fill(Gold.foil))
                }
                .buttonStyle(PressStyle())
            }
            if ledger.racquets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tennis.racket").font(.system(size: 38)).foil()
                    Text("Add your racquet").font(.display(20)).foregroundStyle(Gold.ivory)
                    Text("Track string, tension and hours played. Practice time is added to your first racquet automatically.")
                        .font(.body(14)).foregroundStyle(Gold.muted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).card(padding: 26)
            }
            ForEach(ledger.racquets) { r in
                Button { editing = r } label: { RacquetCard(racquet: r) }.buttonStyle(PressStyle())
            }
            if ledger.racquets.count > 1 {
                Text("Your first racquet is the one in use. Long-press another to make it your main.")
                    .font(.body(12)).foregroundStyle(Gold.muted).padding(.horizontal, 6)
            }
        }
        .sheet(item: $editing) { r in RacquetEditor(racquet: r).presentationBackground(Gold.ink) }
    }
}

struct RacquetCard: View {
    @Environment(Ledger.self) private var ledger
    let racquet: Racquet

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if ledger.racquets.first?.id == racquet.id { Eyebrow("In use") }
                    Text(racquet.name).font(.display(22, .medium)).foregroundStyle(Gold.ivory)
                    Text(racquet.mains == racquet.crosses ? racquet.mains : "\(racquet.mains) / \(racquet.crosses)")
                        .font(.body(13)).foregroundStyle(Gold.muted)
                }
                Spacer()
                ZStack {
                    FoilRing(progress: racquet.freshness, width: 6).frame(width: 64, height: 64)
                    VStack(spacing: -2) {
                        Text("\(Int(racquet.freshness * 100))").font(.figure(18)).foil()
                        Text("fresh").font(.body(8.5, .semibold)).foregroundStyle(Gold.muted)
                    }
                }
            }
            HStack(spacing: 0) {
                cell("\(racquet.mainTension)/\(racquet.crossTension)", "lbs")
                cell(String(format: "%.1f", racquet.hours), "hours")
                cell(racquet.strung.shortDay, "strung")
                cell("\(Int(Date.now.timeIntervalSince(racquet.strung) / 86400))", "days")
            }
            if !racquet.history.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("String log")
                    ForEach(racquet.history.prefix(4)) { h in
                        HStack {
                            Text(h.date.shortDay).font(.figure(13)).foregroundStyle(Gold.pale).frame(width: 54, alignment: .leading)
                            Text(h.setup).font(.body(13)).foregroundStyle(Gold.ivory.opacity(0.85))
                            Spacer()
                            if h.hours > 0 { Text(String(format: "%.0f h", h.hours)).font(.body(12)).foregroundStyle(Gold.muted) }
                        }
                    }
                }
            }
        }
        .card()
        .contextMenu {
            Button("Make main racquet") {
                if let i = ledger.racquets.firstIndex(where: { $0.id == racquet.id }) {
                    let r = ledger.racquets.remove(at: i); ledger.racquets.insert(r, at: 0)
                }
            }
        }
    }

    private func cell(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.figure(16)).foregroundStyle(Gold.ivory).lineLimit(1).minimumScaleFactor(0.7)
            Text(l.uppercased()).font(.body(9, .bold)).tracking(1.1).foregroundStyle(Gold.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RacquetEditor: View {
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    @State var racquet: Racquet

    private var isNew: Bool { !ledger.racquets.contains { $0.id == racquet.id } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SheetHeader(eyebrow: "Racquet", title: racquet.name.isEmpty ? "New racquet" : racquet.name) { dismiss() }
                    .padding(.horizontal, -20).padding(.top, 20)
                LedgerField(label: "Racquet", text: $racquet.name, prompt: "Pure Aero 98")
                HStack(spacing: 10) {
                    LedgerField(label: "Mains", text: $racquet.mains, prompt: "RPM Blast 17")
                    LedgerField(label: "Crosses", text: $racquet.crosses, prompt: "Same")
                }
                VStack(spacing: 14) {
                    LedgerStepper(label: "Mains tension (lbs)", value: $racquet.mainTension, range: 30...70)
                    LedgerStepper(label: "Crosses tension (lbs)", value: $racquet.crossTension, range: 30...70)
                    DatePicker("Strung on", selection: $racquet.strung, displayedComponents: .date)
                        .font(.body(15, .medium)).foregroundStyle(Gold.ivory)
                }
                .card(padding: 16)
                if !isNew {
                    GhostButton("Just restrung, same setup", icon: "arrow.triangle.2.circlepath") {
                        restring()
                    }
                }
                FoilButton("Save") {
                    guard !racquet.name.isEmpty else { return }
                    if racquet.crosses.isEmpty { racquet.crosses = racquet.mains }
                    if let i = ledger.racquets.firstIndex(where: { $0.id == racquet.id }) { ledger.racquets[i] = racquet }
                    else {
                        racquet.history = [Restring(date: racquet.strung, setup: setup, hours: 0)]
                        ledger.racquets.append(racquet)
                    }
                    Haptic.done(); dismiss()
                }
                if !isNew {
                    Button("Remove racquet", role: .destructive) { ledger.racquets.removeAll { $0.id == racquet.id }; dismiss() }
                        .font(.body(14, .semibold))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var setup: String { "\(racquet.mains) @ \(racquet.mainTension)/\(racquet.crossTension)" }

    private func restring() {
        if !racquet.history.isEmpty { racquet.history[0].hours = racquet.hours }
        racquet.history.insert(Restring(date: .now, setup: setup, hours: 0), at: 0)
        racquet.strung = .now
        racquet.hours = 0
        if let i = ledger.racquets.firstIndex(where: { $0.id == racquet.id }) { ledger.racquets[i] = racquet }
        Haptic.done(); dismiss()
    }
}
