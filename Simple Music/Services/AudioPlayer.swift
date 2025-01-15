import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import MediaPlayer
#if !os(macOS)
import MobileCoreServices
#endif

class AudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?
    private var timer: Timer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentSong: Song?
    @Published var playlist: [Song] = [] {
        didSet {
            saveSongList() // 每次播放列表更改时保存
        }
    }
    @Published var playMode: PlayMode = .listOnce
    @Published var errorMessage: String?
    
    // 用于持久化存储的键
    private static let userDefaultsPlaylistKey = "com.app.simplemusic.savedPlaylist"
    
    init() {
        setupBackgroundPlayback()
        setupRemoteCommandCenter()
        loadSongList() // 初始化时加载保存的播放列表
    }
    
    enum PlayMode {
        case listOnce    // 列表播放，不循环
        case listRepeat  // 列表循环
        case shuffle     // 随机播放
        
        var icon: String {
            switch self {
            case .listOnce: return "arrow.forward"
            case .listRepeat: return "repeat"
            case .shuffle: return "shuffle"
            }
        }
    }
    
    deinit {
        stopTimer()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupBackgroundPlayback() {
#if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 注册后台播放通知
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleInterruption),
                                                   name: AVAudioSession.interruptionNotification,
                                                   object: AVAudioSession.sharedInstance())
            
            // 注册耳机拔出通知
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleRouteChange),
                                                   name: AVAudioSession.routeChangeNotification,
                                                   object: AVAudioSession.sharedInstance())
        } catch {
            print("Failed to set up background playback: \(error)")
        }
#endif
    }
    
    private func setupRemoteCommandCenter() {
#if !os(macOS)
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 播放/暂停
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // 下一首
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        // 上一首
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        
        // 进度控制
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.updateProgress(to: event.positionTime)
            }
            return .success
        }
#endif
    }
    
    @objc private func handleInterruption(notification: Notification) {
#if !os(macOS)
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // 音频被中断（如来电），暂停播放
            pause()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // 中断结束，恢复播放
                play()
            }
        @unknown default:
            break
        }
#endif
    }
    
    @objc private func handleRouteChange(notification: Notification) {
#if !os(macOS)
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // 音频设备断开连接（如耳机拔出），暂停播放
            pause()
        default:
            break
        }
#endif
    }
    
    private func updateNowPlayingInfo() {
#if !os(macOS)
        if let currentSong = currentSong {
            var nowPlayingInfo = [String: Any]()
            nowPlayingInfo[MPMediaItemPropertyTitle] = currentSong.title
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
#endif
    }
    
    func loadAudio(from song: Song) {
        stopTimer()
        do {
            if !FileManager.default.fileExists(atPath: song.url.path) {
                self.errorMessage = "文件不存在: \(song.title)"
                return
            }
            
            player = try AVAudioPlayer(contentsOf: song.url)
            if player == nil {
                self.errorMessage = "无法加载音频文件: \(song.title)"
                return
            }
            
            duration = player?.duration ?? 0
            currentTime = 0
            currentSong = song
            self.errorMessage = nil
            updateNowPlayingInfo()
        } catch {
            print("Failed to load audio file: \(error)")
            self.errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }
    
    func reorderSongs(from source: IndexSet, to destination: Int) {
        playlist.move(fromOffsets: source, toOffset: destination)
    }
    
    func deleteSong(_ song: Song) {
        // 如果当前正在播放这首歌，先停止播放
        if currentSong?.id == song.id {
            pause()
            player = nil
            currentSong = nil
            currentTime = 0
            duration = 0
        }
        
        // 从磁盘删除文件
        do {
            try FileManager.default.removeItem(at: song.url)
        } catch {
            print("Failed to delete file: \(error)")
            self.errorMessage = "删除失败: \(error.localizedDescription)"
        }
        
        // 从播放列表移除
        playlist.removeAll(where: { $0.id == song.id })
    }
    
    func addSong(url: URL) {
        // 获取应用程序Documents目录下的Music文件夹
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let musicDirectory = documentDirectory.appendingPathComponent("Music", isDirectory: true)
        
        do {
            // 确保Music目录存在
            if !FileManager.default.fileExists(atPath: musicDirectory.path) {
                try FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
            }
            
            // 创建唯一的文件名
            let destination = musicDirectory.appendingPathComponent(UUID().uuidString + "." + url.pathExtension)
            
            // 复制文件
            try FileManager.default.copyItem(at: url, to: destination)
            
            // 添加到播放列表并保存
            let title = url.deletingPathExtension().lastPathComponent
            let song = Song(url: destination, title: title)
            playlist.append(song)
        } catch {
            print("Failed to copy file: \(error)")
            self.errorMessage = "添加失败: \(error.localizedDescription)"
        }
    }
    
    func play() {
        guard let player = player else {
            self.errorMessage = "没有可播放的音频文件"
            return
        }
        player.play()
        isPlaying = true
        startTimer()
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
        updateNowPlayingInfo()
    }
    
    func updateProgress(to value: Double) {
        guard let player = player else { return }
        player.currentTime = value
        currentTime = value
        updateNowPlayingInfo()
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            DispatchQueue.main.async {
                self.currentTime = player.currentTime
                self.updateNowPlayingInfo()
                
                if player.currentTime >= player.duration {
                    self.playNext()
                }
            }
        }
        RunLoop.current.add(timer!, forMode: .tracking)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func playNext() {
        guard let currentSong = currentSong else {
            if !playlist.isEmpty {
                loadAudio(from: playlist[0])
                play()
            }
            return
        }
        
        guard let currentIndex = playlist.firstIndex(of: currentSong) else { return }
        
        var nextIndex: Int
        
        switch playMode {
        case .listOnce:
            // 如果是最后一首，就停止播放
            guard currentIndex + 1 < playlist.count else {
                pause()
                return
            }
            nextIndex = currentIndex + 1
            
        case .listRepeat:
            // 到达列表末尾时回到开始
            nextIndex = (currentIndex + 1) % playlist.count
            
        case .shuffle:
            // 随机选择一首（排除当前歌曲）
            if playlist.count > 1 {
                repeat {
                    nextIndex = Int.random(in: 0..<playlist.count)
                } while nextIndex == currentIndex
            } else {
                nextIndex = currentIndex
            }
        }
        
        let nextSong = playlist[nextIndex]
        loadAudio(from: nextSong)
        play()
    }
    
    func playPrevious() {
        guard let currentSong = currentSong,
              let currentIndex = playlist.firstIndex(of: currentSong) else { return }
        
        var previousIndex: Int
        
        switch playMode {
        case .listOnce, .listRepeat:
            // 到达列表开始时回到结尾
            previousIndex = (currentIndex - 1 + playlist.count) % playlist.count
            
        case .shuffle:
            // 随机选择一首（排除当前歌曲）
            if playlist.count > 1 {
                repeat {
                    previousIndex = Int.random(in: 0..<playlist.count)
                } while previousIndex == currentIndex
            } else {
                previousIndex = currentIndex
            }
        }
        
        let previousSong = playlist[previousIndex]
        loadAudio(from: previousSong)
        play()
    }
    
    // 保存播放列表到用户默认值
    private func saveSongList() {
        if let encoded = try? JSONEncoder().encode(playlist) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsPlaylistKey)
        }
    }
    
    // 从用户默认值加载播放列表
    private func loadSongList() {
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsPlaylistKey),
           let decoded = try? JSONDecoder().decode([Song].self, from: data) {
            // 检查文件是否仍然存在
            playlist = decoded.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        }
    }
}
