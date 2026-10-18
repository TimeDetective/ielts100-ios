import SwiftUI
import AVFoundation
import MediaPlayer

@MainActor final class SpeechPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var speaking = false
    @Published private(set) var paused = false
    @Published private(set) var nowPlaying = ""
    @Published private(set) var itemIndex = 0
    @Published private(set) var itemCount = 0
    @Published var error: String?
    @AppStorage("speech.accent") var accent = "en-GB"
    @AppStorage("speech.slow") var slow = false
    @AppStorage("speech.repeat") var repetitions = 1
    @Published private(set) var availableVoices: [AVSpeechSynthesisVoice] = []
    @Published private(set) var loadingVoices = false
    private let synthesizer = AVSpeechSynthesizer()
    private let audioQueue = DispatchQueue(label: "io.github.timedetective.ielts100demo.audio")
    private var requestID = UUID()
    private var preparingAudio = false
    private var playlist: [String] = []
    private var repetitionIndex = 0
    private var playbackVoice: AVSpeechSynthesisVoice?
    private var currentUtterance: AVSpeechUtterance?
    private var pendingRequest: (texts: [String], accent: String?)?
    private var notificationTokens: [NSObjectProtocol] = []
    private var remoteTokens: [Any] = []
    override init() {
        super.init()
        synthesizer.delegate = self
        refreshVoices()
        configureRemoteCommands()
        notificationTokens.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue { self.pause() }
                else if type == AVAudioSession.InterruptionType.ended.rawValue && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) { self.resume() }
            }
        })
        notificationTokens.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { Task { @MainActor [weak self] in self?.pause() } }
        })
    }
    func refreshVoices() {
        guard !loadingVoices && !speaking else { return }
        loadingVoices = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-GB" || $0.language == "en-US" }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.availableVoices = voices
                self.loadingVoices = false
                if let pending = self.pendingRequest { self.pendingRequest = nil; self.playQueue(pending.texts, accent: pending.accent) }
            }
        }
    }
    func voice(_ language: String) -> AVSpeechSynthesisVoice? {
        availableVoices.filter { $0.language == language }.sorted { $0.quality.rawValue > $1.quality.rawValue }.first
    }
    func play(_ text: String, accent requested: String? = nil) { playQueue([text], accent: requested) }
    func playQueue(_ texts: [String], accent requested: String? = nil) {
        stop()
        let texts = texts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !texts.isEmpty else { return }
        if loadingVoices {
            pendingRequest = (texts, requested); speaking = true; nowPlaying = "正在加载英语声音…"; return
        }
        let language = requested ?? accent
        guard let voice = voice(language) else {
            error = "未找到\(language == "en-GB" ? "英国" : "美国")英语声音。请在系统辅助功能设置中下载对应声音，再到 App 设置里刷新声音列表。"; return
        }
        playlist = texts; itemCount = texts.count; itemIndex = 0; repetitionIndex = 0
        playbackVoice = voice; speaking = true; nowPlaying = texts[0]; preparingAudio = true
        activateSession(for: requestID)
    }
    private func activateSession(for id: UUID) {
        audioQueue.async { [weak self] in
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                Task { @MainActor [weak self] in
                    guard let self, self.requestID == id else { return }
                    self.preparingAudio = false
                    if self.synthesizer.isPaused && self.currentUtterance != nil { self.synthesizer.continueSpeaking() }
                    else { self.speakCurrent() }
                }
            } catch {
                let message = error.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, self.requestID == id else { return }
                    self.stop(); self.error = "音频无法启动：\(message)"
                }
            }
        }
    }
    private func speakCurrent() {
        guard speaking && !paused, let voice = playbackVoice, playlist.indices.contains(itemIndex) else { return }
        let utterance = AVSpeechUtterance(string: playlist[itemIndex])
        utterance.voice = voice
        utterance.rate = slow ? AVSpeechUtteranceDefaultSpeechRate * 0.72 : AVSpeechUtteranceDefaultSpeechRate
        utterance.postUtteranceDelay = 0.7
        currentUtterance = utterance
        nowPlaying = playlist[itemIndex]
        synthesizer.speak(utterance)
        updateNowPlaying()
    }
    func pause() {
        guard speaking && !paused else { return }
        paused = true
        if synthesizer.isSpeaking { synthesizer.pauseSpeaking(at: .word) }
        updateNowPlaying()
    }
    func resume() {
        guard speaking && paused else { return }
        paused = false
        if preparingAudio { return }
        activateSession(for: requestID)
        updateNowPlaying()
    }
    func next() {
        guard speaking && !playlist.isEmpty else { return }
        guard itemIndex + 1 < playlist.count else { stop(); return }
        move(to: itemIndex + 1)
    }
    func previous() { if speaking && !playlist.isEmpty { move(to: max(0, itemIndex - 1)) } }
    private func move(to index: Int) {
        currentUtterance = nil
        if synthesizer.isSpeaking || synthesizer.isPaused { synthesizer.stopSpeaking(at: .immediate) }
        itemIndex = index; repetitionIndex = 0; nowPlaying = playlist[index]
        if !preparingAudio { speakCurrent() }
        updateNowPlaying()
    }
    func stop() {
        requestID = UUID(); pendingRequest = nil; preparingAudio = false; currentUtterance = nil
        if synthesizer.isSpeaking || synthesizer.isPaused { synthesizer.stopSpeaking(at: .immediate) }
        speaking = false; paused = false; nowPlaying = ""; playlist = []; playbackVoice = nil; itemIndex = 0; itemCount = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        audioQueue.async { try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation]) }
    }
    private func updateNowPlaying() {
        guard speaking else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: String(nowPlaying.prefix(160)),
            MPMediaItemPropertyArtist: "100句 · \(playbackVoice?.language == "en-US" ? "美音" : "英音") · \(itemIndex + 1)/\(max(1, itemCount))",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: paused ? 0.0 : 1.0
        ]
    }
    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        remoteTokens.append(center.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success })
        remoteTokens.append(center.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success })
        remoteTokens.append(center.togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in guard let self else { return }; self.paused ? self.resume() : self.pause() }; return .success })
        remoteTokens.append(center.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.next() }; return .success })
        remoteTokens.append(center.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.previous() }; return .success })
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in guard utterance === self.currentUtterance, self.speaking else { return }; self.nowPlaying = utterance.speechString; self.updateNowPlaying() }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard utterance === self.currentUtterance, self.speaking else { return }
            self.currentUtterance = nil
            self.repetitionIndex += 1
            if self.repetitionIndex >= max(1, min(self.repetitions, 3)) { self.itemIndex += 1; self.repetitionIndex = 0 }
            if self.itemIndex < self.playlist.count { self.speakCurrent() } else { self.stop() }
        }
    }
}
struct PronounceButtons: View {
    @EnvironmentObject var speech: SpeechPlayer
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Button { speech.play(text, accent: "en-GB") } label: { Label("英音", systemImage: "speaker.wave.2") }.accessibilityLabel("英音朗读 \(text)")
            Button { speech.play(text, accent: "en-US") } label: { Label("美音", systemImage: "speaker.wave.2") }.accessibilityLabel("美音朗读 \(text)")
        }.font(.subheadline.weight(.medium)).buttonStyle(.bordered).tint(Palette.green)
    }
}
