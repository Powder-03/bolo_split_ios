//
//  BoloSplitWidget.swift
//  BoloSplitWidget
//
//  Home Screen & Lock Screen Quick-Bolo Widget launching bolosplit://voice.
//

import SwiftUI
import WidgetKit

struct QuickBoloEntry: TimelineEntry {
    let date: Date
}

struct QuickBoloProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickBoloEntry {
        QuickBoloEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickBoloEntry) -> Void) {
        completion(QuickBoloEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickBoloEntry>) -> Void) {
        let entry = QuickBoloEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct QuickBoloWidgetView: View {
    @Environment(\.widgetFamily) private var family

    private let voiceURL = URL(string: "bolosplit://voice")!

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.title2.weight(.semibold))
            }
            .widgetURL(voiceURL)
            .containerBackground(.clear, for: .widget)

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("BoloSplit")
                        .font(.headline)
                    Text("Tap to speak expense")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .widgetURL(voiceURL)
            .containerBackground(.clear, for: .widget)

        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.teal, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "mic.fill")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                        }

                    Spacer()

                    Image(systemName: "waveform")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.teal)
                }

                Spacer()

                Text("Quick Bolo")
                    .font(.headline.weight(.bold))

                Text("Tap to speak an expense in Hinglish or English")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(2)
            .widgetURL(voiceURL)
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color.teal.opacity(0.16),
                        Color(.systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

struct QuickBoloWidget: Widget {
    let kind = "QuickBoloWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickBoloProvider()) { _ in
            QuickBoloWidgetView()
        }
        .configurationDisplayName("Quick Bolo")
        .description("Launch BoloSplit straight into voice listening from your Home or Lock Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct BoloSplitWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickBoloWidget()
    }
}
