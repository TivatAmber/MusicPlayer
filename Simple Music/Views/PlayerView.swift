import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
#if !os(macOS)
import MobileCoreServices
#endif

struct PlayerView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    @GestureState private var isDragging = false
    @State private var seekPosition: Double = 0
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func getPlayModeDescription(_ mode: AudioPlayer.PlayMode) -> String {
        switch mode {
        case .listOnce:
            return "列表播放"
        case .listRepeat:
            return "列表循环"
        case .shuffle:
            return "随机播放"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if let currentSong = audioPlayer.currentSong {
                Text(currentSong.title)
                    .font(.title)
                    .padding()
            } else {
                Text("No song selected")
                    .font(.title)
                    .padding()
            }
            
            Image(systemName: "music.note")
                .resizable()
                .frame(width: 200, height: 200)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            // 进度条
            Slider(
                value: Binding(
                    get: { isDragging ? seekPosition : audioPlayer.currentTime },
                    set: { newValue in
                        seekPosition = newValue
                        audioPlayer.updateProgress(to: newValue)
                    }
                ),
                in: 0...max(audioPlayer.duration, 1)
            )
            .padding(.horizontal)
            
            // 时间显示
            HStack {
                Text(formatTime(isDragging ? seekPosition : audioPlayer.currentTime))
                    .monospacedDigit()
                Spacer()
                Text(formatTime(audioPlayer.duration))
                    .monospacedDigit()
            }
            .padding(.horizontal)
            
            HStack(spacing: 40) {
                Button(action: { audioPlayer.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }
                
                Button(action: {
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play()
                    }
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                }
                
                Button(action: { audioPlayer.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
            }
            .padding()
            
            // 播放模式控制
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation {
                        switch audioPlayer.playMode {
                        case .listOnce:
                            audioPlayer.playMode = .listRepeat
                        case .listRepeat:
                            audioPlayer.playMode = .shuffle
                        case .shuffle:
                            audioPlayer.playMode = .listOnce
                        }
                    }
                }) {
                    Image(systemName: audioPlayer.playMode.icon)
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .foregroundColor(audioPlayer.playMode == .listOnce ? .gray : .blue)
                }
                .help(getPlayModeDescription(audioPlayer.playMode))
            }
            .frame(height: 44)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Now Playing")
        .onAppear {
            seekPosition = audioPlayer.currentTime
        }
        .onChange(of: audioPlayer.currentTime) { oldValue, newValue in
            if !isDragging {
                seekPosition = newValue
            }
        }
    }
}
