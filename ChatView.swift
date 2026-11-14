import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    var isError = false
}

@MainActor
final class ChatModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(text: "Merhaba! Ben WOZY. Sana nasıl yardımcı olabilirim? 🤖", isUser: false)
    ]
    @Published var input = ""
    @Published var isLoading = false

    func send() async {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isLoading else { return }

        input = ""
        messages.append(ChatMessage(text: prompt, isUser: true))
        isLoading = true
        defer { isLoading = false }

        do {
            let conversation = messages
                .filter { !$0.isError }
                .suffix(20)
                .map { message in
                    [
                        "role": message.isUser ? "user" : "model",
                        "parts": [["text": message.text]]
                    ] as [String: Any]
                }

            let answer = try await NexoraClient.generate(contents: conversation)
            messages.append(ChatMessage(text: answer, isUser: false))
        } catch {
            messages.append(ChatMessage(
                text: "Bağlantı hatası: \(error.localizedDescription)",
                isUser: false,
                isError: true
            ))
        }
    }
}

enum NexoraClient {
    // WOZY Vercel API
    private static let endpoint = "https://wozy-wpzy1.vercel.app/api/chat"

    static func generate(contents: [[String: Any]]) async throws -> String {
        guard !endpoint.contains("YOUR-SUBDOMAIN"),
              let url = URL(string: endpoint) else {
            throw NSError(
                domain: "NEXORA",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "WOZY sunucusuna şu anda bağlanılamıyor."]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": contents
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard (200..<300).contains(http.statusCode) else {
            let detail = json?["error"] as? String ?? "Sunucu hatası (\(http.statusCode))."
            throw NSError(
                domain: "NEXORA",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: detail]
            )
        }

        guard let answer = json?["text"] as? String, !answer.isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        return answer
    }
}

struct ChatView: View {
    @StateObject private var model = ChatModel()

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.035, blue: 0.07).ignoresSafeArea()
            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(model.messages) { message in
                                HStack {
                                    if message.isUser { Spacer(minLength: 45) }

                                    Text(message.text)
                                        .font(.system(size: 15))
                                        .foregroundColor(message.isError ? .orange : .white)
                                        .padding(13)
                                        .background(message.isUser ? Color.purple : Color.white.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 17))

                                    if !message.isUser { Spacer(minLength: 45) }
                                }
                                .id(message.id)
                            }

                            if model.isLoading {
                                HStack {
                                    ProgressView().tint(.purple)
                                    Text("WOZY düşünüyor…").foregroundColor(.gray)
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: model.messages.count) { _ in
                        if let last = model.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                HStack(spacing: 10) {
                    TextField("Mesajını yaz…", text: $model.input, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(12)
                        .background(Color.white.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .foregroundColor(.white)

                    Button {
                        Task { await model.send() }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 46, height: 46)
                            .background(Color.purple)
                            .clipShape(Circle())
                    }
                    .disabled(model.isLoading)
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "sparkles")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            .frame(width: 45, height: 45)

            VStack(alignment: .leading, spacing: 2) {
                Text("WOZY").font(.title2.bold()).foregroundColor(.white)
                Text("Akıllı asistanın").font(.caption).foregroundColor(.gray)
            }

            Spacer()
            Circle().fill(Color.green).frame(width: 8, height: 8)
            Text("Çevrimiçi").font(.caption).foregroundColor(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.25))
    }
}
