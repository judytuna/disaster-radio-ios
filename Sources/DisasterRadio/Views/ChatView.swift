import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText = ""
    @State private var showConnection = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if appState.connectionState != .connected {
                    disconnectedBanner
                }

                messageList

                inputBar
            }
            .navigationTitle("disaster.radio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showConnection = true
                    } label: {
                        Image(systemName: connectionIcon)
                            .foregroundStyle(connectionColor)
                    }
                }
            }
            .sheet(isPresented: $showConnection) {
                ConnectionView()
            }
        }
    }

    // MARK: - Subviews

    private var disconnectedBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Not connected — tap \(Image(systemName: connectionIcon)) to connect")
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.yellow.opacity(0.15))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(appState.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onChange(of: appState.messages.count) { _ in
                if let last = appState.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(
                appState.hasJoined ? "Message…" : "Enter your name or alias",
                text: $inputText
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit(sendMessage)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                      || appState.connectionState != .connected)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        appState.send(text)
        inputText = ""
    }

    // MARK: - Helpers

    private var connectionIcon: String {
        switch appState.connectionMode {
        case .ble: return "bluetooth"
        case .wifi: return "wifi"
        }
    }

    private var connectionColor: Color {
        appState.connectionState == .connected ? .blue : .gray
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.kind == .`self` { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(bubbleColor)
                .foregroundStyle(textColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .font(message.kind == .status ? .caption : .body)
            if message.kind == .remote { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: message.kind == .`self` ? .trailing : .leading)
    }

    private var bubbleColor: Color {
        switch message.kind {
        case .`self`: return .blue
        case .remote: return Color(.secondarySystemBackground)
        case .status: return .clear
        }
    }

    private var textColor: Color {
        switch message.kind {
        case .`self`: return .white
        case .remote: return .primary
        case .status: return .secondary
        }
    }
}
