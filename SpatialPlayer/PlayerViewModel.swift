//
//  PlayerViewModel.swift
//  SpatialPlayer
//
//  Created by Michael Swanson on 2/6/24.
//

import Combine
import Foundation

class PlayerViewModel: ObservableObject {
    @Published var videoURL: URL?
    @Published var videoInfo: VideoInfo = VideoInfo()
    @Published var isImmersiveSpaceShown: Bool = false
    @Published var isDocumentPickerPresented: Bool = false
    @Published var isSpatialVideoAvailable: Bool = false
    @Published var shouldPlayInStereo: Bool = true
    
    var isStereoEnabled: Bool {
        isSpatialVideoAvailable && shouldPlayInStereo
    }
    
    @Published var sizeString: String = ""

    var timer: Timer?
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            self.refresh()
        })
    }
    deinit {
        timer?.invalidate()
    }
    func refresh() {
        sizeString = videoInfo.sizeString
    }
}
