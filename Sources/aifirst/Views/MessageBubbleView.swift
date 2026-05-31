import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    let maxBubbleWidth: CGFloat
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var loc: LocalizationService

    init(message: ChatMessage, maxBubbleWidth: CGFloat = 360) {
        self.message = message
        self.maxBubbleWidth = maxBubbleWidth
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(verbatim: message.role == .user ? loc.tr("chat_you") : loc.tr("chat_ai"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(message.content)
                    .textSelection(.enabled)
                    .font(chatFont(size: CGFloat(settings.chatFontSize)))
                    .padding(12)
                    .background(message.role == .user ? Color.accentColor.opacity(0.12) : Color(.textBackgroundColor))
                    .cornerRadius(12)
                    .frame(maxWidth: maxBubbleWidth, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                Image(systemName: "person.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
        }
    }

    private func chatFont(size: CGFloat) -> Font {
        switch settings.chatFontFamily {
        case "rounded":    return .system(size: size, design: .rounded)
        case "serif":      return .system(size: size, design: .serif)
        case "monospace":  return .system(size: size, design: .monospaced)
        default:           return .system(size: size)
        }
    }
}
