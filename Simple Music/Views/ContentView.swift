import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
#if !os(macOS)
import MobileCoreServices
#endif

struct ContentView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var isImporting = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showingPlayer = false  // 控制播放界面的显示
    
    var body: some View {
        if #available(macOS 13.0, iOS 16.0, *) {
            NavigationSplitView(columnVisibility: $columnVisibility, sidebar: {
                List {
                    ForEach(audioPlayer.playlist) { song in
                        HStack {
                            // Drag indicator
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.gray)
                            Text(song.title)
                                .padding(.leading, 8)
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
                .navigationTitle("播放列表")
                .listStyle(.sidebar)
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            // 添加按钮
                            Button(action: { isImporting = true }) {
                                Image(systemName: "plus")
                            }
                            
                            // 播放器切换按钮
                            Button(action: { showingPlayer = true }) {
                                Image(systemName: "play.circle")
                            }
                        }
                    }
                    #else
                    ToolbarItem {
                        Button(action: { isImporting = true }) {
                            Image(systemName: "plus")
                        }
                    }
                    #endif
                }
                #if os(iOS)
                .navigationDestination(isPresented: $showingPlayer) {
                    PlayerView(audioPlayer: audioPlayer)
                }
                #endif
            }, detail: {
                #if os(iOS)
                if !showingPlayer {
                    Text("选择歌曲开始播放")
                        .font(.title)
                        .foregroundColor(.gray)
                } else {
                    PlayerView(audioPlayer: audioPlayer)
                }
                #else
                PlayerView(audioPlayer: audioPlayer)
                #endif
            })
            .navigationSplitViewStyle(.balanced)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: AudioFileType.all,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        guard url.startAccessingSecurityScopedResource() else {
                            print("Failed to access security-scoped resource")
                            continue
                        }
                        
                        Task {
                            defer {
                                url.stopAccessingSecurityScopedResource()
                            }
                            
                            await MainActor.run {
                                audioPlayer.addSong(url: url)
                            }
                        }
                    }
                case .failure(let error):
                    print("Import failed: \(error)")
                    audioPlayer.errorMessage = "导入失败: \(error.localizedDescription)"
                }
            }
        } else {
            // Fallback for older versions
            NavigationView {
                SidebarView(audioPlayer: audioPlayer, isImporting: $isImporting)
                PlayerView(audioPlayer: audioPlayer)
            }
            .navigationViewStyle(.columns)
        }
    }
}

#Preview {
    ContentView()
}
