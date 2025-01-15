import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
#if !os(macOS)
import MobileCoreServices
#endif

struct SidebarView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    @Binding var isImporting: Bool
    
    var body: some View {
        List {
            ForEach(audioPlayer.playlist) { song in
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.gray)
                        .padding(.trailing, 8)
                    Text(song.title)
                    Spacer()
                    if audioPlayer.currentSong?.id == song.id {
                        Image(systemName: "music.note")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    audioPlayer.loadAudio(from: song)
                    audioPlayer.play()
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        withAnimation {
                            audioPlayer.deleteSong(song)
                        }
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
            .onMove(perform: audioPlayer.reorderSongs)
        }
        .navigationTitle("Playlist")
        .listStyle(.sidebar)
    }
}
