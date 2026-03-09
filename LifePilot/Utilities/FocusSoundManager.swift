import AVFoundation
import Observation

/// Manages ambient focus sounds during active task sessions.
///
/// Uses AVAudioEngine to generate procedural soundscapes (white noise, brown noise,
/// gentle tone) so no bundled audio files are required. Also provides a task-completion
/// chime using system sounds.
@Observable
final class FocusSoundManager {

    // MARK: - Singleton

    static let shared = FocusSoundManager()

    // MARK: - Sound Types

    enum SoundType: String, CaseIterable, Identifiable {
        case whiteNoise = "White Noise"
        case brownNoise = "Brown Noise"
        case gentleTone = "Gentle Tone"
        case none = "Off"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .whiteNoise: return "waveform"
            case .brownNoise: return "wind"
            case .gentleTone: return "music.note"
            case .none:       return "speaker.slash"
            }
        }
    }

    // MARK: - Properties

    /// The currently selected ambient sound type.
    var selectedSound: SoundType = .none

    /// Whether ambient sound is currently playing.
    var isPlaying = false

    /// Volume level for the ambient sound (0.0 to 1.0).
    var volume: Float = 0.3 {
        didSet {
            volume = max(0, min(1, volume))
            playerNode?.volume = volume
        }
    }

    // MARK: - Private Audio Engine Components

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var completionPlayer: AVAudioPlayer?

    private init() {
        configureAudioSession()
    }

    // MARK: - Audio Session

    /// Configures the shared audio session for background-compatible playback.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[FocusSoundManager] Audio session setup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Playback Controls

    /// Starts playing the selected ambient sound.
    func startAmbientSound() {
        guard selectedSound != .none else { return }

        // Stop any existing playback first.
        stopAmbientSound()

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        player.volume = volume

        engine.attach(player)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            print("[FocusSoundManager] Engine start failed: \(error.localizedDescription)")
            return
        }

        // Generate and schedule a looping audio buffer for the selected sound type.
        let buffer = generateBuffer(for: selectedSound, format: format)
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()

        audioEngine = engine
        playerNode = player
        isPlaying = true
    }

    /// Stops the currently playing ambient sound.
    func stopAmbientSound() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        isPlaying = false
    }

    /// Toggles ambient sound on or off based on current state.
    func toggle() {
        if isPlaying {
            stopAmbientSound()
        } else {
            startAmbientSound()
        }
    }

    /// Plays a short chime sound when a task is completed.
    func playCompletionSound() {
        // Use system sound 1025 (a short, pleasant chime).
        AudioServicesPlaySystemSound(1025)
    }

    /// Plays a celebratory sound when all tasks are done for the day.
    func playDayCompleteSound() {
        // Use system sound 1026 (a fanfare-like tone).
        AudioServicesPlaySystemSound(1026)
    }

    // MARK: - Sound Generation

    /// Generates a procedural audio buffer for the given sound type.
    ///
    /// Each sound type uses a different algorithm:
    /// - White noise: uniform random samples for a flat-spectrum hiss
    /// - Brown noise: integrated random walk for a deeper, warmer rumble
    /// - Gentle tone: low-frequency sine wave mixed with soft noise for a calming hum
    private func generateBuffer(for type: SoundType, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        // Generate 2 seconds of audio; the player loops it seamlessly.
        let frameCount = AVAudioFrameCount(sampleRate * 2)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else { return buffer }

        switch type {
        case .whiteNoise:
            for i in 0..<Int(frameCount) {
                channelData[i] = Float.random(in: -0.15...0.15)
            }

        case .brownNoise:
            var lastValue: Float = 0
            for i in 0..<Int(frameCount) {
                let white = Float.random(in: -1...1)
                // Integrate with a small step for a smooth, deep rumble.
                lastValue = (lastValue + (0.02 * white))
                // Soft clamp to prevent drift.
                lastValue = max(-0.15, min(0.15, lastValue))
                channelData[i] = lastValue
            }

        case .gentleTone:
            let frequency: Double = 174 // Low Solfeggio frequency — soothing
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                let sine = Float(sin(2 * .pi * frequency * t)) * 0.08
                let noise = Float.random(in: -0.03...0.03)
                channelData[i] = sine + noise
            }

        case .none:
            break
        }

        return buffer
    }
}
