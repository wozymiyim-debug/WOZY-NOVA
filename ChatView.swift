import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

@MainActor
final class ChatModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(text: "Merhaba Wozy! Ben WOZY AI. Sana nasıl yardımcı olabilirim? 🤖", isUser: false)
    ]
    @Published var input = ""
    @Published var isLoading = false
    @Published var apiKey = UserDefaults.standard.string(forKey: "wozy_gemini_key") ?? ""

    func saveKey() {
        UserDefaults.standard.set(apiKey, forKey: "wozy_gemini_key")
    }

    func send() async {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isLoading else { return }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            messages.append(ChatMessage(text: "Önce üstteki API anahtarı alanına Gemini API anahtarını gir.", isUser: false))
            return
        }
        input = ""
        messages.append(ChatMessage(text: prompt, isUser: true))
        isLoading = true
        defer { isLoading = false }

        do {
            let answer = try await GeminiClient.generate(prompt: prompt, apiKey: apiKey)
            messages.append(ChatMessage(text: answer, isUser: false))
        } catch {
            messages.append(ChatMessage(text: "Bağlantı hatası: \(error.localizedDescription)", isUser: false))
        }
    }
}

enum GeminiClient {
    static func generate(prompt: String, apiKey: String) async throws -> String {
        guard let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(encodedKey)") else {
            throw URLError(.badURL)
        }

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": "Sen WOZY AI adında akıllı bir asistansın. Türkçe konuş. Samimi, zeki ve yardımsever ol. Kullanıcının adı Wozy. Soruları doğru ve anlaşılır cevapla."]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "Bilinmeyen API hatası"
            throw NSError(domain: "GeminiAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: detail])
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let text = parts?.compactMap { $0["text"] as? String }.joined(separator: "\n")
        guard let result = text, !result.isEmpty else { throw URLError(.cannotParseResponse) }
        return result
    }
}

struct ChatView: View {
    @StateObject private var model = ChatModel()
    @State private var showKey = false

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.035, blue: 0.07).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                HStack(spacing: 8) {
                    Group {
                        if showKey { TextField("Gemini API anahtarın", text: $model.apiKey) }
                        else { SecureField("Gemini API anahtarın", text: $model.apiKey) }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    Button(showKey ? "Gizle" : "Göster") { showKey.toggle() }
                        .font(.caption.bold()).foregroundColor(.purple)
                }
                .padding(12)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.top, 10)
                .onChange(of: model.apiKey) { _ in model.saveKey() }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(model.messages) { message in
                                HStack {
                                    if message.isUser { Spacer(minLength: 45) }
                                    Text(message.text)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                        .padding(13)
                                        .background(message.isUser ? Color.purple : Color.white.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 17))
                                    if !message.isUser { Spacer(minLength: 45) }
                                }
                                .id(message.id)
                            }
                            if model.isLoading {
                                HStack { ProgressView().tint(.purple); Text("WOZY AI düşünüyor…").foregroundColor(.gray); Spacer() }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: model.messages.count) { _ in
                        if let last = model.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
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
                            .font(.bold(18))
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
                RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "sparkles").font(.title2.bold()).foregroundColor(.white)
            }
            .frame(width: 45, height: 45)
            VStack(alignment: .leading, spacing: 2) {
                Text("WOZY AI").font(.title2.bold()).foregroundColor(.white)
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
