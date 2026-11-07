import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TriSpikeWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlayerLiveActivity()
    }
}

struct PlayerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlayerActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.sessionName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(context.state.stepName)
                        .font(.headline)
                    Spacer()
                    Text(timerInterval: context.state.stepStart...context.state.stepEnd, countsDown: true)
                        .font(.title2.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
                Text("Step \(context.state.stepIndex + 1) of \(context.state.stepCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.stepName).font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.stepStart...context.state.stepEnd, countsDown: true)
                        .monospacedDigit()
                }
            } compactLeading: {
                Text("\(context.state.stepIndex + 1)/\(context.state.stepCount)")
            } compactTrailing: {
                Text(timerInterval: context.state.stepStart...context.state.stepEnd, countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                Text("\(context.state.stepIndex + 1)")
            }
        }
    }
}
