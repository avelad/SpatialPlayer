//
//  ContentView.swift
//  SpatialPlayer
//
//  Created by Michael Swanson on 2/6/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    @State private var urlDialog = false
    @State private var urlString = "https://storage.googleapis.com/shaka-demo-assets/bbb-dark-truths-hls/hls.m3u8"
    
    func urlSubmit() {
        if (urlString != "") {
            viewModel.videoURL = URL(string: urlString)
            viewModel.isHLS = false
            viewModel.isDocumentPickerPresented = false
            viewModel.isImmersiveSpaceShown = true
        }
        urlDialog = false
    }
    
    var body: some View {
        VStack {
            if viewModel.isImmersiveSpaceShown {
                if viewModel.isHLS {
                    Text("Size:").bold() + Text(" \(viewModel.sizeString)")
                } else {
                    Text("Spatial:").bold() + Text(" \(viewModel.videoInfo.isSpatial ? "Yes" : "No")")
                    Text("Size:").bold() + Text(" \(viewModel.sizeString)")
                    Text("Projection:").bold() + Text(" \(viewModel.videoInfo.projectionTypeString)")
                    Text("Horizontal FOV:").bold() + Text(" \(viewModel.videoInfo.horizontalFieldOfViewString)")
                    Toggle("Show in stereo", isOn: $viewModel.shouldPlayInStereo)
                        .fixedSize()
                        .disabled(!viewModel.isSpatialVideoAvailable)
                        .padding()
                }
            } else {
                Text("Spatial Player").font(.title).padding()
                Text("by Michael Swanson (modified by ATEME)")
                Link("https://blog.mikeswanson.com/spatial", destination: URL(string: "https://blog.mikeswanson.com/spatial")!)
                Text("An example spatial video player for MV-HEVC video.\nIt doesn't do much, but I hope it gets you started.\nIf you build something with it, let me know!").padding()
            }
            Button("Select Video", systemImage: "video.fill") {
                viewModel.isImmersiveSpaceShown = false
                viewModel.isDocumentPickerPresented = true
            }
            .padding()
            .sheet(isPresented: $viewModel.isDocumentPickerPresented) {
                DocumentPicker()
            }
            Button("Enter your URL") {
                viewModel.isImmersiveSpaceShown = false
                urlDialog.toggle()
            }
            .alert("Enter your URL", isPresented: $urlDialog) {
                TextField("Enter your URL", text: $urlString)
                Button("OK", action: urlSubmit)
            }
            .padding()
            Text("Default projection type")
            Picker("Default projection type", selection: $viewModel.defaultProjectionType) {
                ForEach(PlayerViewModel.ProjectionType.allCases) { projectionType in
                    Text(projectionType.rawValue.capitalized)
                }
            }
            Text("Default horizontal field of view")
            Picker("Default horizontal field of view", selection: $viewModel.defaultHorizontalFieldOfView) {
                ForEach(PlayerViewModel.HorizontalFieldOfView.allCases) { horizontalFieldOfView in
                    Text(horizontalFieldOfView.rawValue.capitalized)
                }
            }
            Toggle("Default is spatial", isOn: $viewModel.defaultIsSpatial)
                .fixedSize()
                .padding()
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .onChange(of: viewModel.isImmersiveSpaceShown) { _, newValue in
            Task {
                if newValue {
                    switch await openImmersiveSpace(id: "PlayerImmersiveSpace") {
                    case .opened:
                        viewModel.isImmersiveSpaceShown = true
                    default:
                        viewModel.isImmersiveSpaceShown = false
                    }
                } else {
                    await dismissImmersiveSpace()
                    viewModel.isImmersiveSpaceShown = false
                }
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PlayerViewModel())
    }
}
