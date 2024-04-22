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
    @State private var isURLSecurityScoped: Bool = false
    @State private var videoMaterial: VideoMaterial?
    @State private var presentationSizeObserver: NSKeyValueObservation?
    @State private var statusObserver: NSKeyValueObservation?
    @State private var playbackBufferEmptyObserver: NSKeyValueObservation?
    @State private var playbackLikelyToKeepUpObserver: NSKeyValueObservation?
    @State private var playbackBufferFullObserver: NSKeyValueObservation?
    
    var body: some View {
        RealityView { content in
            guard let url = viewModel.videoURL else {
                print("No video URL selected")
                return
            }
            
            // Wrap access in a security scope
            isURLSecurityScoped = url.startAccessingSecurityScopedResource()
            
            let asset = FairPlayPlayer().getAsset(with: viewModel)
            let playerItem = AVPlayerItem(asset: asset)
            
            do {
                let session = AVAudioSession.sharedInstance()
                // Configure the app for playback of long-form movies.
                try session.setCategory(.playback, mode: .moviePlayback)
            } catch {
                // Handle error.
            }
            
            guard let videoInfo = await VideoTools.getVideoInfo(asset: asset) else {
                print("Failed to get video info")
                return
            }

            // NOTE: If you want to force a custom projection, horizontal field of view, etc. because
            // your media doesn't contain the correct metadata, you can do that here. For example:
            //
            if (videoInfo.size == .zero) {
                viewModel.isHLS = true
                switch (viewModel.defaultProjectionType) {
                case PlayerViewModel.ProjectionType.equirectangular:
                    videoInfo.projectionType = .equirectangular
                    break
                case PlayerViewModel.ProjectionType.fisheye:
                    videoInfo.projectionType = .fisheye
                    break
                case PlayerViewModel.ProjectionType.halfEquirectangular:
                    videoInfo.projectionType = .halfEquirectangular
                    break
                case PlayerViewModel.ProjectionType.rectangular:
                    videoInfo.projectionType = .rectangular
                    break
                }
                videoInfo.horizontalFieldOfView = Float(viewModel.defaultHorizontalFieldOfView.rawValue)
                videoInfo.isSpatial = viewModel.defaultIsSpatial
                presentationSizeObserver = playerItem.observe(\.presentationSize, options:  [.new, .old], changeHandler: { (playerItem, change) in
                    if playerItem.presentationSize != .zero {
                        videoInfo.size = playerItem.presentationSize;
                    }
                    print("Current presentation size", playerItem.presentationSize)
                })
                statusObserver = playerItem.observe(\.status, options:  [.new, .old], changeHandler: { (playerItem, change) in
                    if playerItem.status == .readyToPlay {
                        print("Current item status is ready")
                    } else if playerItem.status == .failed {
                        print("Current item status is failed")
                    }
                })
                playbackBufferEmptyObserver = playerItem.observe(\.isPlaybackBufferEmpty, options:  [.new, .old], changeHandler: { (playerItem, change) in
                    print("buffering...")
                })
                playbackLikelyToKeepUpObserver = playerItem.observe(\.isPlaybackLikelyToKeepUp, options:  [.new, .old], changeHandler: { (playerItem, change) in
                    print("buffering ends...")
                })
                playbackBufferFullObserver = playerItem.observe(\.isPlaybackBufferFull, options:  [.new, .old], changeHandler: { (playerItem, change) in
                    print("buffering is hidden...")
                })
            }

            viewModel.videoInfo = videoInfo
            viewModel.isSpatialVideoAvailable = videoInfo.isSpatial
            viewModel.refresh()
            
            guard let (mesh, transform) = await VideoTools.makeVideoMesh(videoInfo: videoInfo) else {
                print("Failed to get video mesh")
                return
            }
            
            videoMaterial = VideoMaterial(avPlayer: viewModel.player)
            guard let videoMaterial else {
                print("Failed to create video material")
                return
            }
            
            updateStereoMode()
            let videoEntity = Entity()
            videoEntity.components.set(ModelComponent(mesh: mesh, materials: [videoMaterial]))
            videoEntity.transform = transform
            content.add(videoEntity)
            
            viewModel.player.replaceCurrentItem(with: playerItem)
            viewModel.player.play()
        }
        .onDisappear {
            if isURLSecurityScoped, let url = viewModel.videoURL {
                url.stopAccessingSecurityScopedResource()
            }
            presentationSizeObserver?.invalidate()
            statusObserver?.invalidate()
            playbackBufferEmptyObserver?.invalidate()
            playbackLikelyToKeepUpObserver?.invalidate()
            playbackBufferFullObserver?.invalidate()
            viewModel.player.replaceCurrentItem(with: nil)
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
