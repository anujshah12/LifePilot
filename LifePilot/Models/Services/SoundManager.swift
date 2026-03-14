import AVFoundation

/// Plays sound effects for habit completion and streak milestones.
/// Uses system sounds for lightweight audio feedback (media playback requirement).
final class SoundManager {

    static let shared = SoundManager()

    private init() {
        // Configure audio session so sounds play even in silent mode is off.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[SoundManager] Audio session setup failed: \(error.localizedDescription)")
        }
    }

    /// Short chime when a habit is checked off.
    func playCheckSound() {
        AudioServicesPlaySystemSound(1025)
    }

    /// Celebratory sound when all habits for the day are complete.
    func playAllCompleteSound() {
        AudioServicesPlaySystemSound(1026)
    }

    /// Undo / uncheck sound.
    func playUncheckSound() {
        AudioServicesPlaySystemSound(1003)
    }
}
