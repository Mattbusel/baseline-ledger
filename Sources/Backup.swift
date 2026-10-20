import Foundation
import SwiftUI

/// iCloud backup of the whole ledger (Plus), through the iCloud key-value store: compressed, one key,
/// no account or server of ours. Kept under Apple's 1 MB limit; a very large ledger is told to export.
enum Backup {
    private static var store: NSUbiquitousKeyValueStore { .default }
    private static let dataKey = "ledger.backup"
    private static let dateKey = "ledger.backup.date"
    private static let countKey = "ledger.backup.count"
    static let limit = 950_000

    enum Outcome: Equatable { case saved(Int), tooBig, failed }

    static var last: Date? {
        store.synchronize()
        return store.object(forKey: dateKey) as? Date
    }
    static var lastSummary: String? { store.string(forKey: countKey) }

    static func save(_ l: Ledger) -> Outcome {
        guard let raw = l.snapshotData(), let packed = try? (raw as NSData).compressed(using: .lzfse) as Data else { return .failed }
        guard packed.count < limit else { return .tooBig }
        store.set(packed, forKey: dataKey)
        store.set(Date.now, forKey: dateKey)
        store.set("\(l.matches.count) matches, \(l.sessions.count) sessions", forKey: countKey)
        store.synchronize()
        return .saved(packed.count)
    }

    static func restore(into l: Ledger) -> Bool {
        store.synchronize()
        guard let packed = store.data(forKey: dataKey),
              let raw = try? (packed as NSData).decompressed(using: .lzfse) as Data else { return false }
        return l.restore(snapshot: raw)
    }

    /// Once a day at most, when the app goes to the background, for subscribers.
    static func auto(_ l: Ledger) {
        if let d = last, d > .now.addingTimeInterval(-20 * 3600) { return }
        _ = save(l)
    }
}

struct BackupCard: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Pro.self) private var pro
    @State private var note: String?
    @State private var confirm = false
    @State private var last = Backup.last

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "icloud.fill").font(.body(17, .semibold)).foil()
                    .frame(width: 42, height: 42).background(Circle().fill(Gold.lacquerHi))
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud backup").font(.display(18, .medium)).foregroundStyle(Gold.ivory)
                    Text(pro.plusActive ? (last.map { "Last backed up \($0.formatted(.relative(presentation: .named)))" + (Backup.lastSummary.map { ", \($0)" } ?? "") } ?? "Not backed up yet. It happens by itself once a day.")
                                        : "The whole ledger, safe in your iCloud. With Plus.")
                        .font(.body(12)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if !pro.plusActive {
                    Button { pro.ask(.backup) } label: {
                        Image(systemName: "lock.fill").font(.body(15, .bold)).foil()
                            .frame(width: 44, height: 44).overlay(Circle().strokeBorder(Gold.hairline, lineWidth: 1))
                    }
                    .accessibilityLabel("iCloud backup comes with Plus")
                }
            }
            if pro.plusActive {
                HStack(spacing: 10) {
                    GhostButton("Back up now", icon: "arrow.up.circle") {
                        switch Backup.save(ledger) {
                        case .saved: note = "Backed up."; last = Backup.last; Haptic.done()
                        case .tooBig: note = "The ledger is too big for the iCloud backup. Export it as spreadsheets instead."
                        case .failed: note = "Could not back up. Check that iCloud is on for this app in Settings."
                        }
                    }
                    GhostButton("Restore", icon: "arrow.down.circle") { confirm = true }
                }
                if let note { Text(note).font(.body(12, .semibold)).foregroundStyle(Gold.pale) }
            }
        }
        .card(padding: 14)
        .confirmationDialog("Restore the backup?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Replace this ledger with the backup", role: .destructive) {
                note = Backup.restore(into: ledger) ? "Restored." : "No backup found in your iCloud yet."
            }
        } message: { Text("What is on this phone now is replaced by the copy in iCloud.") }
    }
}
