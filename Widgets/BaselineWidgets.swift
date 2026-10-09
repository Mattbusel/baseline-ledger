import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BaselineWidgets: WidgetBundle {
    var body: some Widget {
        RecordWidget()
        FormWidget()
        MatchLiveActivity()
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

/// Free: the record on the Home Screen.
struct RecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "record", provider: GlanceProvider()) { e in
            RecordGlanceView(g: e.g).containerBackground(for: .widget) { LacquerBackground() }
        }
        .configurationDisplayName("Record")
        .description("Your match record, win streak and this week's hitting.")
        .supportedFamilies([.systemSmall])
    }
}

/// Pro: form over the last ten matches.
struct FormWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "form", provider: GlanceProvider()) { e in
            Group { if e.g.unlocked { FormGlanceView(g: e.g) } else { LockedGlanceView() } }
                .containerBackground(for: .widget) { LacquerBackground() }
        }
        .configurationDisplayName("Form")
        .description("Your last ten results, first serve, break points and string life.")
        .supportedFamilies([.systemMedium])
    }
}

/// A match being scored, on the Lock Screen and in the Dynamic Island.
struct MatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivity.self) { ctx in
            MatchLiveView(opponent: ctx.attributes.opponent, s: ctx.state)
                .activityBackgroundTint(Gold.ink)
                .activitySystemActionForegroundColor(Gold.leaf)
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
                    Text((ctx.attributes.opponent.isEmpty ? "Live match" : "vs \(ctx.attributes.opponent)") + (ctx.state.status.isEmpty ? "" : " · \(ctx.state.status)"))
                        .font(.body(12)).foregroundStyle(Gold.muted).lineLimit(1)
                }
            } compactLeading: {
                Text("\(ctx.state.me.last ?? 0)-\(ctx.state.them.last ?? 0)").font(.figure(13)).foregroundStyle(Gold.ivory)
            } compactTrailing: {
                Text("\(ctx.state.pointMe.isEmpty ? "–" : ctx.state.pointMe)·\(ctx.state.pointThem.isEmpty ? "–" : ctx.state.pointThem)").font(.figure(13)).foregroundStyle(Gold.leaf)
            } minimal: {
                Image(systemName: "tennisball.fill").foregroundStyle(Gold.leaf)
            }
        }
    }
}
