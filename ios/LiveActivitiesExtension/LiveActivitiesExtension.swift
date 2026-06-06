import ActivityKit
import SwiftUI
import WidgetKit

private extension String {
  var compactLanguageLabel: String {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return "AI"
    }
    return String(trimmed.prefix(2))
  }
}

@available(iOSApplicationExtension 16.1, *)
struct TranslationLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TranslationActivityAttributes.self) { context in
      LockScreenTranslationView(context: context)
        .activityBackgroundTint(Color.black.opacity(0.72))
        .activitySystemActionForegroundColor(.cyan)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.sourceLanguage)
              .font(.caption2)
              .foregroundStyle(.secondary)
            Text("原声")
              .font(.caption.bold())
          }
        }

        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 2) {
            Text(context.attributes.targetLanguage)
              .font(.caption2)
              .foregroundStyle(.secondary)
            Text("译文")
              .font(.caption.bold())
          }
        }

        DynamicIslandExpandedRegion(.bottom) {
          Text(displayText(context.state))
            .font(.footnote.weight(.semibold))
            .lineLimit(2)
            .multilineTextAlignment(.center)
        }
      } compactLeading: {
        Image(systemName: "captions.bubble.fill")
          .foregroundStyle(.cyan)
      } compactTrailing: {
        Text(context.attributes.targetLanguage.compactLanguageLabel)
          .font(.caption2.weight(.black))
      } minimal: {
        Image(systemName: "waveform")
          .foregroundStyle(.cyan)
      }
      .keylineTint(.cyan)
    }
  }

  private func displayText(_ state: TranslationActivityAttributes.ContentState) -> String {
    if !state.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return state.translation
    }
    if !state.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return state.transcript
    }
    return state.status
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct LockScreenTranslationView: View {
  let context: ActivityViewContext<TranslationActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("声译 AI", systemImage: "captions.bubble.fill")
          .font(.headline.weight(.bold))
        Spacer()
        Text("\(context.attributes.sourceLanguage) → \(context.attributes.targetLanguage)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }

      Text(primaryText)
        .font(.title3.weight(.heavy))
        .lineLimit(2)

      if !context.state.transcript.isEmpty && context.state.translation != context.state.transcript {
        Text(context.state.transcript)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 4)
  }

  private var primaryText: String {
    if !context.state.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return context.state.translation
    }
    if !context.state.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return context.state.transcript
    }
    return context.state.status
  }
}

@main
@available(iOSApplicationExtension 16.1, *)
struct TranslationLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    TranslationLiveActivityWidget()
  }
}
