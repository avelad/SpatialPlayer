//
//  PlayerViewModel.swift
//  SpatialPlayer
//
//  Created by Michael Swanson on 2/6/24.
//

import Combine
import Foundation

class PlayerViewModel: ObservableObject {
    @Published var videoURL: URL? = URL(string: "https://private.ateme-ri.com/VhObLtUMFf/ref/clear/hls/master.m3u8")
    @Published var videoInfo: VideoInfo = VideoInfo()
    @Published var isImmersiveSpaceShown: Bool = false
    @Published var isDocumentPickerPresented: Bool = false
    @Published var isSpatialVideoAvailable: Bool = false
    @Published var shouldPlayInStereo: Bool = true
    
    var isStereoEnabled: Bool {
        isSpatialVideoAvailable && shouldPlayInStereo
    }
}
