import SwiftUI
import SwiftData
import Speech
import AVFoundation

@MainActor
private final class SpeechEntryService: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?
    private let recognizer = SFSpeechRecognizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() {
        if isRecording { stop(); return }
        Task {
            let speech = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard speech == .authorized else { errorMessage = "Speech recognition permission is required."; return }
            let microphone = await AVAudioApplication.requestRecordPermission()
            guard microphone else { errorMessage = "Microphone permission is required."; return }
            start()
        }
    }

    private func start() {
        stop()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        let node = engine.inputNode
        node.installTap(onBus: 0, bufferSize: 1024, format: node.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            engine.prepare(); try engine.start(); isRecording = true
            task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result { self?.transcript = result.bestTranscription.formattedString }
                    if error != nil || result?.isFinal == true { self?.stop() }
                }
            }
        } catch {
            errorMessage = error.localizedDescription; stop()
        }
    }

    func stop() {
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        request?.endAudio(); task?.cancel(); request = nil; task = nil; isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

struct QuickEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode = CurrencyCatalog.defaultCode
    @StateObject private var speech = SpeechEntryService()
    @State private var text = ""
    @State private var draft: QuickEntryDraft?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Describe the transaction") {
                    TextField("Lunch 350 at Green Cafe today using UPI", text: $text, axis: .vertical)
                        .lineLimit(3...6).accessibilityIdentifier("quickEntryText")
                    Button {
                        speech.toggle()
                    } label: {
                        Label(speech.isRecording ? "Stop Listening" : "Enter by Voice",
                              systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                    }
                    Text("Include an amount. Merchant, date, payment method, and category are optional.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let draft {
                    Section("Review") {
                        LabeledContent("Amount", value: AppFormat.money(draft.amount, currencyCode: currencyCode))
                        LabeledContent("Type", value: draft.type.title)
                        LabeledContent("Category", value: draft.category.displayName)
                        if !draft.merchant.isEmpty { LabeledContent("Merchant", value: draft.merchant) }
                        LabeledContent("Date", value: draft.date.formatted(date: .abbreviated, time: .omitted))
                        Button("Save Transaction", action: save).buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("saveQuickEntry")
                    }
                }
            }
            .navigationTitle("Quick Entry")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onChange(of: speech.transcript) { _, value in text = value }
            .onChange(of: text) { _, value in draft = QuickEntryParser.parse(value) }
            .onDisappear { speech.stop() }
            .alert("Quick Entry", isPresented: Binding(get: { message != nil || speech.errorMessage != nil },
                                                       set: { if !$0 { message = nil; speech.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(message ?? speech.errorMessage ?? "") }
        }
    }

    private func save() {
        guard let draft else { return }
        let transaction = Transaction(amount: draft.amount, type: draft.type, category: draft.category,
                                      paymentMethod: draft.paymentMethod, currencyCode: currencyCode,
                                      transactionDate: draft.date, merchant: draft.merchant, notes: draft.notes)
        context.insert(transaction)
        do { try context.save(); dismiss() }
        catch { message = error.localizedDescription }
    }
}
