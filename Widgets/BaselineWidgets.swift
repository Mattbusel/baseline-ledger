import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct BaselineWidgets: WidgetBundle {
    var body: some Widget {
        RecordWidget()
        FormWidget()
        LockRecordWidget()
        MatchLiveActivity()
        if #available(iOSApplicationExtension 18.0, *) {
            ScoreMatchControl()
            StartHittingControl()
        }
    }
}

struct GlanceEntry: TimelineEntry {
    let date: Date
    let g: Glance
}

struct GlanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlanceEntry { GlanceEntry(date: .now, g: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> Void) {
        Court.reload()
        let g = Glance.load()
        completion(GlanceEntry(date: .now, g: context.isPreview && g.won + g.lost == 0 ? .sample : g))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GlanceEntry>) -> Void) {
        Court.reload()
        // "This week" rolls over, so look again at midnight.
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [GlanceEntry(date: .now, g: Glance.load())], policy: .after(midnight)))
    }
}

/// Free: the record on the Home Screen (and in StandBy).
struct RecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "record", provider: GlanceProvider()) { e in
            RecordGlanceView(g: e.g).containerBackground(for: .widget) { LacquerBackground() }
                .widgetURL(URL(string: "baselineledger://matches"))
        }
        .configurationDisplayName("Record")
        .description("Your match record, win streak and this week's hitting.")
        .supportedFamilies([.systemSmall])
    }
}

/// Free: the record and the week on the Lock Screen.
struct LockRecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "lock-record", provider: GlanceProvider()) { e in
            LockRecordView(g: e.g).containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "baselineledger://score"))
        }
        .configurationDisplayName("Record and court time")
        .description("Your record and this week's court time on the Lock Screen. Tap to score a match.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockRecordView: View {
    @Environment(\.widgetFamily) private var family
    let g: Glance
    var body: some View {
        switch family {
        case .accessoryCircular: WeekRingAccessory(g: g)
        case .accessoryInline: Text("\(g.won)–\(g.lost) · \(g.weekMinutes) min this week")
        default: RecordAccessory(g: g)
        }
    }
}

/// Pro: form over the last ten matches.
struct FormWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "form", provider: GlanceProvider()) { e in
            Group { if e.g.unlocked { FormGlanceView(g: e.g) } else { LockedGlanceView() } }
                .containerBackground(for: .widget) { LacquerBackground() }
                .widgetURL(URL(string: "baselineledger://stats"))
        }
        .configurationDisplayName("Form")
        .description("Your last ten results, first serve, break points and string life.")
        .supportedFamilies([.systemMedium])
    }
}

/// A match being scored, on the Lock Screen and in the Dynamic Island, with buttons to score from there.
struct MatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivity.self) { ctx in
            MatchLiveView(opponent: ctx.attributes.opponent, s: ctx.state)
                .activityBackgroundTint(Gold.ink)
                .activitySystemActionForegroundColor(Gold.leaf)
                .widgetURL(URL(string: "baselineledger://score"))
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You  " + ctx.state.me.map(String.init).joined(separator: " ")).font(.figure(15)).foregroundStyle(Gold.ivory)
                        Text("Them " + ctx.state.them.map(String.init).joined(separator: " ")).font(.figure(15)).foregroundStyle(Gold.muted)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ctx.state.pointMe.isEmpty ? "–" : ctx.state.pointMe).font(.figure(17)).foregroundStyle(Gold.leaf)
                        Text(ctx.state.pointThem.isEmpty ? "–" : ctx.state.pointThem).font(.figure(17)).foregroundStyle(Gold.muted)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text((ctx.attributes.opponent.isEmpty ? "Live match" : "vs \(ctx.attributes.opponent)") + (ctx.state.status.isEmpty ? (ctx.state.secondServe ? " · 2nd serve" : "") : " · \(ctx.state.status)"))
                            .font(.body(12)).foregroundStyle(Gold.muted).lineLimit(1)
                        if !ctx.state.over {
                            HStack(spacing: 8) {
                                Button(intent: ScorePointIntent("won")) { islandPill("Won", strong: true) }
                                Button(intent: ScorePointIntent("lost")) { islandPill("Lost", strong: false) }
                                Button(intent: ScorePointIntent("fault")) { islandPill(ctx.state.secondServe ? "Double" : "Fault", strong: false) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } compactLeading: {
                Text("\(ctx.state.me.last ?? 0)-\(ctx.state.them.last ?? 0)").font(.figure(13)).foregroundStyle(Gold.ivory)
            } compactTrailing: {
                Text("\(ctx.state.pointMe.isEmpty ? "–" : ctx.state.pointMe)·\(ctx.state.pointThem.isEmpty ? "–" : ctx.state.pointThem)").font(.figure(13)).foregroundStyle(Gold.leaf)
            } minimal: {
                Image(systemName: "tennisball.fill").foregroundStyle(Gold.leaf)
            }
            .widgetURL(URL(string: "baselineledger://score"))
        }
    }

    private func islandPill(_ t: String, strong: Bool) -> some View {
        Text(t).font(.body(13, .semibold))
            .foregroundStyle(strong ? Gold.ink : Gold.ivory)
            .frame(maxWidth: .infinity).frame(height: 32)
            .background(Capsule().fill(strong ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi)))
    }
}

// MARK: - Control Center, Lock Screen controls and the Action button (iOS 18)

@available(iOSApplicationExtension 18.0, *)
struct ScoreMatchControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mattbusel.baselineledger.score") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "baselineledger://score")!)) {
                Label("Score a Match", systemImage: "tennisball.fill")
            }
        }
        .displayName("Score a Match")
        .description("Opens Baseline Ledger's live scorer.")
    }
}

@available(iOSApplicationExtension 18.0, *)
struct StartHittingControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mattbusel.baselineledger.hit") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "baselineledger://hit")!)) {
                Label("Start Hitting", systemImage: "figure.tennis")
            }
        }
        .displayName("Start Hitting")
        .description("Starts a practice session in Baseline Ledger.")
    }
}
