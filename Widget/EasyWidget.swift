import WidgetKit
import SwiftUI

struct EasyWidgetEntry: TimelineEntry {
    let date: Date
}

struct EasyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> EasyWidgetEntry {
        EasyWidgetEntry(date: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping (EasyWidgetEntry) -> Void) {
        completion(EasyWidgetEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<EasyWidgetEntry>) -> Void) {
        completion(Timeline(entries: [EasyWidgetEntry(date: Date())], policy: .never))
    }
}

struct EasyWidgetView: View {
    var entry: EasyWidgetEntry
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.2, green: 0.15, blue: 0.35), Color(red: 0.1, green: 0.1, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 8) {
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                Text("易创")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("AI 创作助手")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

@main
struct EasyWidget: Widget {
    let kind: String = "EasyWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EasyWidgetProvider()) { entry in
            EasyWidgetView(entry: entry)
        }
        .configurationDisplayName("易创")
        .description("AI 网文创作助手")
    }
}
