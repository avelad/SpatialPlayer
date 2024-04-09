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
    @Published var isHLS: Bool = false
    
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
    
    enum HorizontalFieldOfView: String, CaseIterable, Identifiable {
        case full = "360.0"
        case half = "180.0"
        case center = "63.0"
        var id: Self { self }
    }
    
    @Published var defaultHorizontalFieldOfView: HorizontalFieldOfView = HorizontalFieldOfView.center
    
    enum ProjectionType: String, CaseIterable, Identifiable {
        case equirectangular = "equirectangular"
        case fisheye = "fisheye"
        case halfEquirectangular = "halfEquirectangular"
        case rectangular = "rectangular"
        var id: Self { self }
    }
        
    @Published var defaultProjectionType: ProjectionType = ProjectionType.rectangular
    
    @Published var defaultIsSpatial: Bool = true
}
