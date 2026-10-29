import Foundation
import AVFoundation
import Speech
import SwiftUI

@MainActor
final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechService()

    // MARK: - Text to Speech
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var speakingMessageId: UUID?

    // MARK: - Speech to Text (Dictation)
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    @Published var isRecording = false
    @Published var transcribedText = ""

    override private init() {
        super.init()
        synthesizer.delegate = self
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR")) ?? SFSpeechRecognizer()
    }

    // MARK: - TTS Methods
    func speak(text: String, messageId: UUID) {
        if isSpeaking && speakingMessageId == messageId {
            stopSpeaking()
            return
        }

        stopSpeaking()

        // Nettoyer les balises Markdown et balises think pour une lecture audio agréable
        let clean = cleanTextForSpeech(text)
        guard !clean.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.pitchMultiplier = 1.0

        speakingMessageId = messageId
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        speakingMessageId = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingMessageId = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingMessageId = nil
        }
    }

    private func cleanTextForSpeech(_ text: String) -> String {
        var str = text
        // Supprimer <think>...</think>
        if let regex = try? NSRegularExpression(pattern: #"<think>[\s\S]*?<\/think>"#, options: []) {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: (str as NSString).length), withTemplate: "")
        }
        // Supprimer les blocs de code ```...```
        if let regex = try? NSRegularExpression(pattern: #"```[\s\S]*?```"#, options: []) {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(location: 0, length: (str as NSString).length), withTemplate: " [bloc de code] ")
        }
        // Nettoyer les caractères markdown
        str = str.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: ">", with: "")
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Dictation Methods
    func toggleDictation(onResult: @escaping (String) -> Void) {
        if isRecording {
            stopRecording()
        } else {
            startRecording(onResult: onResult)
        }
    }

    func startRecording(onResult: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard status == .authorized else { return }
                self?.beginAudioRecording(onResult: onResult)
            }
        }
    }

    private func beginAudioRecording(onResult: @escaping (String) -> Void) {
        stopRecording()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            Haptics.tap()
        } catch {
            return
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    let text = result.bestTranscription.formattedString
                    self?.transcribedText = text
                    onResult(text)
                }
                if error != nil || (result?.isFinal == true) {
                    self?.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}
