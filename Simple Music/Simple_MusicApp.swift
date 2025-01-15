import SwiftUI
import SwiftData

// TODO 如果点击正在播放的歌曲，不要从头开始播放
@main
struct MusicPlayerApp: App {
    init() {
        // 启用远程控制事件接收
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
