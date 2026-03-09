import SwiftUI

/// Sheet view for selecting and controlling ambient focus sounds.
///
/// Displays available sound types with a volume slider, allowing users to
/// pick a soundscape that plays during active task sessions via AVAudioEngine.
struct FocusSoundPickerSheet: View {

    @Environment(\.dismiss) private var dismiss
    private var soundManager = FocusSoundManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(FocusSoundManager.SoundType.allCases) { sound in
                        Button {
                            if sound == .none {
                                soundManager.selectedSound = .none
                                soundManager.stopAmbientSound()
                            } else {
                                soundManager.selectedSound = sound
                                soundManager.startAmbientSound()
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: sound.systemImage)
                                    .font(.title3)
                                    .foregroundStyle(sound == soundManager.selectedSound ? .blue : .secondary)
                                    .frame(width: 28)

                                Text(sound.rawValue)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if sound == soundManager.selectedSound && sound != .none {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else if sound == .none && !soundManager.isPlaying {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Ambient Sounds")
                        .textCase(nil)
                } footer: {
                    Text("Focus sounds are generated in real-time and play while your task session is active.")
                }

                // Volume control — only shown when a sound is selected
                if soundManager.selectedSound != .none {
                    Section("Volume") {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)

                            Slider(value: Binding(
                                get: { soundManager.volume },
                                set: { soundManager.volume = $0 }
                            ), in: 0.05...1.0)
                            .tint(.blue)

                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Focus Sounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    FocusSoundPickerSheet()
}
