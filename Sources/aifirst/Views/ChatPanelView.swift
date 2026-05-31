import SwiftUI

struct ChatPanelView: View {
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var loc: LocalizationService
    @State private var input = ""
    @State private var inputHeight: CGFloat = 80
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            resizableDivider
            inputArea
                .frame(height: inputHeight)
        }
        .frame(minWidth: 400, minHeight: 400)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ChatInputText"))) { note in
            if let text = note.userInfo?["text"] as? String, !text.isEmpty {
                input = text
                isFocused = true
            }
        }
    }

    private var resizableDivider: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 7)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeUpDown.push() }
                else { NSCursor.pop() }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = value.translation.height
                        inputHeight = max(44, min(320, inputHeight - delta))
                    }
            )
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(.separator)
                    .frame(height: 1)
                    .padding(.horizontal, 8)
            }
    }

    private var header: some View {
        HStack {
            Text(verbatim: loc.tr("chat_title"))
                .font(.headline)
            Spacer()
            if !aiService.messages.isEmpty {
                Button { aiService.clear() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help(loc.tr("chat_clear"))
            }
        }
        .padding()
    }

    private var messageList: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    if aiService.messages.isEmpty {
                        emptyState
                    } else {
                        let bubbleMax = max(geo.size.width - 60, 250)
                        LazyVStack(spacing: 12) {
                            ForEach(aiService.messages.filter { $0.role != .system }) { message in
                                MessageBubbleView(message: message, maxBubbleWidth: bubbleMax)
                                    .id(message.id)
                            }
                            if aiService.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(verbatim: loc.tr("chat_processing"))
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                }
                .onChange(of: aiService.messages.count) { _, _ in
                    if let last = aiService.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(verbatim: loc.tr("chat_empty"))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("", text: $input, prompt: Text(verbatim: loc.tr("chat_input_placeholder")), axis: .vertical)
                .font(.body)
                .lineLimit(1...10)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .padding(4)
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
            }
            .buttonStyle(.plain)
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || aiService.isLoading)
        }
        .padding()
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !aiService.isLoading else { return }
        input = ""
        Task { await aiService.send(text) }
    }
}
