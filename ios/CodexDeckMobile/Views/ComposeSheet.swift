import AVFoundation
import Speech
import SwiftUI

/// On-device dictation driving the compose sheet: starts recording the moment
/// the sheet appears, streams partial results into an editable transcript, and
/// leaves the final wording to the user before anything is sent.
@Observable
@MainActor
final class DictationController {
  var transcript = ""
  var isRecording = false
  var statusMessage: String?

  @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
  @ObservationIgnored private let engine = AVAudioEngine()
  @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
  @ObservationIgnored private var task: SFSpeechRecognitionTask?
  /// Text confirmed before the current recognition session started, so a
  /// stop/restart cycle appends instead of overwriting manual edits.
  @ObservationIgnored private var committedPrefix = ""

  func start() async {
    guard !isRecording else { return }
    let speechAuth = await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
    }
    guard speechAuth == .authorized else {
      statusMessage = "Speech recognition permission is required — enable it in Settings."
      return
    }
    let micGranted = await AVAudioApplication.requestRecordPermission()
    guard micGranted else {
      statusMessage = "Microphone permission is required — enable it in Settings."
      return
    }
    guard let recognizer, recognizer.isAvailable else {
      statusMessage = "Speech recognition is unavailable right now."
      return
    }

    committedPrefix = transcript.isEmpty ? "" : transcript + " "
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    self.request = request

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setActive(true, options: .notifyOthersOnDeactivation)
      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        request.append(buffer)
      }
      engine.prepare()
      try engine.start()
    } catch {
      statusMessage = "Could not start the microphone: \(error.localizedDescription)"
      cleanupAudio()
      return
    }

    isRecording = true
    statusMessage = nil
    task = recognizer.recognitionTask(with: request) { [weak self] result, error in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if let result {
          self.transcript = self.committedPrefix + result.bestTranscription.formattedString
        }
        if error != nil || (result?.isFinal ?? false) {
          self.finishRecording()
        }
      }
    }
  }

  func stop() {
    guard isRecording else { return }
    request?.endAudio()
    finishRecording()
  }

  private func finishRecording() {
    guard isRecording else { return }
    isRecording = false
    task?.cancel()
    task = nil
    request = nil
    cleanupAudio()
  }

  private func cleanupAudio() {
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}

/// Long-press on the mic key opens this sheet: dictation starts immediately,
/// the transcript stays editable, and nothing is dispatched until Send.
struct ComposeSheet: View {
  @Environment(DashboardStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var dictation = DictationController()
  @State private var sending = false
  @FocusState private var editorFocused: Bool

  private var selectedAgent: RoutedAgent? { store.agents.first(where: \.selected) }

  var body: some View {
    NavigationStack {
      VStack(spacing: 14) {
        HStack(spacing: 8) {
          Image(systemName: "arrow.turn.down.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(CodexTheme.secondary)
          Text(selectedAgent.map { "\($0.title) · \($0.host.hostName)" } ?? "No chat selected — tap an agent key first")
            .font(.caption.weight(.semibold))
            .foregroundStyle(selectedAgent == nil ? CodexTheme.red : CodexTheme.secondary)
            .lineLimit(1)
          Spacer()
        }

        TextEditor(text: $dictation.transcript)
          .font(.body)
          .focused($editorFocused)
          .scrollContentBackground(.hidden)
          .padding(10)
          .frame(minHeight: 130, maxHeight: 220)
          .background(CodexTheme.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(alignment: .topLeading) {
            if dictation.transcript.isEmpty {
              Text(dictation.isRecording ? "正在听……直接说话" : "说点什么,或直接打字")
                .foregroundStyle(CodexTheme.secondary.opacity(0.6))
                .padding(.top, 18)
                .padding(.leading, 15)
                .allowsHitTesting(false)
            }
          }

        if let message = dictation.statusMessage {
          Text(message)
            .font(.caption)
            .foregroundStyle(CodexTheme.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        HStack(spacing: 12) {
          Button {
            if dictation.isRecording {
              dictation.stop()
            } else {
              editorFocused = false
              Task { await dictation.start() }
            }
          } label: {
            Label(
              dictation.isRecording ? "停止" : "继续说",
              systemImage: dictation.isRecording ? "stop.circle.fill" : "mic.fill")
              .font(.subheadline.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 13)
          }
          .buttonStyle(.bordered)
          .tint(dictation.isRecording ? CodexTheme.red : nil)

          Button {
            sending = true
            dictation.stop()
            let text = dictation.transcript
            Task {
              await store.composeToSelectedAgent(text)
              dismiss()
            }
          } label: {
            Label("发送", systemImage: "paperplane.fill")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 13)
          }
          .buttonStyle(.borderedProminent)
          .tint(CodexTheme.blue)
          .disabled(
            sending || selectedAgent == nil
              || dictation.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        Spacer(minLength: 0)
      }
      .padding(16)
      .background(CodexTheme.canvas)
      .navigationTitle(dictation.isRecording ? "正在聆听" : "派活")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") {
            dictation.stop()
            dismiss()
          }
        }
        ToolbarItem(placement: .principal) {
          if dictation.isRecording {
            Image(systemName: "waveform")
              .symbolEffect(.variableColor.iterative.reversing)
              .foregroundStyle(CodexTheme.red)
          }
        }
      }
      .task { await dictation.start() }
      .onChange(of: dictation.isRecording) { _, recording in
        store.localDictating = recording
      }
      .onDisappear {
        dictation.stop()
        store.localDictating = false
      }
    }
    .presentationDetents([.height(380), .medium])
    .presentationDragIndicator(.visible)
  }
}
