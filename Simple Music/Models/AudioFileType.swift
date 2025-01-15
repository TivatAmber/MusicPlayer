import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct AudioFileType {
    static var all: [UTType] {
        #if os(iOS)
        // iOS 上使用更广泛的音频类型支持
        return [
            .audio,
            .mpeg4Audio,
            UTType(tag: "mp3", tagClass: .filenameExtension, conformingTo: .audio)!,
            UTType(tag: "wav", tagClass: .filenameExtension, conformingTo: .audio)!,
            UTType(tag: "m4a", tagClass: .filenameExtension, conformingTo: .audio)!,
            UTType(tag: "aac", tagClass: .filenameExtension, conformingTo: .audio)!
        ]
        #else
        // macOS 上使用通用音频类型
        return [.audio]
        #endif
    }
}
