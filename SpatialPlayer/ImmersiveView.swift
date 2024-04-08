//
//  ImmersiveView.swift
//  SpatialPlayer
//
//  Created by Michael Swanson on 2/6/24.
//

import AVKit
import RealityKit
import SwiftUI

struct ImmersiveView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @State private var player: AVPlayer = AVPlayer()
    @State private var isURLSecurityScoped: Bool = false
    @State private var videoMaterial: VideoMaterial?
    @State private var observer: NSKeyValueObservation?
    
    var body: some View {
        RealityView { content in
            guard let url = viewModel.videoURL else {
                print("No video URL selected")
                return
            }
            
            // Wrap access in a security scope
            isURLSecurityScoped = url.startAccessingSecurityScopedResource()
            
            let asset = AVURLAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            
            guard let videoInfo = await VideoTools.getVideoInfo(asset: asset) else {
                print("Failed to get video info")
                return
            }

            // NOTE: If you want to force a custom projection, horizontal field of view, etc. because
            // your media doesn't contain the correct metadata, you can do that here. For example:
            //
            if (videoInfo.size == .zero) {
                videoInfo.projectionType = .equirectangular
                videoInfo.horizontalFieldOfView = 360.0
                videoInfo.isSpatial = true
                viewModel.isHLS = true
                observer = playerItem.observe(\.presentationSize, options:  [.new, .old], changeHandler: { (playerItem, change) in
                    if playerItem.presentationSize != .zero {
                        videoInfo.size = playerItem.presentationSize;
                    }
                })
            }

            viewModel.videoInfo = videoInfo
            viewModel.isSpatialVideoAvailable = videoInfo.isSpatial
            viewModel.refresh()
            
            guard let (mesh, transform) = await VideoTools.makeVideoMesh(videoInfo: videoInfo) else {
                print("Failed to get video mesh")
                return
            }
            
            videoMaterial = VideoMaterial(avPlayer: player)
            guard let videoMaterial else {
                print("Failed to create video material")
                return
            }
            
            updateStereoMode()
            let videoEntity = Entity()
            videoEntity.components.set(ModelComponent(mesh: mesh, materials: [videoMaterial]))
            videoEntity.transform = transform
            content.add(videoEntity)
            
            player.replaceCurrentItem(with: playerItem)
            player.play()
        }
        .onDisappear {
            if isURLSecurityScoped, let url = viewModel.videoURL {
                url.stopAccessingSecurityScopedResource()
            }
            observer?.invalidate()
        }
        .onChange(of: viewModel.shouldPlayInStereo) { _, newValue in
            updateStereoMode()
        }
    }
    
    func updateStereoMode() {
        if let videoMaterial {
            videoMaterial.controller.preferredViewingMode =
            viewModel.isStereoEnabled ? .stereo : .mono
        }
    }
}
